import unittest

from inventory.errors import InvalidValue
from inventory.money import format_cents, parse_cents


class MoneyTest(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(parse_cents("2.5"), 250)
        self.assertEqual(parse_cents("2.05"), 205)
        self.assertEqual(parse_cents("3"), 300)
        self.assertEqual(parse_cents(".99"), 99)

    def test_parse_rejects(self):
        for bad in ("-1", "1.234", "abc", "1.x"):
            with self.assertRaises(InvalidValue):
                parse_cents(bad)

    def test_format(self):
        self.assertEqual(format_cents(250), "$2.50")
        self.assertEqual(format_cents(123456), "$1,234.56")
        self.assertEqual(format_cents(0), "$0.00")
