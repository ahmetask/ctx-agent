# Task: inventory low-stock feature (3 phases)

Fixture: `repo/` — a stdlib-only Python CLI (~600 lines, 12 tests, `make test`).
Each phase is a separate headless session; phases 2–3 depend on what phase 1 built, so an agent
without memory has to re-discover the code, the conventions (table style, error handling, money
formatting, data-format rules in `docs/`) and what was done before.

| phase | prompt | hidden check |
|---|---|---|
| 1 | `phase1.md` — persisted reorder level + `set-reorder` + `show` line, backward-compatible load | `check1.sh` |
| 2 | `phase2.md` — `alerts` table in the house style | `check2.sh` |
| 3 | `phase3.md` — `restock` with `--dry-run`, money formatting | `check3.sh` (also re-runs 1–2) |

`reference.patch` is a known-good solution; `tests/run.sh` uses it to prove the checks pass.
