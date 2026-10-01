---
name: harness-check
description: Run the harness feedback loop on the current change — computational sensors by tier, then a short inferential review against the repo's guides — and self-correct before handing to a human. Use before committing, opening a PR, or when asked to verify work.
---

# harness-check

1. Computational first (cheap, deterministic):
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/sensors.sh" fast` → fix every failure, re-run until green.
   Run `slow` only if asked or before a release.
2. Inferential review (only on the diff, `git diff`), against AGENTS.md rules and the modules
   whose `covers:` paths the diff touches. Look for what tools miss:
   misread intent, over-engineering / unrequested features, brute-force fixes, semantic duplication,
   redundant or tautological tests, boundary violations, missing observability per conventions.
3. Behaviour: does a test actually exercise the requested behaviour (would it fail without the change)?
4. Steering loop: if a finding is the kind a tool could catch, propose the sensor (lint rule,
   structural test, script) and its `hint.` instead of only fixing the instance.
5. Report: ✓/✗ per tier, findings fixed, findings needing a human (≤ 10 lines).
