# 2026-10-03 · inventory · claude-haiku-4-5 · 1 rep

First end-to-end run (`bench/run.sh --reps 1 --model claude-haiku-4-5-20251001 --max-budget-usd 1`).
n=1 on a ~600-line fixture: it shows the pipeline works, not a verdict. See the notes at the end.

## Per phase (mean per session)

| arm | phase | n | pass | cost $ | tokens | fresh | cache read | output | turns |
|---|---|---|---|---|---|---|---|---|---|
| ctx-setup | 0 | 1 | 1/1 | 0.1489 | 783245 | 26678 | 756567 | 6696 | 30.0 |
| baseline | 1 | 1 | 1/1 | 0.1662 | 940432 | 26864 | 913568 | 7487 | 25.0 |
| baseline | 2 | 1 | 1/1 | 0.1361 | 701152 | 25491 | 675661 | 6239 | 19.0 |
| baseline | 3 | 1 | 1/1 | 0.1846 | 1035320 | 31058 | 1004262 | 7784 | 26.0 |
| ctx | 1 | 1 | 1/1 | 0.2319 | 1361182 | 36278 | 1324904 | 9411 | 32.0 |
| ctx | 2 | 1 | 1/1 | 0.1611 | 853039 | 29775 | 823264 | 6828 | 21.0 |
| ctx | 3 | 1 | 1/1 | 0.1911 | 1026631 | 34625 | 992006 | 7972 | 24.0 |
| ctx-mem | 1 | 1 | 1/1 | 0.2503 | 1470441 | 38393 | 1432048 | 10561 | 34.0 |
| ctx-mem | 2 | 1 | 1/1 | 0.1690 | 887912 | 30784 | 857128 | 7653 | 22.0 |
| ctx-mem | 3 | 1 | 1/1 | 0.2152 | 1142838 | 38769 | 1104069 | 9525 | 26.0 |

## Whole task (phases 1+, mean per rep)

| arm | pass | cost $ | Δ cost | tokens | Δ tokens | fresh | cost $ incl. setup | Δ incl. setup |
|---|---|---|---|---|---|---|---|---|
| baseline | 3/3 | 0.4869 | +0.0% | 2676904 | +0.0% | 83413 | 0.4869 | +0.0% |
| ctx | 3/3 | 0.5842 | +20.0% | 3240852 | +21.1% | 100678 | 0.7331 | +50.6% |
| ctx-mem | 3/3 | 0.6345 | +30.3% | 3501191 | +30.8% | 107946 | 0.7835 | +60.9% |

Setup (harness-init, once per repo, shared by ctx arms): $0.1489, 783245 tokens.
Δ is relative to baseline. Compare arms only where pass rates match; a cheaper failure is not a win.

## Notes
- The harness cost more here: +20% (`ctx`) and +30% (`ctx-mem`) per task, and +51%/+61% counting setup.
- Cost follows turns: about 97% of tokens are cache reads of the whole context, re-read on every turn.
  Phase 1 took 32–34 turns in the ctx arms vs 25 for baseline. The extra turns come from the
  state.md handoff that the Stop hook asks for, the fast sensors at Stop, and reading the map and modules.
- Memory didn't pay off at this size: baseline re-discovered the 600-line repo in 19 turns (phase 2).
- To test next: larger fixture, `--reps 3`, a stronger model, and an arm with `gate.state=off`
  to price the handoff turn.
