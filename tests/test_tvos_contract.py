import json
import plistlib
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class TvOSContractTests(unittest.TestCase):
    @staticmethod
    def png_header(path: Path):
        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
            raise AssertionError(f"not a PNG: {path}")
        return struct.unpack(">IIBBBBB", data[16:29])

    def test_runtime_target_is_native_dual_mode(self):
        patch = (ROOT / "patches/wiicompiled-tvos-runtime.patch").read_text()
        self.assertIn('CMAKE_SYSTEM_NAME STREQUAL "tvOS"', patch)
        self.assertIn("mkw_configure_kartpad_tvos(KartPadDual KartPad)", patch)
        self.assertIn("TARGET_OS_IOS || TARGET_OS_TV", patch)
        self.assertIn("--- a/src/hle/input/kpad.cpp", patch)
        self.assertGreaterEqual(
            patch.count("TARGET_OS_IOS || TARGET_OS_TV"), 16
        )
        self.assertIn("MINIZIP::minizip", patch)
        self.assertIn("runtime/src/retro_rewind/archive_path.cpp", patch)
        self.assertIn("runtime/src/retro_rewind/archive_scan.cpp", patch)
        self.assertIn("KARTPAD_TVOS_BUNDLE_IDENTIFIER", patch)

    def test_tvos_host_keeps_rebuildable_and_durable_state_separate(self):
        host = (ROOT / "apple/tvos/KartPadTVRuntimeHost.mm").read_text()
        self.assertIn("NSApplicationSupportDirectory", host)
        self.assertIn("NSCachesDirectory", host)
        self.assertIn('@"GameData"', host)
        self.assertIn("KartPadRetroRewindInstaller.installedRootPath", host)
        self.assertIn("KartPadTVWriteRuntimePaths", host)

    def test_extended_gamepad_is_explicit_and_siri_remote_is_not_gameplay(self):
        with (ROOT / "apple/tvos/RuntimeInfo.plist").open("rb") as handle:
            info = plistlib.load(handle)
        self.assertTrue(info["GCSupportsControllerUserInteraction"])
        self.assertEqual(
            info["GCSupportedGameControllers"], [{"ProfileName": "ExtendedGamepad"}]
        )
        host = (ROOT / "apple/tvos/KartPadTVRuntimeHost.mm").read_text()
        self.assertIn("Siri Remote", host)
        self.assertIn("not a supported racing controller", host)

    def test_tvos_brand_assets_are_layered_and_original(self):
        assets = ROOT / "apple/tvos/Assets.xcassets/App Icon.brandassets"
        small = json.loads(
            (assets / "App Icon - Small.imagestack/Contents.json").read_text()
        )
        self.assertEqual(
            [layer["filename"] for layer in small["layers"]],
            [
                "Mark.imagestacklayer",
                "Circuit.imagestacklayer",
                "Background.imagestacklayer",
            ],
        )
        content = "App Icon - Small.imagestack/{}/Content.imageset/{}"
        background = assets / content.format("Background.imagestacklayer", "background@2x.png")
        circuit = assets / content.format("Circuit.imagestacklayer", "circuit@2x.png")
        mark = assets / content.format("Mark.imagestacklayer", "mark@2x.png")
        self.assertEqual(self.png_header(background)[:2], (800, 480))
        self.assertIn(self.png_header(background)[3], (0, 2, 3))
        self.assertNotIn(b"tRNS", background.read_bytes())
        self.assertEqual(self.png_header(circuit)[3], 6)
        self.assertEqual(self.png_header(mark)[3], 6)
        provenance = (ROOT / "branding/PROVENANCE.md").read_text()
        self.assertIn("tvOS layered icon", provenance)
        self.assertNotIn("opening.bnr", provenance.split("## tvOS layered icon", 1)[1])

    def test_retro_rewind_remains_pinned_and_hash_verified(self):
        profile = json.loads(
            (ROOT / "builder/profiles/mkwii-rmcp01-rev0.json").read_text()
        )
        self.assertEqual(profile["retroRewind"]["version"], "6.12.5")
        host = (ROOT / "apple/tvos/KartPadTVRuntimeHost.mm").read_text()
        self.assertIn("installArchiveAtURL", host)
        self.assertIn("officialArchiveURL", host)
        installer = (ROOT / "apple/ios/KartPadRetroRewindInstaller.mm").read_text()
        self.assertIn("KARTPAD_RR_ARCHIVE_SHA256", installer)
        self.assertIn("TARGET_OS_TV", installer)
        self.assertIn("NSCachesDirectory", installer)

    def test_download_is_staged_before_url_session_releases_its_temp_file(self):
        host = (ROOT / "apple/tvos/KartPadTVRuntimeHost.mm").read_text()
        download = host.split("- (void)downloadRetroRewind {", 1)[1].split(
            "- (void)selectRetroRewind:", 1
        )[0]
        self.assertLess(
            download.index("moveItemAtURL:location"),
            download.index("dispatch_async(dispatch_get_main_queue()"),
        )
        self.assertIn("installArchiveAtPath:stagedArchive", download)

    def test_build_and_audit_scripts_fail_closed(self):
        build = (ROOT / "scripts/build-tvos-game-app.sh").read_text()
        audit = (ROOT / "scripts/audit-tvos-app.sh").read_text()
        stage = (ROOT / "scripts/stage-tvos-game-data.sh").read_text()
        backup = (ROOT / "scripts/backup-tvos-state.sh").read_text()
        diagnostics = (ROOT / "scripts/collect-tvos-diagnostics.sh").read_text()
        self.assertIn("CODE_SIGNING_ALLOWED=NO", build)
        self.assertIn("KartPadDual", build)
        dawn = (ROOT / "scripts/build-dawn-tvos.sh").read_text()
        self.assertIn("-ffile-prefix-map=${repo_root}=KartPad", dawn)
        self.assertIn("TVOS", audit)
        self.assertIn("Assets.car", audit)
        self.assertIn("mark-large.png", audit)
        self.assertIn("expected_bundle_identifier", audit)
        self.assertIn("/Users/[^/]+/|/tmp/kartpad-tvos-", audit)
        self.assertIn("rksys.dat", audit)
        self.assertIn("appDataContainer", stage)
        self.assertIn("sys/apploader.img", stage)
        self.assertIn("5d1c9ea3", stage)
        self.assertIn("80d18895b39c63bd80f457398bfcbb91", stage)
        for script in (build, stage, backup, diagnostics):
            self.assertIn("KARTPAD_TVOS_BUNDLE_IDENTIFIER", script)
        self.assertIn("Application Support/KartPad/Logs", diagnostics)
        self.assertIn("Application Support/SunPad/Logs", diagnostics)
        self.assertIn("<app-container>", diagnostics)
        self.assertIn("<user-home>", diagnostics)
        self.assertNotIn("GameData", diagnostics)

    def test_stable_release_contracts_cover_ios_and_tvos(self):
        ios_package = (ROOT / "scripts/package-public-unsigned-ipa.py").read_text()
        ios_audit = (ROOT / "scripts/audit-public-unsigned-ipa.py").read_text()
        tvos_package = (
            ROOT / "scripts/package-public-unsigned-tvos-ipa.py"
        ).read_text()
        tvos_audit = (ROOT / "scripts/audit-public-unsigned-tvos-ipa.py").read_text()
        for script in (ios_package, ios_audit, tvos_package, tvos_audit):
            self.assertIn('RELEASE_TAG = "v0.4.0"', script)
            self.assertIn('APP_VERSION = "0.4.0"', script)
        self.assertIn('APP_BUILD = "15"', ios_package)
        self.assertIn('APP_BUILD = "15"', ios_audit)
        self.assertIn('APP_BUILD = "3"', tvos_package)
        self.assertIn('APP_BUILD = "3"', tvos_audit)
        self.assertIn('"physicalAppleTVAcceptance": False', tvos_package)
        self.assertIn('"physicalAppleTVAcceptance": False', tvos_audit)
        self.assertTrue((ROOT / "docs/INSTALL_TVOS.md").is_file())
        self.assertTrue((ROOT / "docs/releases/v0.4.0.md").is_file())


if __name__ == "__main__":
    unittest.main()
