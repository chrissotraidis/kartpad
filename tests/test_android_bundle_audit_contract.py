from __future__ import annotations

import unittest
import subprocess
import tempfile
import zipfile
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidBundleAuditContractTests(unittest.TestCase):
    def test_parser_markers_are_bound_to_members(self) -> None:
        audit = (REPO / "scripts/audit-android-bundle.sh").read_text()
        code = audit.split("<<'PY_AUDIT'\n", 1)[1].split("\nPY_AUDIT", 1)[0]
        markers = b"\n".join(b"-----" + edge + b" " + kind + b"PRIVATE KEY-----"
                              for edge in (b"BEGIN", b"END")
                              for kind in (b"", b"EC ", b"RSA ")) + b"\n"
        # The coreless disc-import library links no TLS code, so it carries no
        # parser literals (91802b34); markers there now fail the audit.
        base = {"base/lib/arm64-v8a/libmain.so": markers * 2,
                "base/lib/arm64-v8a/libkartpad_discio.so": b"coreless disc reader"}
        symbol = "BUNDLE-METADATA/com.android.tools.build.debugsymbols/arm64-v8a/libmain.so.sym"
        cases = [(base, True), ({**base, symbol: markers * 2}, True),
                 ({**base, "base/assets/unexpected.txt": markers}, False),
                 ({**base, "base/lib/arm64-v8a/libmain.so": markers * 3}, False),
                 ({**base, symbol: markers}, False),
                 ({**base, "base/lib/arm64-v8a/libkartpad_discio.so": markers}, False)]
        with tempfile.TemporaryDirectory() as temporary:
            for index, (entries, passes) in enumerate(cases):
                with self.subTest(index=index):
                    archive = Path(temporary) / f"case{index}.aab"
                    with zipfile.ZipFile(archive, "w") as output:
                        for name, data in entries.items():
                            output.writestr(name, data)
                    result = subprocess.run(["python3", "-", str(archive)], input=code,
                                            text=True, capture_output=True)
                    self.assertEqual(result.returncode == 0, passes, result.stderr)

    def test_unsigned_bundle_audit_is_fail_closed(self) -> None:
        audit = (REPO / "scripts/audit-android-bundle.sh").read_text()

        self.assertIn("bundletool-all-1.18.1.jar", audit)
        self.assertIn("675786493983787ffa", audit)
        self.assertIn("validate --bundle", audit)
        self.assertIn('package="dev.kartpad.android"', audit)
        self.assertIn("KARTPAD_ANDROID_EXPECTED_VERSION_NAME", audit)
        # The expected version defaults to the single version.json (15bebd18).
        self.assertIn('"${repo_root}/version.json" version', audit)
        self.assertIn("${KARTPAD_ANDROID_EXPECTED_VERSION_NAME:-${release_version}}", audit)
        self.assertIn("KARTPAD_ANDROID_EXPECTED_VERSION_CODE", audit)
        self.assertIn("release AAB is debuggable", audit)
        self.assertIn("AAB is signed", audit)
        self.assertIn("base/lib/arm64-v8a/libmain.so", audit)
        self.assertIn("LOAD", audit)
        self.assertIn("GNU_RELRO", audit)
        self.assertIn("PRIVATE KEY", audit)
        self.assertIn("/Users/", audit)


if __name__ == "__main__":
    unittest.main()
