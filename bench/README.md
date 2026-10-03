# Token benchmark: does context + memory pay for itself?

`bench/run.sh` runs the same multi-phase coding job under three arms and measures what each
costs. Every phase is a **separate headless session** (`claude -p`, never resumed), like a person
coming back the next day and typing the next request. Between sessions, the only memory is
what's left in the repository.

## Why three phases
A single session can't show whether memory helps: memory only matters when a *new* session has
to continue earlier work. With three dependent phases:

- phase 1 has no prior session, so it measures the **context harness alone** (the AGENTS.md map,
  modules, read guard, sensors) against baseline;
- phases 2–3 must build on phase 1's code and conventions, so they measure **resumption cost**:
  re-exploring code vs. starting from `state.md` + `checkpoint.md` + plans;
- phase 3 re-runs phases 1–2's checks, so a cheaper but broken session is caught.

## Arms
| arm | plugin + harness | memory between phases | isolates |
|---|---|---|---|
| `baseline` | no | git history only | — |
| `ctx` | yes | wiped (`state.md` reset, plans/checkpoint/ledger removed) | context harness |
| `ctx-mem` | yes | kept | context harness + memory |

`ctx − baseline` = what the context harness buys; `ctx-mem − ctx` = what memory buys.
Both ctx arms start from one shared `harness-init` setup session (phase 0). It's a one-off cost
per repo, so the report gives totals with and without it.

All arms get the same prompts, model, permission mode, `--setting-sources project`,
`--strict-mcp-config` (no MCP tools), `--no-session-persistence` and
`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`. Each arm works on its own copy of the fixture. The runner
commits after every phase in every arm, so all arms have the same git history to read.

## Run
```
bench/run.sh                                   # default task, 3 arms, 1 rep
bench/run.sh --reps 3 --model claude-sonnet-5-5 # repeat to see variance
bench/run.sh --arms baseline,ctx-mem --agent ctx-agent:harness-coder
bench/run.sh --task path/to/your-task --max-budget-usd 2
bench/report.sh <out>/results.tsv              # re-render a summary
```
Output goes to `$TMPDIR/ctx-bench-<time>/`: `results.tsv` (one row per session),
`summary.md`, `raw/*.json` (the full Claude Code result), `logs/*.check` (why a check failed)
and `work/` (every arm's final repo, for inspecting what the agent did).

Agents run with `bypassPermissions`. Use throwaway fixtures only.

## Metrics
From each session's JSON result. `modelUsage` covers every model the session used,
subagents included:
- **cost $**: `total_cost_usd`. This is the main number, because it weights cache reads
  (cheap) and cache writes (expensive) correctly.
- **tokens**: input + cache write + cache read + output, meaning everything the model processed.
- **fresh**: the same, minus cache reads.
- **turns**, **pass** (the hidden `check<N>.sh`).

Δ% is against baseline. Compare arms only when their pass rates match.

## Bring your own repo (repo-agnostic)
A task is a directory:
```
my-task/
  repo/          fixture copied per arm (any language; include its own test command)
  phase1.md      prompt for session 1 … phaseN.md
  check1.sh      hidden acceptance: check<N>.sh <workdir>, exit 0 = pass … checkN.sh
```
Keep each prompt self-contained for *what* to build, but don't restate *where* or *how*.
That knowledge is what a session without memory has to rediscover. Make the last check re-run
the earlier ones.

## Interpreting results honestly
- Run `--reps 3` or more: single runs vary by ±20% or more.
- The harness has fixed overhead: hook output, the state.md handoff turn, and sync requests.
  On a tiny repo it can cost more than it saves. The default fixture (~600 lines) is small on
  purpose so a run is cheap. Use a real repo for real numbers.
- Memory is wiped in `ctx`, but old `state.md` contents stay in git history. An agent that
  digs through `git log -p` can recover them. That's rare, and it would only shrink the measured
  gap, never inflate it.
