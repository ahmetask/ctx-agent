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
| Role of the human | explicit escalation list in `AGENTS.md`; behaviour-harness gaps go to the human |

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
  .ledger .sensor-log        # local, gitignored
```

## Skills, agent, hooks

| | Purpose |
|---|---|
| `/ctx-agent:harness-init` | scaffold + detect stack + fill from the code |
| `/ctx-agent:harness-sync` | update only affected context lines from the ledger; clear it |
| `/ctx-agent:harness-check` | computational sensors, then inferential review of the diff |
| `/ctx-agent:harness-gc` | dead refs, stale/over-budget docs, recurring/silent/orphan sensors |
| `context-harness` agent | does the above in an isolated context |
| SessionStart hook | inject state + module index + drift summary |
| PostToolUse hook | ledger the edit, run `edit` sensors, feed failures back (exit 2) |
| Stop hook | run `fast` sensors before the turn ends; request sync after N files (`gate.stop`) |

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

## Development

`bash tests/run.sh` — integration tests against throwaway repos.
