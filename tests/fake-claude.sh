#!/usr/bin/env bash
# Stand-in for `claude -p ... --output-format json` used by tests/run.sh to exercise bench/run.sh.
# Setup prompt -> runs init.sh. Phase 1 -> applies the task's reference.patch. With --plugin-dir
# it writes state.md (like an agent with memory) and reports fewer tokens. Logs what it saw.
prompt=""; plugin=""
while [ $# -gt 0 ]; do
  case "$1" in -p) prompt="$2"; shift 2 ;; --plugin-dir) plugin="$2"; shift 2 ;; *) shift ;; esac
done
seen=$(sed -n 's/^- focus:[[:space:]]*//p' .harness/state.md 2>/dev/null)
echo "$(basename "$PWD") plugin=${plugin:+yes} focus=${seen:-none}" >> "$FAKE_LOG"
case "$prompt" in
  /ctx-agent:harness-init*) bash "$plugin/scripts/init.sh" >/dev/null ;;
  *"part 1 of 3"*) git apply "$FAKE_PATCH" ;;
esac
ph=$(grep -o 'part [0-9]' <<<"$prompt" | cut -c6)
[ -n "$plugin" ] && [ -n "$ph" ] && sed -i "s/^- focus:.*/- focus: phase $ph/" .harness/state.md
in=$([ -n "$plugin" ] && echo 100 || echo 300)
printf '{"type":"result","is_error":false,"num_turns":4,"duration_ms":1000,"total_cost_usd":%s,"usage":{"input_tokens":1,"cache_creation_input_tokens":1,"cache_read_input_tokens":1,"output_tokens":1},"modelUsage":{"m":{"inputTokens":%s,"outputTokens":50,"cacheReadInputTokens":1000,"cacheCreationInputTokens":200,"costUSD":0}}}\n' \
  "$([ -n "$plugin" ] && echo 0.1 || echo 0.3)" "$in"
