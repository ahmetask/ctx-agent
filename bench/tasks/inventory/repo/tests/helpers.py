import contextlib
import io
import os
import tempfile
import unittest

from inventory.cli import main


class CliTestCase(unittest.TestCase):
    """Runs the CLI in-process against a throwaway database."""

    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.db = os.path.join(self._dir.name, "db.json")
        self._old = os.environ.get("INVENTORY_DB")
        os.environ["INVENTORY_DB"] = self.db

    def tearDown(self):
        if self._old is None:
            os.environ.pop("INVENTORY_DB", None)
        else:
            os.environ["INVENTORY_DB"] = self._old
        self._dir.cleanup()

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = main(list(argv))
        return code, out.getvalue(), err.getvalue()
