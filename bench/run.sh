#!/usr/bin/env bash
# Token A/B benchmark: does ctx-agent (context harness + session memory) reduce token use?
#
#   bench/run.sh [--task DIR] [--arms baseline,ctx,ctx-mem] [--reps N] [--model M]
#                [--agent NAME] [--max-budget-usd X] [--out DIR]
#
# A task is a directory with repo/ (fixture), phase<N>.md (prompts) and check<N>.sh (hidden
# acceptance: check<N>.sh <workdir>, exit 0 = pass). Every phase is a fresh headless session
# (claude -p, no resume), so the only memory between phases is what is left in the repo.
#
# Arms (same prompts, model and flags; each gets its own copy of the fixture):
#   baseline  no plugin, no harness
#   ctx       plugin + harness; session memory (state.md, plans, checkpoint) wiped between phases
#   ctx-mem   plugin + harness; memory carried between phases
# ctx arms share one harness-init "setup" session per rep (phase 0, reported separately).
#
# Env: CLAUDE_BIN (default claude), BENCH_PERMISSION_MODE (default bypassPermissions).
# Run it only on throwaway fixtures: agents run with permissions bypassed.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
task="$HERE/tasks/inventory"; arms="baseline,ctx,ctx-mem"; reps=1
model=""; agent=""; budget=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --task) task="$(cd "$2" && pwd)"; shift 2 ;;
    --arms) arms="$2"; shift 2 ;;
    --reps) reps="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --agent) agent="$2"; shift 2 ;;
    --max-budget-usd) budget="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
PERM="${BENCH_PERMISSION_MODE:-bypassPermissions}"
out="${out:-${TMPDIR:-/tmp}/ctx-bench-$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$out/raw" "$out/logs" "$out/work"; out="$(cd "$out" && pwd)"
nphases=$(find "$task" -maxdepth 1 -name 'phase*.md' | wc -l | tr -d ' ')
[ -d "$task/repo" ] && [ "$nphases" -gt 0 ] || { echo "not a task dir: $task" >&2; exit 2; }
for a in ${arms//,/ }; do case "$a" in baseline|ctx|ctx-mem) ;; *) echo "unknown arm: $a" >&2; exit 2 ;; esac; done

PREAMBLE="No human is available during this run. Don't wait for answers: where you would ask, take the most conservative reversible option and note it."
RESULTS="$out/results.tsv"
printf 'rep\tarm\tphase\tpass\tcost_usd\tinput\tcache_write\tcache_read\toutput\tturns\tduration_ms\terror\n' > "$RESULTS"

g() { git -c user.name=bench -c user.email=bench@localhost "$@"; }
commit_all() { (cd "$1" && g add -A && g commit -qm "$2" --allow-empty); }
fixture() { cp -R "$task/repo" "$1" && (cd "$1" && g init -q && g add -A && g commit -qm "initial"); }

# metrics RAW -> cost input cache_write cache_read output turns duration_ms error (tab-separated)
# Sums modelUsage (all models, incl. subagents) when present, else the top-level usage block.
metrics() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '
      def mu(k): [(.modelUsage // {})[] | .[k] // 0] | add;
      (if ((.modelUsage // {}) | length) > 0
       then [mu("inputTokens"), mu("cacheCreationInputTokens"), mu("cacheReadInputTokens"), mu("outputTokens")]
       else [.usage.input_tokens, .usage.cache_creation_input_tokens, .usage.cache_read_input_tokens, .usage.output_tokens]
       end | map(. // 0)) as $t
      | [(.total_cost_usd // 0)] + $t + [(.num_turns // 0), (.duration_ms // 0), (if .is_error then 1 else 0 end)] | @tsv' "$1" 2>/dev/null
  else
    python3 - "$1" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
mu = d.get("modelUsage") or {}
if mu:
    t = [sum(m.get(k, 0) or 0 for m in mu.values()) for k in
         ("inputTokens", "cacheCreationInputTokens", "cacheReadInputTokens", "outputTokens")]
else:
    u = d.get("usage") or {}
    t = [u.get(k) or 0 for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens")]
print("\t".join(str(x) for x in [d.get("total_cost_usd") or 0] + t +
      [d.get("num_turns") or 0, d.get("duration_ms") or 0, 1 if d.get("is_error") else 0]))
PY
  fi
}

# session WORKDIR ARM LABEL PROMPT -> raw JSON in $out/raw/LABEL.json
session() {
  local wd="$1" arm="$2" label="$3" prompt="$4"
  local args=(-p "$prompt" --output-format json --permission-mode "$PERM"
              --setting-sources project --strict-mcp-config --no-session-persistence)
  [ -n "$model" ] && args+=(--model "$model")
  [ -n "$budget" ] && args+=(--max-budget-usd "$budget")
  if [ "$arm" != baseline ]; then
    args+=(--plugin-dir "$PLUGIN"); [ -n "$agent" ] && args+=(--agent "$agent")
  fi
  (cd "$wd" && CTX_AGENT_NONINTERACTIVE=1 CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 \
     "$CLAUDE_BIN" "${args[@]}" </dev/null >"$out/raw/$label.json" 2>"$out/logs/$label.stderr")
}

record() { # REP ARM PHASE PASS LABEL
  local m; m=$(metrics "$out/raw/$5.json")
  [ -n "$m" ] || m=$(printf '0\t0\t0\t0\t0\t0\t0\t1')
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$m" >> "$RESULTS"
  printf '  %-9s phase %s  %s  %s\n' "$2" "$3" "$([ "$4" = 1 ] && echo pass || echo FAIL)" \
    "$(cut -f1,5 <<<"$m" | awk -F'\t' '{printf "$%.4f  out=%s", $1, $2}')"
}

# Session memory = what the agent or hooks leave for the next session. Guides stay.
wipe_memory() {
  local h="$1/.harness"
  cp "$PLUGIN/templates/harness/state.md" "$h/state.md"
  rm -rf "$h/plans/active"
  rm -f "$h/checkpoint.md" "$h/.ledger" "$h/.state-nudged" "$h/.fast-checked"
  commit_all "$1" "bench: reset session memory"
}

echo "ctx-agent bench · task $(basename "$task") · arms $arms · reps $reps · out $out"
for rep in $(seq 1 "$reps"); do
  base="$out/work/r$rep"; mkdir -p "$base"
  if [[ ",$arms," == *",ctx"* ]]; then
    setup="$base/setup/$(basename "$task")"; mkdir -p "$base/setup"  # dir name = project name in AGENTS.md
    fixture "$setup"
    session "$setup" ctx "r$rep-setup" "/ctx-agent:harness-init $PREAMBLE"
    ok=0; [ -f "$setup/AGENTS.md" ] && [ -d "$setup/.harness" ] && ok=1
    commit_all "$setup" "harness init"
    record "$rep" ctx-setup 0 "$ok" "r$rep-setup"
  fi
  for arm in ${arms//,/ }; do
    wd="$base/$arm"
    if [ "$arm" = baseline ]; then fixture "$wd"; else cp -R "$setup" "$wd"; fi
    for ph in $(seq 1 "$nphases"); do
      [ "$arm" = ctx ] && [ "$ph" -gt 1 ] && wipe_memory "$wd"
      label="r$rep-$arm-p$ph"
      session "$wd" "$arm" "$label" "$PREAMBLE

$(cat "$task/phase$ph.md")"
      ok=0; bash "$task/check$ph.sh" "$wd" >"$out/logs/$label.check" 2>&1 && ok=1
      record "$rep" "$arm" "$ph" "$ok" "$label"
      commit_all "$wd" "phase $ph"
    done
  done
done
"$HERE/report.sh" "$RESULTS" | tee "$out/summary.md"
