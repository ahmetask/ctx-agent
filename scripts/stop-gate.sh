#!/usr/bin/env bash
# Stop hook: "keep quality left". Before the agent ends its turn:
#   1) run fast-tier sensors if code changed this session -> block on failure
#   2) if many files changed, ask for a context sync so the guides don't drift
# gate.stop = block | warn | off   (.harness/config)
. "$(dirname "$0")/lib.sh"
is_initialized || exit 0
input=$(cat)
[ "$(json_field "$input" '.stop_hook_active')" = "true" ] && exit 0
mode=$(cfg_get gate.stop block)
[ "$mode" = off ] && exit 0
[ -s "$LEDGER" ] || exit 0

marker="$HARNESS_DIR/.fast-checked"
reason=""
if [ ! -f "$marker" ] || [ "$LEDGER" -nt "$marker" ]; then
  out=$("$(dirname "$0")/sensors.sh" fast) || reason="Fast sensors failed. Fix, then finish:
$out"
  [ -z "$reason" ] && touch "$marker"
fi
if [ -z "$reason" ]; then
  thr=$(cfg_get gate.sync_threshold 5)
  c=$(sort -u "$LEDGER" | wc -l | tr -d ' ')
  [ "$c" -ge "$thr" ] && reason="$c files changed since last context sync. Run /ctx-agent:harness-sync (delegate to the context-harness agent) so AGENTS.md/modules/state.md stay true and small."
fi
[ -z "$reason" ] && exit 0
if [ "$mode" = warn ]; then echo "[ctx-agent] $reason" >&2; exit 0; fi
if command -v jq >/dev/null 2>&1; then
  jq -n --arg r "$reason" '{decision:"block",reason:$r}'
else
  python3 -c 'import json,sys;print(json.dumps({"decision":"block","reason":sys.argv[1]}))' "$reason"
fi
exit 0
