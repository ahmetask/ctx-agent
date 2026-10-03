#!/usr/bin/env bash
# checkpoint.sh [event] — mechanical session memory, no LLM tokens spent writing it.
# Overwrites .harness/checkpoint.md with what a fresh session needs to resume:
# branch/HEAD, uncommitted files, files edited since sync, failing sensors, active plan.
# Called by the Stop, PreCompact and SessionEnd hooks; printed by session-start.sh.
# state.md holds intent (written by the agent); this file holds facts (written by us).
. "$(dirname "$0")/lib.sh"
is_initialized || exit 0
[ -t 0 ] || cat >/dev/null 2>&1  # drain hook JSON; unused
cd "$ROOT" || exit 0
ev="${1:-manual}"
list() { head -n "$1" | tr '\n' ' ' | sed 's/ $//'; }

{
  echo "# Checkpoint (auto · $(date -u +%Y-%m-%dT%H:%MZ) · $ev)"
  if git rev-parse --git-dir >/dev/null 2>&1; then
    echo "- git: $(git branch --show-current 2>/dev/null || echo detached) @ $(git log -1 --format='%h %s' 2>/dev/null | cut -c1-72)"
    dirty=$(git status --porcelain 2>/dev/null | grep -v ' \.harness/' | awk '{print $NF}')
    [ -n "$dirty" ] && echo "- uncommitted ($(printf '%s\n' "$dirty" | wc -l | tr -d ' ')): $(printf '%s\n' "$dirty" | list 8)"
  fi
  [ -s "$LEDGER" ] && echo "- edited since sync: $(sort -u "$LEDGER" | list 8)"
  if [ -s "$SENSOR_LOG" ]; then
    # latest status per sensor; report the ones whose last run failed
    red=$(awk -F'\t' '{s[$2"/"$3]=$4} END{for(k in s) if(s[k]=="fail") print k}' "$SENSOR_LOG" | sort)
    [ -n "$red" ] && echo "- failing sensors (last run): $(printf '%s\n' "$red" | list 6)"
  fi
  for p in "$HARNESS_DIR"/plans/active/*.md; do
    [ -f "$p" ] || continue
    st=$(sed -n 's/^- status:[[:space:]]*//p' "$p" | head -n 1)
    nx=$(awk '/^## Next action/{f=1;next} f&&NF{print;exit}' "$p")
    echo "- plan ${p#"$ROOT"/}: ${st:-no status}${nx:+ · next: $nx}"
  done
} > "$HARNESS_DIR/checkpoint.md.tmp" && mv "$HARNESS_DIR/checkpoint.md.tmp" "$HARNESS_DIR/checkpoint.md"
exit 0
