#!/usr/bin/env bash
# Token budget check for harness context (approx tokens = chars/4).
#   budget.sh [-q]   -q: print only violations
# Exit 1 when any budget is exceeded. Budgets live in .harness/config.
. "$(dirname "$0")/lib.sh"
quiet=0; [ "${1:-}" = "-q" ] && quiet=1

b_map=$(cfg_get budget.map 1200)
b_mod=$(cfg_get budget.module 800)
b_state=$(cfg_get budget.state 400)
b_total=$(cfg_get budget.always_loaded 1800)

over=0; always=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  t=$(approx_tokens "$f"); rel="${f#"$ROOT"/}"
  case "$rel" in
    AGENTS.md) lim=$b_map; always=$((always + t)) ;;
    .harness/state.md) lim=$b_state; always=$((always + t)) ;;
    *) lim=$b_mod ;;
  esac
  if [ "$t" -gt "$lim" ]; then over=1; echo "OVER  ${t}/${lim}t  $rel"
  elif [ $quiet -eq 0 ]; then echo "ok    ${t}/${lim}t  $rel"; fi
done < <(context_files)

if [ "$always" -gt "$b_total" ]; then over=1; echo "OVER  ${always}/${b_total}t  always-loaded total (AGENTS.md + state.md)"
elif [ $quiet -eq 0 ]; then echo "ok    ${always}/${b_total}t  always-loaded total"; fi
exit $over
