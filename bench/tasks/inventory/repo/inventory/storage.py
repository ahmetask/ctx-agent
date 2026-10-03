import json
import os
import tempfile

from .errors import DuplicateSku, InventoryError, UnknownSku
from .models import Item

FORMAT_VERSION = 1


def db_path():
    return os.environ.get("INVENTORY_DB", "inventory.json")


class Store:
    """In-memory view of the database file. Call save() to persist."""

    def __init__(self, path=None):
        self.path = path or db_path()
        self.items = {}

    @classmethod
    def load(cls, path=None):
        store = cls(path)
        if not os.path.exists(store.path):
            return store
        with open(store.path, encoding="utf-8") as fh:
            try:
                data = json.load(fh)
            except json.JSONDecodeError as exc:
                raise InventoryError(f"corrupt database {store.path}: {exc}") from exc
        version = data.get("version", 0)
        if version > FORMAT_VERSION:
            raise InventoryError(f"database version {version} is newer than this tool")
        for raw in data.get("items", []):
            item = Item.from_dict(raw)
            store.items[item.sku] = item
        return store

    def save(self):
        data = {
            "version": FORMAT_VERSION,
            "items": [self.items[sku].to_dict() for sku in sorted(self.items)],
        }
        directory = os.path.dirname(os.path.abspath(self.path))
        fd, tmp = tempfile.mkstemp(dir=directory, prefix=".inventory-", suffix=".json")
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, sort_keys=True)
            fh.write("\n")
        os.replace(tmp, self.path)

    def get(self, sku):
        try:
            return self.items[sku]
        except KeyError:
            raise UnknownSku(sku) from None

    def add(self, item):
        if item.sku in self.items:
            raise DuplicateSku(item.sku)
        self.items[item.sku] = item

    def remove(self, sku):
        self.get(sku)
        del self.items[sku]

    def sorted_items(self):
        return [self.items[sku] for sku in sorted(self.items)]
