#!/usr/bin/env bash
# PostToolUse hook (Edit|Write|MultiEdit|NotebookEdit).
# 1) Records the touched file in the ledger (input for /harness-sync).
# 2) Runs edit-tier computational sensors on that file. On failure exits 2 so
#    the squeezed failure + fix hint is fed straight back to the agent.
. "$(dirname "$0")/lib.sh"
is_initialized || exit 0
input=$(cat)
f=$(json_field "$input" '.tool_input.file_path')
[ -z "$f" ] && f=$(json_field "$input" '.tool_input.notebook_path')
[ -z "$f" ] && exit 0
case "$f" in /*) ;; *) f="$ROOT/$f" ;; esac
case "$f" in "$ROOT"/*) ;; *) exit 0 ;; esac
rel="${f#"$ROOT"/}"
case "$rel" in
  AGENTS.md|CLAUDE.md|.harness/*) exit 0 ;;  # context edits are the sync itself
esac
echo "$rel" >> "$LEDGER"
[ -f "$f" ] || exit 0
out=$("$(dirname "$0")/sensors.sh" edit "$rel") || { printf '%s\n' "$out" >&2; exit 2; }
exit 0
