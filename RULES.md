# Harness engineering rules (ctx-agent)

Source model: Böckeler, "Harness engineering for coding agent users" (martinfowler.com, 2026).
Agent = Model + Harness. We build the *outer* (user) harness: guides + sensors, steered by a human.

## R1 Guides and sensors come in pairs
- Guide = feedforward (steers before acting): AGENTS.md, context modules, skills, codemods.
- Sensor = feedback (observes after acting): tests, linters, type checks, structural tests, review.
- Guides alone → rules never verified. Sensors alone → same mistake repeated. Add the missing half.

## R2 Prefer computational over inferential
- If a rule can be checked by a tool, make it a sensor (lint rule, structural test, script) and
  delete the prose. Prose costs tokens on every session; a sensor costs tokens only on failure.
- Use inferential controls (LLM review) only for semantic judgement, and not on every edit.

## R3 Sensor output is written for an LLM
- Silent on success. On failure: the smallest excerpt that locates the problem + a fix hint
  (`hint.<name>` in .harness/config). Never dump full logs into context.

## R4 Keep quality left (timing tiers)
- edit: per-file, seconds. fast: before finishing a turn / commit. slow: CI only.
  drift: continuous, outside the change lifecycle. Put each check in the cheapest tier that catches it.

## R5 Context is a map, not an encyclopedia
- AGENTS.md ≤ budget.map tokens; only what cannot be cheaply discovered from code.
- Details live in `.harness/context/*.md`, each with a `> When to read:` line, loaded on demand
  (progressive disclosure). Session start shows titles, not bodies.
- Point to a canonical file instead of describing it. No duplication across files.
- Every line must be true, load-bearing and current; delete habit, history and narration.

## R6 Context is kept true continuously (sync), not rewritten occasionally
- Edits are recorded in a ledger; sync updates only the affected lines, then clears the ledger.
- Modules declare `<!-- covers: paths -->` so staleness is detected mechanically.
- state.md is a rolling handoff (overwrite, ≤ budget.state), never a log.

## R7 Garbage-collect entropy
- Periodically: dead references, stale modules, over-budget files, contradictions between
  guides and sensors, silent sensors (never fire → may detect nothing), recurring failures.

## R8 Steering loop
- An issue seen ≥ steer.recurring_threshold times is a harness defect: add/sharpen a guide or a
  sensor, record it in harness.md › Lessons. Prefer turning it into a computational sensor.

## R9 Regulate three categories explicitly
- maintainability (easiest; lint/types/tests), architecture fitness (boundaries, perf, observability),
  behaviour (spec as guide; tests/approved fixtures + human review as sensors). Track gaps in harness.md.

## R10 Direct the human, don't replace them
- Escalate: ambiguous requirements, sensor/rule conflicts, public API or behaviour changes,
  security, irreversible operations. Correctness needs a human-specified intent.

## R11 Harnessability & coherence
- Record ambient affordances (types, boundaries, tests, CI). Recommend the cheapest affordance
  that unlocks a new sensor. One harness map (harness.md) lists all controls; no orphans, no conflicts.
