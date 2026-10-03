Low-stock feature, part 2 of 3: the `alerts` command.

- Lists the items whose reorder level is above 0 and whose qty is at or below their reorder level.
- Columns: SKU, NAME, QTY, REORDER, SHORT — where SHORT = reorder level − qty. Sorted by SHORT
  descending, then SKU. Same table style as `list`.
- When no item qualifies, prints `no alerts`.
- Add tests. `make test` must pass.
