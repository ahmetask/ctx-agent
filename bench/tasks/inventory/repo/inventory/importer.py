import csv

from .errors import InvalidValue
from .models import Item
from .money import parse_cents

REQUIRED = ("sku", "name", "qty", "price")


def read_csv(path):
    """Parse a CSV with columns sku,name,qty,price into Items. Errors name the line."""
    items = []
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        missing = [c for c in REQUIRED if c not in (reader.fieldnames or [])]
        if missing:
            raise InvalidValue(f"{path}: missing columns: {', '.join(missing)}")
        for lineno, row in enumerate(reader, start=2):
            try:
                items.append(
                    Item(
                        sku=row["sku"].strip(),
                        name=row["name"].strip(),
                        qty=int(row["qty"]),
                        unit_price_cents=parse_cents(row["price"]),
                    )
                )
            except (ValueError, InvalidValue) as exc:
                raise InvalidValue(f"{path}:{lineno}: {exc}") from None
    return items
