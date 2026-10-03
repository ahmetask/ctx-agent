#!/usr/bin/env bash
# Phase 2 acceptance: alerts. Hidden from the agent.
. "$(dirname "$0")/lib.sh" "$1"
(cd "$R" && make -s test >/dev/null 2>&1) || fail "make test"
seed
out=$(inv alerts) || fail "alerts exit code"
[ "$(sed -n 1p <<<"$out" | norm)" = "SKU NAME QTY REORDER SHORT" ] || fail "header: $(sed -n 1p <<<"$out")"
sed -n 2p <<<"$out" | grep -Eqx -- '-+( +-+){4}' || fail "rule line like list: $(sed -n 2p <<<"$out")"
rows=$(sed 1,2d <<<"$out" | norm)
[ "$rows" = "B Bolt 0 4 4
A Anchor 3 5 2
E Eyelet 2 2 0" ] || fail "rows/order: $rows"
fresh; inv add C Cog 10 5 >/dev/null
[ "$(inv alerts)" = "no alerts" ] || fail "empty case"
echo "PASS phase 2"
