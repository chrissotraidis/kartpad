from pathlib import Path
import ast
import unittest

REPO = Path(__file__).resolve().parents[1]


class AndroidPublicReleaseTests(unittest.TestCase):
    def test_derivation_is_guarded_and_never_installs(self):
        source = (REPO / "scripts/derive-android-release-apk.sh").read_text()
        for required in ("audit-android-bundle.sh", "audit-android-package.sh",
                         "CN=Android Debug", "androiddebugkey", "apksigner",
                         "KARTPAD_ANDROID_EXPECTED_VERSION_CODE", "KARTPAD_ANDROID_REQUIRE_RELEASE",
                         '--ks-pass="file:', '--key-pass="file:', '--mode=universal'):
            self.assertIn(required, source)
        for forbidden in ("adb ", "gh release", "-genkeypair", "pass:android"):
            self.assertNotIn(forbidden, source)

    def test_public_notices_have_provenance_and_exact_signer(self):
        source = (REPO / "scripts/package-android-release-notices.py").read_text()
        for required in ("sourceCommit", "apkSHA256", "nativeLibraries", "noticesSHA256",
                         "containsTranslatedGameCode", "upstreamRightsConfirmed",
                         "certificate_sha256", "CN=Android Debug", '"--porcelain"',
                         "APPROVED_NATIVE",
                         "GPL-3.0.txt", "Dawn-BSD.txt", "SDL3-Zlib.txt", "package.testzip()"):
            self.assertIn(required, source)
        assignments = {
            target.id: node.value
            for node in ast.parse(source).body if isinstance(node, ast.Assign)
            for target in node.targets if isinstance(target, ast.Name)
        }
        native = ast.literal_eval(assignments["APPROVED_NATIVE"])
        self.assertEqual(set(native), {
            "lib/arm64-v8a/libmain.so", "lib/arm64-v8a/libkartpad_discio.so",
            "lib/arm64-v8a/libSDL3.so", "lib/arm64-v8a/libc++_shared.so",
        })
        self.assertEqual(native["lib/arm64-v8a/libmain.so"],
                         "8180940e3cf4188a7132e55263785d9843f97b00145df54917a4990b0631d9de")
        for digest in native.values():
            self.assertRegex(digest, r"^[0-9a-f]{64}$")
        self.assertIn("native != APPROVED_NATIVE", source)

    def test_source_manifest_rejects_wrong_candidate(self):
        import importlib.util
        import copy
        spec = importlib.util.spec_from_file_location("notices", REPO / "scripts/package-android-release-notices.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        name = "KartPad-v0.5.1-arm64.apk"
        good = {"schemaVersion": 2, "sourceRevision": module.APPROVED_SOURCE,
                "candidateArtifacts": {name: {"bytes": 169109067, "sha256": module.APPROVED_APK}}}
        self.assertTrue(module.source_matches_candidate(good, name, 169109067))
        for field, value in (("schemaVersion", 1), ("sourceRevision", "wrong"), ("candidateArtifacts", {})):
            bad = copy.deepcopy(good); bad[field] = value
            self.assertFalse(module.source_matches_candidate(bad, name, 169109067))
        self.assertFalse(module.source_matches_candidate(good, name, 1))
        bad = copy.deepcopy(good); bad["candidateArtifacts"][name]["sha256"] = "0" * 64
        self.assertFalse(module.source_matches_candidate(bad, name, 169109067))

    def test_update_guide_preserves_private_previews(self):
        guide = (REPO / "docs/INSTALL_ANDROID.md").read_text()
        for required in ("Do not uninstall", "does not back up Retro", "different local",
                         "60 FPS", "APK", "SHA256SUMS"):
            self.assertIn(required, guide)


if __name__ == "__main__":
    unittest.main()
