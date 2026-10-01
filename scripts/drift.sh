#!/usr/bin/env bash
# Continuous drift & harness-health sensor (garbage collection input).
# Prints one finding per line, prefixed by kind. Exit 1 if any finding.
#   dead-ref   context mentions a path that no longer exists
#   stale      a module's covered paths changed after the module did
#   unsynced   files edited since last /harness-sync (ledger)
#   budget     token budget exceeded
#   recurring  sensor failed >= N times -> promote to a guide or a sharper sensor
#   silent     sensor ran >= N times and never fired -> verify it can detect anything
#   orphan     harness.md references a sensor missing from config (incoherent harness)
. "$(dirname "$0")/lib.sh"
cd "$ROOT" || exit 1
is_initialized || { echo "uninitialized: no .harness/ (run /ctx-agent:harness-init)"; exit 1; }
n=0; say() { echo "$1"; n=$((n + 1)); }

# dead-ref: backticked tokens that look like repo paths (outside <!-- comments -->)
strip_comments() { awk '{ while (1) { if (c) { i=index($0,"-->"); if (!i) { $0=""; break } $0=substr($0,i+3); c=0 }
  i=index($0,"<!--"); if (!i) break; pre=substr($0,1,i-1); rest=substr($0,i+4); j=index(rest,"-->")
  if (j) { $0=pre substr(rest,j+3) } else { $0=pre; c=1; break } } print }' "$1"; }
while IFS= read -r f; do
  rel="${f#"$ROOT"/}"
  strip_comments "$f" | grep -o '`[^` ]*`' | tr -d '`' | sort -u | while IFS= read -r p; do
    case "$p" in
      */*|*.*) ;; *) continue ;; esac
    case "$p" in
      http*|*://*|*'{'*|*'*'*|*'<'*|*'$'*|-*|*'='*|*'('*|.harness/.ledger|.harness/.sensor-log) continue ;; esac
    [[ "$p" =~ ^[A-Za-z0-9_./@-]+$ ]] || continue
    [[ "$p" == */* ]] || [[ "$p" =~ \.[A-Za-z]{1,6}$ ]] || continue
    [ -e "$p" ] || [ -e "${p%/}" ] && continue
    # bare filename: fine if it exists anywhere in the repo
    if [[ "$p" != */* ]] && { git ls-files 2>/dev/null; find . -name "$p" -not -path './.git/*' 2>/dev/null; } | grep -Eq "(^|/)${p//./\\.}$"; then continue; fi
    echo "dead-ref   $rel -> $p"
  done
done < <(context_files) > "$HARNESS_DIR/.drift.tmp"
while IFS= read -r l; do say "$l"; done < "$HARNESS_DIR/.drift.tmp"; rm -f "$HARNESS_DIR/.drift.tmp"

# stale: modules declare <!-- covers: path1 path2 --> ; compare git commit times
if git rev-parse --git-dir >/dev/null 2>&1; then
  while IFS= read -r f; do
    covers=$(sed -n 's/.*<!--[[:space:]]*covers:[[:space:]]*\(.*\)-->.*/\1/p' "$f" | head -n 1)
    [ -z "$covers" ] && continue
    mt=$(git log -1 --format=%ct -- "$f" 2>/dev/null); [ -z "$mt" ] && continue
    # shellcheck disable=SC2086
    ct=$(git log -1 --format=%ct -- $covers 2>/dev/null)
    [ -n "$ct" ] && [ "$ct" -gt "$mt" ] && say "stale      ${f#"$ROOT"/} (covered code changed $(( (ct - mt) / 86400 ))d after doc)"
  done < <(context_files)
fi

# unsynced
if [ -s "$LEDGER" ]; then
  c=$(sort -u "$LEDGER" | wc -l | tr -d ' ')
  say "unsynced   $c file(s) changed since last sync: $(sort -u "$LEDGER" | head -n 5 | tr '\n' ' ')"
fi

# budget
while IFS= read -r l; do say "budget     $l"; done < <("$(dirname "$0")/budget.sh" -q)

# recurring / silent (steering-loop signals)
if [ -s "$SENSOR_LOG" ]; then
  rec=$(cfg_get steer.recurring_threshold 3); sil=$(cfg_get steer.silent_threshold 30)
  while read -r key fails runs; do
    [ "$fails" -ge "$rec" ] && say "recurring  $key failed $fails/$runs runs -> encode the lesson as a guide (AGENTS.md/module rule) or a sharper sensor"
    [ "$fails" -eq 0 ] && [ "$runs" -ge "$sil" ] && say "silent     $key never fired in $runs runs -> verify it can detect a seeded violation"
  done < <(awk -F'\t' '{k=$2"/"$3; r[k]++; if($4=="fail")f[k]++} END{for(k in r) print k, f[k]+0, r[k]}' "$SENSOR_LOG" | sort)
fi

# orphan: sensors named in harness.md must exist in config
if [ -f "$HARNESS_DIR/harness.md" ]; then
  grep -o 'sensor\.[a-z]*\.[A-Za-z0-9_-]*' "$HARNESS_DIR/harness.md" | sort -u | while read -r k; do
    grep -Eq "^[[:space:]]*${k//./\\.}=" "$CONFIG" 2>/dev/null || echo "orphan     harness.md lists $k but .harness/config does not define it"
  done > "$HARNESS_DIR/.drift.tmp"
  while IFS= read -r l; do say "$l"; done < "$HARNESS_DIR/.drift.tmp"; rm -f "$HARNESS_DIR/.drift.tmp"
fi

[ $n -eq 0 ] && { [ "${CTX_VERBOSE:-0}" = 1 ] && echo "no drift"; exit 0; }
exit 1
