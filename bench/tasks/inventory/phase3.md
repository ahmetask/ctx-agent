Low-stock feature, part 3 of 3: the `restock` command.

- For every item that `alerts` would list, set qty to 2 × its reorder level and save. Print
  `restocked N item(s), U unit(s), cost $X` — U = units added in total, X = sum of units added ×
  unit price, formatted like the tool's other money output.
- `restock --dry-run` prints the same line but starting with `would restock`, and saves nothing.
- With nothing to restock: `restocked 0 item(s), 0 unit(s), cost $0.00`.
- Add tests. `make test` must pass.
