#!/usr/bin/env bash
# ledger.sh show|clear — files changed since the last context sync.
. "$(dirname "$0")/lib.sh"
case "${1:-show}" in
  show)  [ -s "$LEDGER" ] && sort -u "$LEDGER" ;;
  clear) : > "$LEDGER" 2>/dev/null; rm -f "$HARNESS_DIR/.fast-checked"; echo "ledger cleared" ;;
  *) echo "usage: ledger.sh show|clear" >&2; exit 2 ;;
esac
exit 0
