# ctx-agent — agent map

Claude Code plugin implementing harness engineering (see `RULES.md`). Bash only, no runtime deps.

## Layout
- `scripts/` — all logic; `lib.sh` is sourced by every script (config parsing, budgets, squeeze)
- `hooks/hooks.json` — wires `session-start.sh`, `post-edit.sh`, `stop-gate.sh`
- `skills/*/SKILL.md`, `agents/context-harness.md` — inferential guides; keep them short
- `templates/` — copied into target repos by `init.sh` (`{{...}}` placeholders)

## Commands
- test: `bash tests/run.sh`
- validate plugin: `claude plugin validate .`

## Rules
- Target repos are arbitrary: no language assumptions outside `detect-stack.sh`.
- Never `source`/`eval` `.harness/config` — parse with `cfg_get`/`cfg_sensors` (it's repo content).
- Hooks must be fast and quiet on success; any new output costs tokens in every session.
- Every script behaviour change gets a case in `tests/run.sh`.
