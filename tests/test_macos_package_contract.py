"""Catch package-audit markers left behind when native shell labels change."""
import re
import shlex
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class MacPackageContractTests(unittest.TestCase):
    def test_required_shell_markers_exist_in_current_native_sources(self):
        audit = (ROOT / "scripts/audit-macos-package.sh").read_text()
        contract = re.search(r"for shell_contract in (.*?); do", audit, re.DOTALL)
        self.assertIsNotNone(contract, "package audit must retain its shell contract")
        markers = shlex.split(contract.group(1).replace("\\\n", ""))
        self.assertTrue(markers)
        sources = sorted((ROOT / "apple/macos").glob("*.mm"))
        sources += sorted((ROOT / "apple/macos").glob("*.h"))
        sources.append(ROOT / "vendor/runtimes/macos/runtime/src/settings_overlay.cpp")
        native = "\n".join(source.read_text() for source in sources)
        for marker in markers:
            with self.subTest(marker=marker):
                self.assertIn(marker, native,
                              "package audit expects a marker absent from the current native shell")


if __name__ == "__main__":
    unittest.main()
