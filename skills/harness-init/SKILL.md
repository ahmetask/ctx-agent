---
name: harness-init
description: Bootstrap a harness-engineered agent context in any repository (any language) — a lean AGENTS.md map, on-demand context modules, tiered sensors and a harness map. Use when a repo has no .harness/ directory or the user asks to set up agent context / AGENTS.md / harness engineering.
---

# harness-init

Goal: the smallest set of guides + sensors that lets an agent succeed first time here.

1. Scaffold (non-destructive):
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/init.sh"`
2. Verify sensors: run each `sensor.*` line in `.harness/config` once (or `CTX_VERBOSE=1 sensors.sh fast`).
   Remove/fix commands that don't exist; edit-tier commands must take < ~2s per file.
   If none detected, ask the human for the build/lint/test commands.
3. Learn the repo cheaply: README, manifests, top-level tree, CI config, 2–3 representative
   source files. Do not read the whole codebase.
4. Fill AGENTS.md (budget ~1200 tokens): purpose (1–2 lines), non-obvious layout,
   exact commands, load-bearing rules with *why*, escalation list, module index.
   Fill modules only with what you verified; leave a section empty rather than speculate.
   Set `<!-- covers: ... -->` in each module to the paths it describes.
5. Fill `.harness/harness.md`: control matrix (dir/type/category/timing), harnessability,
   top 3 gaps — especially the behaviour harness (spec, approved fixtures, tests).
6. Check: `budget.sh` and `drift.sh` clean. Clear the ledger: `ledger.sh clear`.
7. Report in ≤ 10 lines. Suggest one high-leverage next sensor (e.g. a structural/boundary test).

Existing CLAUDE.md / AGENTS.md / .cursorrules: merge durable facts into the new layout,
delete duplication, keep `CLAUDE.md` as `@AGENTS.md` (+ Claude-only notes, if any).
