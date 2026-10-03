#!/usr/bin/env bash
# PreToolUse hook (Read): refuse whole-file reads above guard.read_max_tokens.
# The agent retries with Grep or offset/limit, so a large file costs a few
# hundred tokens instead of thousands. guard.read_max_tokens=0 disables it.
. "$(dirname "$0")/lib.sh"
is_initialized || exit 0
input=$(cat)
max=$(cfg_get guard.read_max_tokens 8000)
[ "$max" -gt 0 ] 2>/dev/null || exit 0
[ -n "$(json_field "$input" '.tool_input.limit')$(json_field "$input" '.tool_input.offset')" ] && exit 0
f=$(json_field "$input" '.tool_input.file_path')
[ -f "$f" ] || exit 0
case "${f,,}" in *.png|*.jpg|*.jpeg|*.gif|*.webp|*.bmp|*.pdf|*.ipynb) exit 0 ;; esac
t=$(approx_tokens "$f")
[ "$t" -le "$max" ] && exit 0
lines=$(wc -l < "$f" | tr -d ' ')
echo "[ctx-agent] ${f#"$ROOT"/} is ~${t} tokens (${lines} lines, guard.read_max_tokens=${max}). Grep for what you need, then Read with offset/limit (e.g. limit=200)." >&2
exit 2
