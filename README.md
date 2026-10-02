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
  plans/active/<slug>.md     # exec plans for multi-session work (committed); done → plans/completed/
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
| `harness-reviewer` agent | read-only review of the diff: sensors first, then guides, decisions and the plan; ranked findings |
| SessionStart hook | inject state + module index + drift summary |
| PostToolUse hook | ledger the edit, run `edit` sensors, feed failures back (exit 2) |
| Stop hook | run `fast` sensors before the turn ends; request sync after N files (`gate.stop`) |

## Coding workflow

`harness-architect` plans, `harness-coder` builds, `harness-reviewer` checks. The coder delegates
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

## Development

`bash tests/run.sh` — integration tests against throwaway repos.
