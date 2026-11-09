"""The release gate blocks release pull requests without go-or-no-go answers."""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("gate", ROOT / "scripts/check-release-gate.py")
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
VERSION = __import__("json").loads((ROOT / "version.json").read_text())["version"]


class ReleaseGate(unittest.TestCase):
    def test_missing_answers_block(self):
        self.assertTrue(gate.problems("Fixes things.", VERSION))
        partial = "Go or no-go\n1. Yes, prerelease first.\n2. No setting changes.\n"
        self.assertEqual(len(gate.problems(partial, VERSION)), 2)

    def test_complete_answers_pass(self):
        body = ("**Go or no-go answers**\n\n1. Hardware we couldn't test: yes, prerelease.\n"
                "2. Settings that start doing something: no.\n3. New ways to fail: no, adds fallbacks.\n"
                "4. Results table: filled in on the release.\n")
        self.assertEqual(gate.problems(body, VERSION), [])

    def test_missing_notes_block(self):
        body = "Go or no-go\n" + "".join(f"{n}. A real answer here.\n" for n in range(1, 5))
        self.assertTrue(gate.problems(body, "99.99.99"))


if __name__ == "__main__":
    unittest.main()
