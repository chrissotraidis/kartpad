from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
HOST = REPO / "apple/tvos/KartPadTVRuntimeHost.mm"
PATCH = REPO / "patches/wiicompiled-tvos-runtime.patch"
RUNTIME_REF = REPO / "ref/upstream/Wiicompiled/runtime"
PREPARE = REPO / "scripts/prepare-ios-game-runtime.sh"
STAGE = REPO / "scripts/stage-tvos-game-data.sh"
AUDIT = REPO / "scripts/audit-tvos-app.sh"
SAVE_COMPLETION = REPO / "scripts/inject-tvos-offline-save-completion.py"


class TVOSRuntimeContractTests(unittest.TestCase):
    def test_host_validates_private_game_data_without_embedding_it(self) -> None:
        source = HOST.read_text()
        self.assertIn("NSCachesDirectory", source)
        self.assertIn("GameData", source)
        self.assertIn("sys/main.dol", source)
        self.assertIn("files/rel/StaticR.rel", source)
        self.assertIn(
            "80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05",
            source,
        )
        self.assertIn(
            "16d9d146112541fefea701ecb5bc1a496f9d50e4a752fbb5b6778e7c6399f67d",
            source,
        )
        self.assertIn('"enabled = false', source)
        self.assertIn('URLByAppendingPathComponent:@"NAND"', source)
        self.assertNotIn("EnsureBlankSave", source)
        self.assertNotIn("rksys.dat", source)
        self.assertNotIn("MarioKart.iso", source)
        self.assertNotIn("private/self-build", source)

    def test_host_reuses_extended_controller_adapter(self) -> None:
        source = HOST.read_text()
        self.assertIn("KartPadPhysicalControllers", source)
        self.assertIn("AdaptSunPadInput", source)
        self.assertIn('return "base"', source)
        for excluded in ("DiscIO", "RetroRewind", "MotionSteering", "GameOverlay"):
            self.assertNotIn(excluded, source)

    def test_patch_applies_after_current_apple_stack(self) -> None:
        self.assertTrue(PATCH.is_file())
        with tempfile.TemporaryDirectory() as temporary:
            runtime = Path(temporary) / "runtime"
            subprocess.run(["cp", "-R", RUNTIME_REF, runtime], check=True)
            for patch in (
                "wiicompiled-apple-runtime.patch",
                "wiicompiled-apple-network-tls.patch",
                "wiicompiled-local-wfc-test-route.patch",
                "wiicompiled-blocking-stream-recv-wait.patch",
                "wiicompiled-mii-seed.patch",
                "wiicompiled-ios-arm64-fibers.patch",
                "wiicompiled-present-telemetry.patch",
                "wiicompiled-ios-app-integration.patch",
                "wiicompiled-ios-first-launch-gate.patch",
                "wiicompiled-ios-touch-core-buttons.patch",
                "wiicompiled-ios-settings-bridge.patch",
                "wiicompiled-ios-physical-controllers.patch",
                "wiicompiled-ios-motion-steering.patch",
                "wiicompiled-ios-discio-import.patch",
                "wiicompiled-retro-apple-product.patch",
                "wiicompiled-dual-profile-registry.patch",
                "wiicompiled-dual-profile-mod-loader.patch",
                "wiicompiled-dual-product-selection.patch",
                "wiicompiled-dual-product-target.patch",
                "wiicompiled-tvos-runtime.patch",
            ):
                subprocess.run(
                    ["patch", "--batch", "-s", "-p1", "-d", runtime],
                    input=(REPO / "patches" / patch).read_bytes(),
                    check=True,
                )

    def test_patch_defines_a_base_only_tvos_bundle(self) -> None:
        source = PATCH.read_text()
        self.assertIn('CMAKE_SYSTEM_NAME STREQUAL "tvOS"', source)
        self.assertIn("KartPadTVRuntimeHost.mm", source)
        self.assertIn("RuntimeInfo.plist", source)
        self.assertIn("apple/ios/PrivacyInfo.xcprivacy", source)
        self.assertIn("OUTPUT_NAME KartPadTV", source)
        self.assertIn("TARGET_OS_TV", source)
        self.assertIn('NOT CMAKE_SYSTEM_NAME STREQUAL "tvOS"', source)
        for excluded in (
            "KartPadDiscExtractor",
            "KartPadMotionSteering",
            "target_sources(RetroRewind",
        ):
            self.assertNotIn(excluded, source)

    def test_build_stage_and_audit_use_the_runtime_contract(self) -> None:
        prepare = PREPARE.read_text()
        stage = STAGE.read_text()
        audit = AUDIT.read_text()
        self.assertIn("appletvsimulator", prepare)
        self.assertIn("appletvos", prepare)
        self.assertIn("DEVELOPMENT_TEAM", prepare)
        self.assertIn("Release-appletvos/KartPadTV.app/KartPadTV", prepare)
        self.assertIn("aurora-tvos-package-discovery.patch", prepare)
        self.assertIn("wiicompiled-tvos-runtime.patch", prepare)
        self.assertIn("inject-tvos-offline-save-completion.py", prepare)
        self.assertIn("TVOSSIMULATOR", prepare)
        rejected = subprocess.run(
            [
                PREPARE,
                "missing-translation",
                "/tmp/kartpad-rejected-source",
                "/tmp/kartpad-rejected-build",
                "dual",
                "appletvsimulator",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(rejected.returncode, 64)
        self.assertIn("tvOS supports only product=base", rejected.stderr)
        self.assertIn("simctl get_app_container", stage)
        self.assertIn("Library/Caches/KartPad/GameData", stage)
        self.assertIn("KartPadMobileEnsureGameDataAvailable", audit)
        self.assertNotIn("first-launch", audit)
        self.assertIn("DEVELOPMENT_TEAM", audit)
        self.assertNotIn("HFHZAHV482", audit)
        for forbidden in (
            "GameData",
            "NAND",
            "main.dol",
            "StaticR.rel",
            "rksys.dat",
            "Config.toml",
        ):
            self.assertIn(f"'{forbidden}'", audit)
        for script in (PREPARE, STAGE, AUDIT):
            subprocess.run(["bash", "-n", script], check=True)

    def test_tvos_save_completion_injection_is_exact_and_idempotent(self) -> None:
        source = SAVE_COMPLETION.read_text()
        namespace: dict[str, object] = {"__name__": "tvos_save_completion_test"}
        exec(compile(source, SAVE_COMPLETION, "exec"), namespace)
        inject = namespace["inject"]

        fixture = """extern "C" void func_80672CC8(CpuContext* MKW_RESTRICT ctx)
{
[[maybe_unused]] loc_80672D14:
{
    if (((cr & 0x20000000u) == 0)) {
        goto loc_80672D24;
    }
}
[[maybe_unused]] loc_80672D18:
}
"""
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "func_80672CC8.cpp"
            path.write_text(fixture)
            self.assertTrue(inject(path))
            injected = path.read_text()
            self.assertEqual(injected.count("tvOS has no WiiConnect24 service"), 1)
            self.assertIn("__ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__", injected)
            self.assertIn("if (r3 == 1)", injected)
            self.assertFalse(inject(path))
            self.assertEqual(path.read_text(), injected)


if __name__ == "__main__":
    unittest.main()
