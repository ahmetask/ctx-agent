#!/usr/bin/env bash
# Phase 1 acceptance: reorder levels. Hidden from the agent.
. "$(dirname "$0")/lib.sh" "$1"
(cd "$R" && make -s test >/dev/null 2>&1) || fail "make test"
printf '{"version": 1, "items": [{"sku": "A", "name": "Anchor", "qty": 3, "unit_price_cents": 100}]}\n' > "$INVENTORY_DB"
out=$(inv show A) || fail "show on a pre-feature database"
grep -A1 '^qty:' <<<"$out" | tail -n 1 | grep -qx 'reorder_level: 0' || fail "reorder_level: 0 after qty: — got: $out"
[ "$(inv set-reorder A 5)" = "A reorder_level 5" ] || fail "set-reorder output"
inv show A | grep -qx 'reorder_level: 5' || fail "level not persisted"
err=$(inv set-reorder NOPE 1 2>&1 >/dev/null); [ $? -eq 2 ] && [ "$err" = "error: unknown sku 'NOPE'" ] || fail "unknown sku: $err"
for bad in -1 x 1.5; do
  err=$(inv set-reorder A "$bad" 2>&1 >/dev/null); [ $? -eq 2 ] && grep -q '^error: ' <<<"$err" || fail "bad level $bad: $err"
done
inv show A | grep -qx 'reorder_level: 5' || fail "bad level changed the item"
inv add Z Zip 1 1 >/dev/null && inv show Z | grep -qx 'reorder_level: 0' || fail "new item default level"
echo "PASS phase 1"
