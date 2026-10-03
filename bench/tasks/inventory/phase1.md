Low-stock feature, part 1 of 3: reorder levels.

- Every item gets a reorder level: a non-negative integer, default 0. Persist it. Existing database
  files that don't have it must still load (level 0).
- New command `set-reorder SKU LEVEL`; on success prints `SKU reorder_level LEVEL`
  (e.g. `WID-1 reorder_level 5`). Unknown SKU or a non-integer/negative LEVEL is an error,
  handled like the other commands' errors.
- `show SKU` prints a `reorder_level: N` line directly after the `qty:` line.
- Add tests. `make test` must pass.
