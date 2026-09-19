"""Behavioral safety cases for the read-only phone handoff check."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("preflight", Path(__file__).with_name("phone-preflight.py"))
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


class PreflightTests(unittest.TestCase):
    def info(self, code=123, certificate="a" * 64, sha="b" * 64):
        return dict(package=preflight.PACKAGE, version_code=code,
                    certificate_sha256=certificate, sha256=sha, minimum_api=28)

    def test_forward_update_and_identical_artifact(self):
        current = self.info(122, sha="c" * 64)
        self.assertEqual(preflight.compare(self.info(), current), "forward_update_identity_matches")
        self.assertEqual(preflight.compare(self.info(), self.info()), "same_artifact")

    def test_mismatch_downgrade_equal_version_are_rejected(self):
        for installed in (self.info(certificate="d" * 64), self.info(124, sha="c" * 64),
                          self.info(123, sha="c" * 64), dict(self.info(), package="another.app")):
            with self.subTest(installed=installed), self.assertRaises(ValueError):
                preflight.compare(self.info(), installed)

    def test_missing_ambiguous_and_unauthorized_devices_rejected(self):
        for rows in ("", "secret offline\n", "secret unauthorized\n", "one device\ntwo device\n",
                     "one device\ntwo unauthorized\n"):
            with self.subTest(rows=rows), patch.object(preflight, "run", return_value="List of devices attached\n"+rows):
                with self.assertRaises(ValueError) as error:
                    preflight.device_target(Path("adb"))
                self.assertNotIn("secret", str(error.exception))

    def test_apk_signature_and_metadata_are_parsed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp)/"test.apk"
            path.write_bytes(b"APK fixture")
            badging = "package: name='dev.kartpad.android' versionCode='123' versionName='prototype'\nminSdkVersion:'28'\nnative-code: 'arm64-v8a'\n"
            cert = "Signer #1 certificate SHA-256 digest: " + "a"*64
            with patch.object(preflight, "run", side_effect=[badging, cert]):
                parsed = preflight.apk_info(path, Path(tmp))
            self.assertTrue(parsed["arm64_only"])
            self.assertFalse(parsed["debuggable"])
            self.assertEqual(parsed["certificate_sha256"], "a"*64)
            for signature in ("", cert+"\n"+cert.replace("#1", "#2")):
                with patch.object(preflight, "run", side_effect=[badging, signature]), self.assertRaises(ValueError):
                    preflight.apk_info(path, Path(tmp))

    def test_connected_inspection_uses_only_read_commands(self):
        calls = []
        def fake_run(*args):
            args = tuple(map(str, args))
            calls.append(args)
            if args[-1] == "devices": return "List of devices attached\nprivate-serial device\n"
            if "getprop" in args:
                return {"ro.kernel.qemu":"0", "ro.build.version.sdk":"36", "ro.product.cpu.abi":"arm64-v8a"}[args[-1]]
            if "list" in args: return "package:dev.kartpad.android"
            if "path" in args: return "package:/data/app/opaque/base.apk\npackage:/data/app/opaque/split_config.apk"
            if "pull" in args: return ""
            raise AssertionError(args)
        with patch.object(preflight, "run", side_effect=fake_run), patch.object(preflight, "apk_info", return_value=self.info(122, sha="c"*64)):
            status, _ = preflight.connected_check(self.info(), Path("sdk"), Path("tools"))
        self.assertEqual(status, "forward_update_identity_matches")
        for args in calls:
            self.assertFalse(set(args) & {"install", "uninstall", "clear", "start", "force-stop", "push"})

    def test_device_inspection_failure_does_not_become_fresh_install(self):
        with patch.object(preflight, "device_target", return_value="private"), patch.object(preflight, "run", side_effect=ValueError("Inspection failed")):
            with self.assertRaises(ValueError):
                preflight.connected_check(self.info(), Path("sdk"), Path("tools"))


if __name__ == "__main__":
    unittest.main()
