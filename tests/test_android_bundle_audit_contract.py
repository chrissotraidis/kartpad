from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidBundleAuditContractTests(unittest.TestCase):
    def test_unsigned_bundle_audit_is_fail_closed(self) -> None:
        audit = (REPO / "scripts/audit-android-bundle.sh").read_text()

        self.assertIn("bundletool-all-1.18.1.jar", audit)
        self.assertIn("675786493983787ffa", audit)
        self.assertIn("validate --bundle", audit)
        self.assertIn('package="dev.kartpad.android"', audit)
        self.assertIn("KARTPAD_ANDROID_EXPECTED_VERSION_NAME", audit)
        self.assertIn("0.4.0-android-preview.2", audit)
        self.assertIn("AAB is signed", audit)
        self.assertIn("base/lib/arm64-v8a/libmain.so", audit)
        self.assertIn("LOAD", audit)
        self.assertIn("GNU_RELRO", audit)
        self.assertIn("PRIVATE KEY", audit)
        self.assertIn("/Users/", audit)


if __name__ == "__main__":
    unittest.main()
