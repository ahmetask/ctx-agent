# Data format

The database is one JSON object:

    {"version": 1, "items": [{"sku": "WID-1", "name": "Widget", "qty": 10, "unit_price_cents": 250}]}

- Prices are stored as integer cents; never floats.
- `items` is kept sorted by `sku` on save.
- Loading must accept every older version of the file. Missing optional fields get defaults
  in `inventory/models.py` (`Item.from_dict`), never in the CLI.
- Writes are atomic: write to a temp file in the same directory, then rename.
