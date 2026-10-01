#!/usr/bin/env bash
# Shared helpers for ctx-agent scripts. Source, don't execute.
# Dependency-free: bash + coreutils. jq/python3 used only if present.

set -u

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

ROOT="${CTX_REPO_ROOT:-$(repo_root)}"
HARNESS_DIR="$ROOT/.harness"
CONFIG="$HARNESS_DIR/config"
LEDGER="$HARNESS_DIR/.ledger"

# cfg_get KEY DEFAULT -> value from .harness/config (KEY=value lines; never sourced/eval'd)
cfg_get() {
  local key="$1" def="${2:-}" line
  if [ -f "$CONFIG" ]; then
    line=$(grep -E "^[[:space:]]*${key}=" "$CONFIG" | tail -n 1)
    if [ -n "$line" ]; then
      line="${line#*=}"
      case "$line" in \"*\") line="${line#\"}"; line="${line%\"}" ;; esac
      printf '%s' "$line"
      return
    fi
  fi
  printf '%s' "$def"
}

# approx_tokens FILE -> integer (chars/4, the usual rule of thumb)
approx_tokens() {
  local c
  c=$(wc -c < "$1" 2>/dev/null || echo 0)
  echo $(( (c + 3) / 4 ))
}

# json_field JSON PATH  e.g. json_field "$in" '.tool_input.file_path'
json_field() {
  local json="$1" path="$2" key
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r "$path // empty" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$json" | python3 -c '
import json,sys
d=json.load(sys.stdin)
for k in sys.argv[1].strip(".").split("."):
    d=d.get(k) if isinstance(d,dict) else None
print("" if d is None else (str(d).lower() if isinstance(d,bool) else d))' "$path" 2>/dev/null
  else
    key="${path##*.}"
    printf '%s' "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\).*/\1/p" | head -n 1
  fi
}

# Context files the harness owns (the "map" + on-demand modules + state).
context_files() {
  [ -f "$ROOT/AGENTS.md" ] && echo "$ROOT/AGENTS.md"
  [ -d "$HARNESS_DIR/context" ] && find "$HARNESS_DIR/context" -type f -name '*.md' | sort
  [ -f "$HARNESS_DIR/state.md" ] && echo "$HARNESS_DIR/state.md"
  return 0
}

# Truncate noisy output: keep head+tail so failures stay visible but cheap.
squeeze() {
  local max="${1:-40}"
  awk -v max="$max" '{ l[NR]=$0 } END {
    if (NR <= max) { for (i=1;i<=NR;i++) print l[i]; exit }
    h=int(max/4); t=max-h
    for (i=1;i<=h;i++) print l[i]
    printf "... [%d lines elided by ctx-agent] ...\n", NR-max
    for (i=NR-t+1;i<=NR;i++) print l[i]
  }'
}

is_initialized() { [ -d "$HARNESS_DIR" ]; }

SENSOR_LOG="$HARNESS_DIR/.sensor-log"

# cfg_sensors TIER -> "name<TAB>command" lines for keys sensor.<tier>.<name>=cmd
cfg_sensors() {
  local tier="$1"
  [ -f "$CONFIG" ] || return 0
  grep -E "^[[:space:]]*sensor\.${tier}\.[A-Za-z0-9_-]+=" "$CONFIG" | while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    local key="${line%%=*}" cmd="${line#*=}"
    [ -n "$cmd" ] && printf '%s\t%s\n' "${key##*.}" "$cmd"
  done
}

# hint_for NAME -> remediation hint (hint.<name>=...) to append to failures
hint_for() { cfg_get "hint.$1" ""; }
