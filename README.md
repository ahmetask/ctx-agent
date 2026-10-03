# ctx-agent

A Claude Code plugin that applies **harness engineering** to any repository, in any language.
It keeps the agent's context **small, true and token-budgeted**, and wraps the agent in
**sensors** so it corrects itself before a human has to.

Based on Birgitta Böckeler, [*Harness engineering for coding agent users*](https://martinfowler.com/articles/harness-engineering.html)
(Agent = Model + Harness). The rules the plugin enforces are in [`RULES.md`](RULES.md).

## How it maps to the article

| Article concept | ctx-agent implementation |
|---|---|
| Guides (feedforward) | `AGENTS.md` map + `.harness/context/*.md` modules loaded on demand |
| Sensors (feedback) | `sensor.<tier>.<name>` commands in `.harness/config`, run by hooks |
| Computational vs inferential | scripts/linters/tests (hooks) vs `/harness-check` review skill |
| LLM-optimised sensor output | silent on success; squeezed failures + `hint.<name>` fix instructions |
| Keep quality left | tiers: `edit` (PostToolUse) → `fast` (Stop gate) → `slow` (CI) → `drift` (continuous) |
| Continuous drift sensors / garbage collection | `drift.sh` + `/harness-gc` |
| Steering loop | sensor log → *recurring* failures → promote to guide/sensor; harness.md › Lessons |
| "Sensors that never fire" | *silent* sensor detection |
| Regulation categories | `.harness/harness.md` control matrix: maint / arch / behav |
| Harnessability, ambient affordances | `detect-stack.sh` affordance report → harness.md |
| Harness coherence | one control map; *orphan* detection; gc resolves guide/sensor conflicts |
| Guides written for an LLM | `references/agent-prompts.md` checklist + `/harness-brief` task briefs (adapted from [prompt-master](https://github.com/nidhinjs/prompt-master)) |
| Role of the human | explicit escalation list in `AGENTS.md`; ask-don't-assume protocol (`references/ask-human.md`); behaviour-harness gaps go to the human |

## Token economy

- **Map, not encyclopedia**: `AGENTS.md` ≤ 1200 tokens by default; details live in modules.
- **Progressive disclosure**: session start injects only the state file and module *titles*
  ("When to read: …"), not their bodies. Measured: < 2 KB per session.
- **Budgets enforced** by `budget.sh` (chars/4). Over budget → `drift.sh` reports it.
- **Rules → sensors**: anything checkable becomes a command; prose costs tokens every session,
  sensors cost tokens only when they fail.
- **Isolated maintenance**: sync/gc run in the `context-harness` subagent, so the main
  conversation never reads the whole context.
- **Incremental sync**: an edit ledger tells sync exactly what changed; it edits only the affected lines.
- **Read guard**: whole-file Reads above `guard.read_max_tokens` (8000) are refused with a
  "Grep, then Read with offset/limit" hint.
- **Measured, not claimed**: `bench/` runs a 3-session job with and without the harness and
  memory, and reports cost and tokens per phase. See [Benchmark](#benchmark).

## Session memory (continue where you left off)

Two files, two writers, both shown at session start:

| file | written by | holds |
|---|---|---|
| `.harness/state.md` (committed) | the agent; the Stop hook asks once per session if code changed and it didn't | intent: focus, in progress, next, open questions |
| `.harness/checkpoint.md` (local) | hooks: Stop, PreCompact, SessionEnd; costs no tokens to write | facts: branch/HEAD, uncommitted files, files edited since sync, failing sensors, active plan + next action |
| `.harness/plans/active/*.md` (committed) | harness-architect / harness-coder | multi-session exec plans with gates and evidence |

After `/compact`, `/clear` or a new session, the agent starts from these instead of re-reading code.

## Install

```
/plugin marketplace add ahmetask/ctx-agent
/plugin install ctx-agent@ctx-agent
```
Then in any repo: `/ctx-agent:harness-init`.

## What gets created in your repo

```
AGENTS.md                    # the map (CLAUDE.md just imports it: @AGENTS.md)
.harness/
  config                     # sensors by tier, hints, budgets, gate settings (KEY=value)
  harness.md                 # control matrix, harnessability, gaps, lessons
  state.md                   # rolling handoff for the next session
  context/architecture.md    # on-demand modules, each with "When to read:" + "covers:" paths
  context/conventions.md
  context/decisions.md
  plans/active/<slug>.md     # exec plans for multi-session work (committed); done → plans/completed/
  checkpoint.md              # auto session memory written by hooks (local, gitignored)
  .ledger .sensor-log        # local, gitignored
```

## Skills, agent, hooks

| | Purpose |
|---|---|
| `/ctx-agent:harness-init` | scaffold + detect stack + fill from the code |
| `/ctx-agent:harness-sync` | update only affected context lines from the ledger; clear it |
| `/ctx-agent:harness-check` | computational sensors, then inferential review of the diff |
| `/ctx-agent:harness-gc` | dead refs, stale/over-budget docs, recurring/silent/orphan sensors |
| `/ctx-agent:harness-brief` | rough task or weak prompt → scoped, verifiable brief for a coding agent |
| `context-harness` agent | does the above in an isolated context |
| `harness-architect` agent | plans a change: constraints, options, small verifiable steps → `.harness/plans/active/<slug>.md` |
| `harness-coder` agent | implements through gated lifecycle (orient → plan → test → implement → review → verify → remember → document), keeps context true via harness-sync, resumes exec plans |
| `harness-tester` agent | tests first: failing test before the fix, characterization tests, proves each test fails without the change; behaviour gaps |
| `harness-reviewer` agent | read-only review of the diff: sensors first, then guides, decisions and the plan; ranked findings |
| SessionStart hook | inject state + checkpoint + module index + active plans + drift summary |
| PreToolUse hook (Read) | read guard: refuse oversized whole-file reads with a Grep/offset hint |
| PostToolUse hook | ledger the edit, run `edit` sensors, feed failures back (exit 2) |
| Stop hook | refresh checkpoint; run `fast` sensors; request sync after N files (`gate.stop`); once per session ask for a state.md handoff (`gate.state`) |
| PreCompact / SessionEnd hooks | refresh checkpoint so a compacted or new session can resume |

## Coding workflow

`harness-architect` plans, `harness-tester` pins behaviour, `harness-coder` builds, `harness-reviewer` checks.
All four follow the ask-don't-assume protocol: ambiguity becomes a question with a recommended
default (AskUserQuestion when available); headless runs record it in state.md and take only
reversible defaults. The coder delegates
to the other two when it runs as the main agent (`claude --agent ctx-agent:harness-coder`); as a
subagent it follows their method itself. It writes context as it learns (Remember gate =
`/harness-sync` with provenance tags), so `context-harness` stays the tool for init and gc.
Exec-plan format and provenance tags: [`references/exec-plans.md`](references/exec-plans.md).
Session start lists active plans so a new session resumes them.

## Config example

```
sensor.edit.ruff=ruff check {file}
sensor.fast.test=pytest -q -x
sensor.slow.mutation=mutmut run
sensor.drift.deadcode=vulture src
hint.ruff=Fix the reported rule; never add noqa without a comment saying why.
gate.stop=block
```

Requirements: `bash`, `git`, coreutils. `jq` or `python3` optional (used for JSON when present).

## Benchmark

```
bench/run.sh --reps 3            # baseline vs ctx vs ctx-mem on a 3-phase job; prints summary.md
```
Each phase is a fresh `claude -p` session, so phases 2–3 show what memory saves when work resumes.
Bring any repo as a task (`repo/`, `phase<N>.md`, hidden `check<N>.sh`). Method and caveats:
[`bench/README.md`](bench/README.md).

## Development

`bash tests/run.sh` — integration tests against throwaway repos.
