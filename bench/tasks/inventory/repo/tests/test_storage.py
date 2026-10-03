import json
import os
import tempfile
import unittest

from inventory.errors import DuplicateSku, InventoryError, UnknownSku
from inventory.models import Item
from inventory.storage import Store


class StorageTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.dir.name, "db.json")

    def tearDown(self):
        self.dir.cleanup()

    def test_roundtrip_sorted(self):
        s = Store(self.path)
        s.add(Item("B", "Bolt", 5, 10))
        s.add(Item("A", "Anchor", 1, 999))
        s.save()
        data = json.load(open(self.path))
        self.assertEqual([i["sku"] for i in data["items"]], ["A", "B"])
        self.assertEqual(Store.load(self.path).get("B").qty, 5)

    def test_missing_file_is_empty(self):
        self.assertEqual(Store.load(self.path).items, {})

    def test_duplicate_and_unknown(self):
        s = Store(self.path)
        s.add(Item("A", "Anchor", 1, 1))
        with self.assertRaises(DuplicateSku):
            s.add(Item("A", "Again", 1, 1))
        with self.assertRaises(UnknownSku):
            s.get("Z")

    def test_newer_version_rejected(self):
        with open(self.path, "w") as fh:
            json.dump({"version": 99, "items": []}, fh)
        with self.assertRaises(InventoryError):
            Store.load(self.path)
