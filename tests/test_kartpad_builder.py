from __future__ import annotations

import hashlib
import json
import plistlib
import stat
import tempfile
import unittest
import zipfile
from pathlib import Path

from kartpad_builder.packaging import PackageError, audit_app, package_unsigned_ipa
from kartpad_builder.android_release_contract import render_android_release_contract
from kartpad_builder.pipeline import cache_key, dependency_cache_key
from kartpad_builder.profiles import Profile, ProfileError, load_profiles, select_profile, validate_profile
from kartpad_builder.release_header import render_retro_rewind_header
from kartpad_builder.retro_rewind import (
    extract_archive,
    validate_pack,
    validate_rwfc_payload,
)


REPO = Path(__file__).resolve().parents[1]
PROFILES = REPO / "builder/profiles"


class ProfileTests(unittest.TestCase):
    def test_public_profiles_are_valid_and_unique(self) -> None:
        profiles = load_profiles(PROFILES)
        self.assertEqual([profile.id for profile in profiles], ["mkwii-rmcp01-rev0"])

    def test_profile_can_accept_multiple_container_variants(self) -> None:
        data = json.loads((PROFILES / "mkwii-rmcp01-rev0.json").read_text())
        second_hash = "1" * 64
        data["containers"]["acceptedImages"].append(
            {"format": "iso", "sha256": second_hash, "note": "test variant"}
        )
        validate_profile(data)
        profile = Profile(Path("test.json"), data)
        self.assertIs(select_profile([profile], second_hash), profile)

    def test_duplicate_container_hash_fails_closed(self) -> None:
        data = json.loads((PROFILES / "mkwii-rmcp01-rev0.json").read_text())
        data["containers"]["acceptedImages"].append(dict(data["containers"]["acceptedImages"][0]))
        with self.assertRaisesRegex(ProfileError, "duplicate"):
            validate_profile(data)

    def test_unknown_image_fails_closed(self) -> None:
        with self.assertRaisesRegex(ProfileError, "no supported profile"):
            select_profile(load_profiles(PROFILES), "0" * 64)

    def test_cache_key_changes_for_each_input(self) -> None:
        profile = load_profiles(PROFILES)[0]
        baseline = cache_key(profile, "a" * 64, "b" * 64)
        self.assertNotEqual(baseline, cache_key(profile, "c" * 64, "b" * 64))
        self.assertNotEqual(baseline, cache_key(profile, "a" * 64, "d" * 64))
        changed = json.loads(json.dumps(profile.data))
        changed["displayName"] += " changed"
        self.assertNotEqual(baseline, cache_key(Profile(Path("changed"), changed), "a" * 64, "b" * 64))

    def test_dependency_cache_key_changes_with_build_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "first").write_bytes(b"one")
            (root / "second").write_bytes(b"two")
            baseline = dependency_cache_key(root, ("first", "second"))
            (root / "second").write_bytes(b"changed")
            self.assertNotEqual(baseline, dependency_cache_key(root, ("first", "second")))

    def test_dual_mode_upstream_contract_is_explicit(self) -> None:
        profile = load_profiles(PROFILES)[0]
        dependencies = {
            dependency["name"]
            for dependency in json.loads((REPO / "dependencies.lock.json").read_text())["dependencies"]
        }
        self.assertTrue(set(profile.data["sourceDependencies"]).issubset(dependencies))
        self.assertIn("WiiCompiled", profile.data["sourceDependencies"])
        self.assertIn("Retro Rewind Pulsar", profile.data["sourceDependencies"])
        self.assertIn("Retro Rewind WFC patcher", profile.data["sourceDependencies"])

    def test_release_header_is_generated_from_the_retro_rewind_pin(self) -> None:
        profile = load_profiles(PROFILES)[0]
        retro = profile.data["retroRewind"]
        header = render_retro_rewind_header(profile.data)
        self.assertIn(f'#define KARTPAD_RR_VERSION "{retro["version"]}"', header)
        self.assertIn(
            f'#define KARTPAD_RR_VERSION_MANIFEST_URL "{retro["versionManifestUrl"]}"',
            header,
        )
        self.assertIn(f'#define KARTPAD_RR_ARCHIVE_URL "{retro["archive"]["url"]}"', header)
        self.assertIn(retro["archive"]["sha256"], header)
        self.assertIn(retro["codePul"]["sha256"], header)
        self.assertIn(retro["riivolutionXml"]["sha256"], header)
        self.assertIn(
            f'/zip/{retro["version"]}-',
            retro["archive"]["url"],
            "the visible version and immutable archive URL must advance together",
        )

    def test_android_release_contract_matches_profile(self) -> None:
        profile = load_profiles(PROFILES)[0]
        expected = render_android_release_contract(profile.data)
        generated = (
            REPO
            / "android/app/src/main/java/dev/kartpad/android/RetroRewindRelease.java"
        ).read_text()
        self.assertEqual(generated, expected)

    def test_device_archive_hashing_uses_heap_storage(self) -> None:
        source = (REPO / "apple/ios/KartPadRetroRewindInstaller.mm").read_text()
        self.assertNotIn("uint8_t buffer[1024 * 1024]", source)
        self.assertIn(
            "NSMutableData *bufferStorage = [NSMutableData dataWithLength:1024 * 1024]",
            source,
        )

    def test_retro_rewind_archive_path_policy_is_shared(self) -> None:
        installer = (REPO / "apple/ios/KartPadRetroRewindInstaller.mm").read_text()
        ios_patch = (REPO / "patches/wiicompiled-ios-discio-import.patch").read_text()
        tvos_patch = (REPO / "patches/wiicompiled-tvos-runtime.patch").read_text()
        shared_sources = (
            "runtime/src/retro_rewind/archive_path.cpp",
            "runtime/src/retro_rewind/archive_scan.cpp",
        )
        self.assertIn('"kartpad/retro_rewind/archive_path.h"', installer)
        self.assertIn('"kartpad/retro_rewind/archive_scan.h"', installer)
        self.assertIn("ValidateArchiveMemberPath", installer)
        self.assertIn("ArchiveScan", installer)
        for shared_source in shared_sources:
            self.assertIn(shared_source, ios_patch)
            self.assertIn(shared_source, tvos_patch)

    def test_dual_mode_chooser_keeps_a_width_on_wide_ipads(self) -> None:
        source = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        self.assertIn("self.contentWidthConstraint.constant", source)
        self.assertIn("CGRectGetWidth(self.view.bounds)", source)
        self.assertNotIn("multiplier:0.72", source)

    def test_multiplayer_guidance_keeps_a_visible_back_button_on_ipad(self) -> None:
        source = (REPO / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        method = source[source.index("- (void)showMultiplayerAccess") :]
        method = method[: method.index("- (void)uninstall")]
        self.assertIn("preferredStyle:UIAlertControllerStyleAlert", method)
        self.assertIn('actionWithTitle:@"Back"', method)
        self.assertNotIn("popoverPresentationController", method)


class RetroRewindTests(unittest.TestCase):
    def test_translator_accepts_current_kamek_v2_and_legacy_v3(self) -> None:
        patch = (REPO / "patches/wiicompiled-kamek-v2.patch").read_text()
        prepare = (REPO / "scripts/prepare-patched-translator.sh").read_text()
        self.assertIn("MagicV2 = 0x6B000002", patch)
        self.assertIn("MagicV3 = 0x6B000003", patch)
        self.assertIn("MagicV2 or MagicV3", patch)
        self.assertIn("magic1 == MagicV2 && encodedChunkSize == 0", patch)
        self.assertIn("wiicompiled-kamek-v2.patch", prepare)

    def make_archive(self, root: Path, unsafe: bool = False) -> tuple[Path, dict]:
        archive = root / "retro.zip"
        code = b"code-pul-fixture"
        xml = b"<riivolution/>\n"
        with zipfile.ZipFile(archive, "w") as bundle:
            bundle.writestr("RetroRewind6/version.txt", "6.12.4\n")
            bundle.writestr("RetroRewind6/Binaries/Code.pul", code)
            bundle.writestr("RetroRewind6/xml/RetroRewind6.xml", xml)
            bundle.writestr("apps/RetroRewind/boot.dol", b"not required by KartPad")
            bundle.writestr("RetroRewind.wad", b"not required by KartPad")
            if unsafe:
                bundle.writestr("../escape", b"unsafe")
        config = {
            "version": "6.12.4",
            "root": "RetroRewind6",
            "archive": {
                "url": "https://example.invalid/retro.zip",
                "bytes": archive.stat().st_size,
                "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
                "maximumExpandedBytes": 1024 * 1024,
            },
            "codePul": {
                "path": "Binaries/Code.pul",
                "bytes": len(code),
                "sha256": hashlib.sha256(code).hexdigest(),
            },
            "riivolutionXml": {
                "path": "xml/RetroRewind6.xml",
                "bytes": len(xml),
                "sha256": hashlib.sha256(xml).hexdigest(),
            },
            "payload": {
                "url": "http://example.invalid/payload",
                "bytes": 1,
                "sha256": "0" * 64,
            },
        }
        return archive, config

    def test_extracts_only_version_locked_retro_rewind_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive, config = self.make_archive(root)
            destination = root / "RetroRewind6"
            extract_archive(archive, destination, config)
            validate_pack(destination, config)
            self.assertFalse((root / "apps").exists())
            self.assertFalse((root / "RetroRewind.wad").exists())

    def test_archive_traversal_is_rejected_before_extraction(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive, config = self.make_archive(root, unsafe=True)
            with self.assertRaisesRegex(Exception, "unsafe path"):
                extract_archive(archive, root / "RetroRewind6", config)
            self.assertFalse((root.parent / "escape").exists())

    def test_current_production_payload_signature_and_tamper_detection(self) -> None:
        payload = REPO / "private/builder/retro-rewind-downloads/payload.RMCPD00.bin"
        if not payload.is_file():
            self.skipTest("private production payload is not cached")
        config = load_profiles(PROFILES)[0].data["retroRewind"]["payload"]
        validate_rwfc_payload(payload, config)
        with tempfile.TemporaryDirectory() as temp:
            tampered = Path(temp) / "payload.bin"
            image = bytearray(payload.read_bytes())
            image[-1] ^= 1
            tampered.write_bytes(image)
            changed = dict(config)
            changed["sha256"] = hashlib.sha256(image).hexdigest()
            with self.assertRaisesRegex(Exception, "signature"):
                validate_rwfc_payload(tampered, changed)


class PackagingTests(unittest.TestCase):
    def make_app(self, root: Path) -> Path:
        app = root / "KartPad.app"
        app.mkdir()
        plist = {
            "CFBundleIdentifier": "dev.kartpad.app",
            "CFBundleExecutable": "KartPad",
        }
        with (app / "Info.plist").open("wb") as handle:
            plistlib.dump(plist, handle)
        binary = app / "KartPad"
        binary.write_bytes(b"test arm64 executable")
        binary.chmod(0o755)
        (app / "asset.bin").write_bytes(b"asset")
        return app

    def test_deterministic_unsigned_ipa(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            app = self.make_app(root)
            first = root / "first.ipa"
            second = root / "second.ipa"
            provenance = {"schemaVersion": 1, "profileId": "test"}
            first_hash = package_unsigned_ipa(app, first, provenance)
            second_hash = package_unsigned_ipa(app, second, provenance)
            self.assertEqual(first_hash, second_hash)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as archive:
                mode = archive.getinfo("Payload/KartPad.app/KartPad").external_attr >> 16
                self.assertTrue(mode & stat.S_IXUSR)

    def test_additional_public_release_entries_are_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            app = self.make_app(root)
            notice = root / "RIGHTS_AND_LICENSES.md"
            notice.write_text("community preview\n")
            first = root / "first.ipa"
            second = root / "second.ipa"
            provenance = {"schemaVersion": 1, "releaseTag": "v0.2.0-preview.2"}
            entries = {"RIGHTS_AND_LICENSES.md": notice}
            first_hash = package_unsigned_ipa(app, first, provenance, entries)
            second_hash = package_unsigned_ipa(app, second, provenance, entries)
            self.assertEqual(first_hash, second_hash)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as archive:
                self.assertEqual(archive.read("RIGHTS_AND_LICENSES.md"), b"community preview\n")

    def test_unsafe_additional_entry_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            app = self.make_app(root)
            notice = root / "notice"
            notice.write_text("test\n")
            with self.assertRaisesRegex(PackageError, "invalid additional"):
                package_unsigned_ipa(
                    app,
                    root / "bad.ipa",
                    {"schemaVersion": 1},
                    {"../notice": notice},
                )

    def test_forbidden_game_image_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            app = self.make_app(Path(temp))
            (app / "game.wbfs").write_bytes(b"private")
            with self.assertRaisesRegex(PackageError, "forbidden"):
                audit_app(app)

    def test_private_build_path_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            app = self.make_app(Path(temp))
            (app / "KartPad").write_bytes(b"prefix /Users/private/build suffix")
            with self.assertRaisesRegex(PackageError, "private build path"):
                audit_app(app, ("/Users/private",))


if __name__ == "__main__":
    unittest.main()
