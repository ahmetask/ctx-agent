# Exec plans and provenance

> When to read: writing, updating or resuming an exec plan, or recording a learning in the harness
> (harness-architect, harness-coder).

## Exec plans
Multi-step, risky or multi-session work gets a committed plan at `.harness/plans/active/<slug>.md`
(slug = kebab-case task name). It holds only what a fresh session needs to continue; durable
knowledge leaves it through harness-sync, never by staying in the plan.
On completion: run Remember and Document, then `git mv` it to `.harness/plans/completed/`.

```
# <task title>
- status: gate=<orient|plan|test|implement|review|verify|remember|document> · branch=<name> · base=<sha>
- approved: <yes, by whom/when | pending>

## Intent
<one sentence> — acceptance: <binary criteria>

## Steps
1. [ ] <step> → verify: <sensor command or concrete check>
2. [x] <step> → verify: <check> — evidence: <result, e.g. "sensors.sh fast: green">

## Decisions
- <decision> — <why> (promote to .harness/context/decisions.md if someone could undo it)

## Last operation
<command or edit> → <observed result | started, not confirmed>

## Next action
<one imperative line>

## Blockers / open questions
- <only what needs a human>
```
Update `Last operation` before and after each substantive edit or command; an operation recorded
as started but not confirmed is unknown until inspected.

## Provenance tags
Lines the agents add to AGENTS.md or `.harness/context/*.md` end with a tag; readers trust them as:

| tag | treat as |
|---|---|
| `(human)` | a requirement; never edit it, raise a question instead |
| `(code)`, `(history: <sha>)`, `(agent, verified)` | reliable; re-check if your change depends on it |
| `(agent, unverified)`, `(inferred)` | a hint only |
| untagged | as `(code)` |

`verified` means a sensor or a read of the code confirmed it this session. Open questions for the
human go in `.harness/state.md` › open questions.
