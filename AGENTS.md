# ctx-agent — agent map

Claude Code plugin implementing harness engineering (see `RULES.md`). Bash only, no runtime deps.

## Layout
- `scripts/` — all logic; `lib.sh` is sourced by every script (config parsing, budgets, squeeze)
- `hooks/hooks.json` — wires `session-start.sh`, `read-guard.sh`, `post-edit.sh`, `stop-gate.sh`, `checkpoint.sh`
- `skills/*/SKILL.md`, `agents/*.md` — inferential guides; keep them short. `context-harness` maintains
  the harness; `harness-architect` → `harness-tester` → `harness-coder` → `harness-reviewer` is the change workflow
- `references/` — on-demand plugin docs read by skills/agent (e.g. `agent-prompts.md`, `exec-plans.md`)
- `templates/` — copied into target repos by `init.sh` (`{{...}}` placeholders)
- `bench/` — token A/B benchmark (`run.sh`, `report.sh`, `tasks/<name>/`); method in `bench/README.md`.
  `tests/fake-claude.sh` stands in for `claude -p` in tests

## Commands
- test: `bash tests/run.sh`
- validate plugin: `claude plugin validate .`

## Rules
- Target repos are arbitrary: no language assumptions outside `detect-stack.sh`.
- Never `source`/`eval` `.harness/config` — parse with `cfg_get`/`cfg_sensors` (it's repo content).
- Hooks must be fast and quiet on success; any new output costs tokens in every session.
- Every script behaviour change gets a case in `tests/run.sh`.
- A bench task's `check<N>.sh` must fail on the fixture and pass on `reference.patch` (tested).
