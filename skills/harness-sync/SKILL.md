---
name: harness-sync
description: Keep agent context true and small after code changes — update only the affected lines of AGENTS.md, .harness/context modules and state.md based on the edit ledger and git diff, then clear the ledger. Use after a task touches several files, when the Stop gate requests it, or before ending a session.
---

# harness-sync

Prefer delegating to the `context-harness` agent (keeps the main context small).

1. Inputs only: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh" show`, `git diff --stat`,
   and `drift.sh`. Read a changed file only if its role in the map may have changed.
2. For each change ask: does a guide now say something false or missing that an agent
   could not discover from code in one Grep? If not, change nothing.
   - new/removed/renamed dir, command, dependency rule, invariant → update the map/module line
   - a decision with a non-obvious why → one line in `decisions.md`
   - a lesson learned the hard way → rule (or better, a sensor + `hint.`), log it in harness.md › Lessons
3. Overwrite `.harness/state.md`: focus / in progress / next / open questions (≤ 400 tokens).
4. `budget.sh -q` must pass; if over, compress: remove what code already says, merge, move detail out.
5. `ledger.sh clear`. Report changed files in ≤ 5 lines.
