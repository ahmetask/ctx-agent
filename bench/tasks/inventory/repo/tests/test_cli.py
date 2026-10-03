import os

from tests.helpers import CliTestCase


class CliTest(CliTestCase):
    def test_add_list_show(self):
        self.assertEqual(self.run_cli("add", "WID-1", "Widget", "10", "2.50")[0], 0)
        code, out, _ = self.run_cli("list")
        self.assertEqual(code, 0)
        self.assertIn("WID-1", out)
        self.assertTrue(out.splitlines()[0].startswith("SKU"))
        code, out, _ = self.run_cli("show", "WID-1")
        self.assertIn("value: $25.00", out)

    def test_adjust_never_negative(self):
        self.run_cli("add", "A", "Anchor", "1", "1")
        code, _, err = self.run_cli("adjust", "A", "-5")
        self.assertEqual(code, 2)
        self.assertIn("error:", err)

    def test_unknown_sku_exit_2(self):
        code, _, err = self.run_cli("show", "NOPE")
        self.assertEqual(code, 2)
        self.assertEqual(err.strip(), "error: unknown sku 'NOPE'")

    def test_value(self):
        self.run_cli("add", "A", "Anchor", "2", "1.50")
        self.run_cli("add", "B", "Bolt", "4", "0.25")
        self.assertEqual(self.run_cli("value")[1].strip(), "total value: $4.00 across 2 item(s)")

    def test_import(self):
        csv_path = os.path.join(os.path.dirname(self.db), "in.csv")
        with open(csv_path, "w") as fh:
            fh.write("sku,name,qty,price\nA,Anchor,3,1.00\nB,Bolt,1,0.10\n")
        self.assertEqual(self.run_cli("import", csv_path)[1].strip(), "imported 2 item(s)")
        self.assertEqual(self.run_cli("value")[1].strip(), "total value: $3.10 across 2 item(s)")
