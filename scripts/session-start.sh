#!/usr/bin/env bash
# SessionStart hook: inject the *minimum* context. AGENTS.md is already loaded
# via CLAUDE.md, so we only add: current state, the module index (progressive
# disclosure: titles, not bodies) and a one-line drift summary.
. "$(dirname "$0")/lib.sh"
PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -n "${CLAUDE_ENV_FILE:-}" ] && echo "export CTX_AGENT_ROOT=\"$PLUGIN_ROOT\"" >> "$CLAUDE_ENV_FILE"

if ! is_initialized; then
  echo "[ctx-agent] No harness in this repo. Suggest /ctx-agent:harness-init when the user starts substantial work."
  exit 0
fi

echo "[ctx-agent] harness active · scripts: $PLUGIN_ROOT/scripts"
if [ -s "$HARNESS_DIR/state.md" ]; then
  echo "## state (.harness/state.md)"
  grep -v '^[[:space:]]*$' "$HARNESS_DIR/state.md" | grep -v '^<!--' | head -n 25
fi
if [ -d "$HARNESS_DIR/context" ]; then
  echo "## modules — Read only when the task touches them"
  for f in "$HARNESS_DIR"/context/*.md; do
    [ -f "$f" ] || continue
    when=$(sed -n 's/^>[[:space:]]*[Ww]hen to read:[[:space:]]*//p' "$f" | head -n 1)
    echo "- .harness/context/$(basename "$f") — ${when:-no 'When to read:' line}"
  done
fi
d=$("$(dirname "$0")/drift.sh" 2>/dev/null)
if [ -n "$d" ]; then
  echo "## harness drift ($(printf '%s\n' "$d" | wc -l | tr -d ' ') findings; fix via /ctx-agent:harness-gc when convenient)"
  printf '%s\n' "$d" | head -n 5
fi
exit 0
