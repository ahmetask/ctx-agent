#!/usr/bin/env bash
# Phase 3 acceptance: restock (+ phases 1-2 still hold). Hidden from the agent.
d="$(dirname "$0")"
"$d/check1.sh" "$1" >/dev/null || { echo "FAIL: phase 1 regressed"; exit 1; }
"$d/check2.sh" "$1" >/dev/null || { echo "FAIL: phase 2 regressed"; exit 1; }
. "$d/lib.sh" "$1"
seed
[ "$(inv restock --dry-run)" = 'would restock 3 item(s), 17 unit(s), cost $13.00' ] || fail "dry-run: $(inv restock --dry-run)"
inv show A | grep -qx 'qty: 3' || fail "dry-run saved"
[ "$(inv restock)" = 'restocked 3 item(s), 17 unit(s), cost $13.00' ] || fail "restock line"
inv show B | grep -qx 'qty: 8' && inv show A | grep -qx 'qty: 10' && inv show C | grep -qx 'qty: 10' || fail "quantities"
[ "$(inv alerts)" = "no alerts" ] || fail "alerts after restock"
[ "$(inv restock)" = 'restocked 0 item(s), 0 unit(s), cost $0.00' ] || fail "nothing to restock"
echo "PASS phase 3"
