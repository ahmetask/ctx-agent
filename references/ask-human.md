# Ask, don't assume

> When to read: you are about to act on something the code, the harness and the request don't
> settle (architect, coder, tester, reviewer).

## When to ask
- Two plausible readings of the request lead to different code or behaviour.
- The change alters public API, CLI output, schema, stored data format or user-visible behaviour
  beyond what was literally requested.
- A `(human)` line, AGENTS.md rule, decision or sensor conflicts with the task.
- Deleting files, adding a dependency, security-relevant code, migrations, anything irreversible.
- A fact you need is tagged `(agent, unverified)`/`(inferred)` or comes from a `stale` module, and
  the code can't confirm it in one Grep.

Don't ask what one Grep, a test run or `git log` answers. Look first, ask second.

## How to ask
- Batch: ≤ 3 questions per round, each answerable in one click. Use the AskUserQuestion tool
  when you have it; otherwise end your turn with the questions.
- Each question: what you found (file:line), the options, and your recommended default first.
- While waiting, do only work that every answer keeps.

## No human available
Headless runs (`claude -p`, `CTX_AGENT_NONINTERACTIVE=1`, or no AskUserQuestion tool):
- Reversible choice → take the recommended default, and record it in `.harness/state.md` ›
  open questions as `Q: <question> — took: <default> (reversible)`.
- Irreversible or out of scope → don't do it; record the question and stop that branch of work.
- Never write an assumption into a guide as fact: tag it `(agent, unverified)`.

## After the answer
Record it where it binds: a `(human)` line in the module or AGENTS.md, a `decisions.md` line,
or the exec plan's Decisions. Remove the question from state.md.
