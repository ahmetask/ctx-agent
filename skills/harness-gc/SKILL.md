---
name: harness-gc
description: Garbage-collect harness entropy — dead references, stale or over-budget context, contradictions between guides and sensors, silent and recurring sensors — and evolve the harness (steering loop). Use periodically, when session start reports drift, or when context feels bloated.
---

# harness-gc

Prefer delegating to the `context-harness` agent.

1. `bash "${CLAUDE_PLUGIN_ROOT}/scripts/drift.sh"` and `sensors.sh drift`. Handle each finding:
   - dead-ref → fix the path or delete the line
   - stale → re-verify the module against its `covers:` paths; update or delete lines
   - budget → compress: delete what code/tools already express, dedupe, move detail to a module
   - recurring → encode the lesson: computational sensor + `hint.` first, guide rule second;
     record in harness.md › Lessons
   - silent → seed a known violation in a scratch copy (or reason about config) to prove the
     sensor can fire; fix or remove it
   - orphan → align harness.md with .harness/config
2. Coherence: find guide rules that contradict each other or a sensor; resolve or escalate.
   Remove rules now enforced by a sensor (they're duplicated tokens).
3. Re-assess harnessability gaps in harness.md; propose at most 3 next controls, ranked by
   (failures prevented ÷ cost). Behaviour-harness gaps go to the human.
4. Verify `drift.sh` and `budget.sh -q` clean. Report before/after token totals.
