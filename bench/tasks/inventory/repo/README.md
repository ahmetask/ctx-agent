# inventory

Small stock-keeping CLI for a single warehouse. Pure Python 3 standard library.

    python3 -m inventory add WID-1 "Widget" 10 2.50
    python3 -m inventory list
    python3 -m inventory value

The database is a JSON file: `$INVENTORY_DB`, or `inventory.json` in the working directory.

Run the tests with `make test`.
