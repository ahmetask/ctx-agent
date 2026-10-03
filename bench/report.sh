#!/usr/bin/env bash
# report.sh RESULTS.tsv -> markdown summary (means over reps).
#   tokens  = input + cache_write + cache_read + output (everything the model processed)
#   fresh   = input + cache_write + output (excludes cheap cache reads)
#   cost    = total_cost_usd reported by Claude Code (accounts for cache pricing)
# The ctx arms share a one-off harness-init setup session; totals are shown without and with it.
set -u
[ -f "${1:-}" ] || { echo "usage: report.sh results.tsv" >&2; exit 2; }
awk -F'\t' '
NR == 1 { next }
{
  rep = $1; arm = $2; ph = $3; tok = $6 + $7 + $8 + $9; fresh = $6 + $7 + $9
  k = arm SUBSEP ph
  n[k]++; pass[k] += $4; cost[k] += $5; tk[k] += tok; fr[k] += fresh; cr[k] += $8
  out[k] += $9; turns[k] += $10; err[k] += $12
  if (!(arm in seen)) { seen[arm] = 1; order[++na] = arm }
  if (ph + 0 > maxph) maxph = ph + 0
  if (arm == "ctx-setup") { scost += $5; stok += tok; sn++ }
  else { wcost[arm] += $5; wtok[arm] += tok; wfr[arm] += fresh; wpass[arm] += $4; wn[arm]++
         if (!((arm, rep) in r)) { r[arm, rep] = 1; reps[arm]++ } }
}
function pct(a, b) { return b > 0 ? sprintf("%+.1f%%", 100 * (a - b) / b) : "–" }
END {
  print "## Per phase (mean per session)\n"
  print "| arm | phase | n | pass | cost $ | tokens | fresh | cache read | output | turns |"
  print "|---|---|---|---|---|---|---|---|---|---|"
  for (i = 1; i <= na; i++) for (p = 0; p <= maxph; p++) {
    k = order[i] SUBSEP p; if (!n[k]) continue
    printf "| %s | %s | %d | %d/%d | %.4f | %d | %d | %d | %d | %.1f |%s\n", order[i], p, n[k], pass[k], n[k],
      cost[k] / n[k], tk[k] / n[k], fr[k] / n[k], cr[k] / n[k], out[k] / n[k], turns[k] / n[k],
      (err[k] ? " " err[k] " error(s)" : "")
  }
  sc = sn ? scost / sn : 0; st = sn ? stok / sn : 0
  bc = reps["baseline"] ? wcost["baseline"] / reps["baseline"] : 0
  bt = reps["baseline"] ? wtok["baseline"] / reps["baseline"] : 0
  print "\n## Whole task (phases 1+, mean per rep)\n"
  print "| arm | pass | cost $ | Δ cost | tokens | Δ tokens | fresh | cost $ incl. setup | Δ incl. setup |"
  print "|---|---|---|---|---|---|---|---|---|"
  for (i = 1; i <= na; i++) {
    a = order[i]; if (a == "ctx-setup") continue
    c = wcost[a] / reps[a]; t = wtok[a] / reps[a]; s = (a == "baseline") ? 0 : sc
    printf "| %s | %d/%d | %.4f | %s | %d | %s | %d | %.4f | %s |\n", a, wpass[a], wn[a], c, pct(c, bc),
      t, pct(t, bt), wfr[a] / reps[a], c + s, pct(c + s, bc)
  }
  if (sn) printf "\nSetup (harness-init, once per repo, shared by ctx arms): $%.4f, %d tokens.\n", sc, st
  print "Δ is relative to baseline. Compare arms only where pass rates match; a cheaper failure is not a win."
}' "$1"
