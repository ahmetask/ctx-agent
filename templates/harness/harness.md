# Harness map
> When to read: changing guides/sensors, or running /ctx-agent:harness-gc.

<!-- The harness as one system, so guides and sensors stay coherent.
     direction: ff=feedforward guide, fb=feedback sensor
     type: C=computational, I=inferential
     category: maint | arch | behav
     timing: edit | fast | slow | drift | human -->

| control | dir | type | category | timing | where |
|---|---|---|---|---|---|
| project map | ff | I | maint | always | `AGENTS.md` |
{{CONTROLS}}
| change plan | ff | I | arch | human | harness-architect agent → `.harness/plans/active/` |
| context review | fb | I | maint | fast | /ctx-agent:harness-check, harness-reviewer agent |
| drift & entropy GC | fb | C+I | maint | drift | /ctx-agent:harness-gc |

## Harnessability
{{AFFORDANCES}}

## Gaps (prioritised; human decides)
<!-- e.g. "behav: no spec/approved fixtures for billing" -->

## Lessons (steering loop)
<!-- date · recurring issue · control added/changed. Promote: repeat ≥3 → rule or sensor. -->
