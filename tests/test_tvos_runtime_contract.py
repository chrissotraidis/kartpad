from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
HOST = REPO / "apple/tvos/KartPadTVRuntimeHost.mm"
PATCH = REPO / "patches/wiicompiled-tvos-runtime.patch"
RELEASE_PROFILE = REPO / "builder/profiles/mkwii-rmcp01-rev0.json"
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

    def test_host_selects_exact_runtime_profiles_and_pinned_retro_payload(self) -> None:
        source = HOST.read_text()
        self.assertIn('URLByAppendingPathComponent:@"RuntimeProfile"', source)
        self.assertIn(
            '[@"base\\n" dataUsingEncoding:NSUTF8StringEncoding]', source
        )
        self.assertIn(
            '[@"retro_rewind\\n" dataUsingEncoding:NSUTF8StringEncoding]', source
        )
        self.assertNotIn("stringByTrimmingCharactersInSet", source)
        self.assertIn("return @\"base\";", source)
        self.assertIn("return nil;", source)
        self.assertIn(
            'const bool retroProfile = [selectedProfile '
            'isEqualToString:@"retro_rewind"];',
            source,
        )
        self.assertIn('#include "kartpad_retro_rewind_release.h"', source)
        for constant in (
            "KARTPAD_RR_ROOT",
            "KARTPAD_RR_VERSION",
            "KARTPAD_RR_CODE_PUL_PATH",
            "KARTPAD_RR_CODE_PUL_BYTES",
            "KARTPAD_RR_CODE_PUL_SHA256",
            "KARTPAD_RR_XML_PATH",
            "KARTPAD_RR_XML_BYTES",
            "KARTPAD_RR_XML_SHA256",
        ):
            self.assertIn(constant, source)

        retro = json.loads(RELEASE_PROFILE.read_text())["retroRewind"]
        self.assertEqual(retro["version"], "6.12.4")
        self.assertEqual(retro["codePul"]["bytes"], 1_718_176)
        self.assertEqual(
            retro["codePul"]["sha256"],
            "ea93f9b8bf6d7696a807c1da5be724f1b0ec3eea563c1fdc1adfab10cb6c98e2",
        )
        self.assertEqual(retro["riivolutionXml"]["bytes"], 20_949)
        self.assertEqual(
            retro["riivolutionXml"]["sha256"],
            "9493911ddd39df695016e2cb7069df4a5f2b4c3a9eeef4d91ea00438ca7952df",
        )

        self.assertIn(
            'retroProfile ? @"enabled = true\\n\\n" : @"enabled = false\\n\\n";',
            source,
        )
        self.assertIn("retro_rewind_root", source)
        self.assertLess(source.index("if (retroProfile)"), source.index("NSString *networkConfig"))
        self.assertLess(
            source.index("NSString *networkConfig"),
            source.index("gSelectedRuntimeProfile = [selectedProfile"),
        )
        self.assertIn("gSelectedRuntimeProfile = [selectedProfile UTF8String];", source)
        self.assertIn("return gSelectedRuntimeProfile.c_str();", source)

    def test_host_reuses_extended_controller_adapter(self) -> None:
        source = HOST.read_text()
        self.assertIn("KartPadPhysicalControllers", source)
        self.assertIn("AdaptSunPadInput", source)
        self.assertIn('std::string gSelectedRuntimeProfile = "base";', source)
        for excluded in ("DiscIO", "MotionSteering", "GameOverlay"):
            self.assertNotIn(excluded, source)

    def test_patch_applies_after_current_apple_stack_and_builds_requested_tvos_target(
        self,
    ) -> None:
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
            patched_products = (runtime / "cmake/PublicProducts.cmake").read_text()
            self.assertIn(
                'if(CMAKE_SYSTEM_NAME STREQUAL "tvOS" AND MKW_KARTPAD_REPO_ROOT)\n'
                "    if(NOT MKW_KARTPAD_TVOS_TARGET)\n"
                '        message(FATAL_ERROR "MKW_KARTPAD_TVOS_TARGET must select the tvOS product")\n'
                "    elseif(NOT TARGET ${MKW_KARTPAD_TVOS_TARGET})\n"
                '        message(FATAL_ERROR "Requested tvOS target does not exist: ${MKW_KARTPAD_TVOS_TARGET}")\n'
                "    else()\n"
                "        mkw_configure_tvos_target(${MKW_KARTPAD_TVOS_TARGET})\n"
                "    endif()\n"
                "endif()",
                patched_products,
            )
            self.assertLess(
                patched_products.index("add_executable(KartPadDual"),
                patched_products.index(
                    "mkw_configure_tvos_target(${MKW_KARTPAD_TVOS_TARGET})"
                ),
            )
            self.assertIn(
                'if(CMAKE_SYSTEM_NAME STREQUAL "tvOS")\n'
                "        target_precompile_headers(KartPadDual PRIVATE\n"
                '            "${MKW_RUNTIME_SOURCE_DIR}/include/mkw_pch.h")\n'
                "    else()\n"
                "        target_precompile_headers(KartPadDual REUSE_FROM WiiCompiled)\n"
                "    endif()",
                patched_products,
            )
            self.assertIn("MKW_KARTPAD_TVOS_ASSETS", patched_products)
            self.assertIn(
                'XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "App Icon"',
                patched_products,
            )
            self.assertIn("kartpad-profile", patched_products)
            self.assertIn('if(CMAKE_SYSTEM_NAME STREQUAL "iOS" AND', patched_products)
            self.assertIn(
                'if(APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS"',
                patched_products,
            )

            selector_start = patched_products.rindex(
                'if(CMAKE_SYSTEM_NAME STREQUAL "tvOS" AND MKW_KARTPAD_REPO_ROOT)'
            )
            selector_end = patched_products.index(
                "\nendif()\n\nset(MKW_ALL_BUILD_TARGETS", selector_start
            ) + len("\nendif()")
            tvos_target_selector = patched_products[selector_start:selector_end]
            for requested_target in ("WiiCompiled", "KartPadDual"):
                probe_source = Path(temporary) / f"tvos-target-{requested_target}"
                probe_source.mkdir()
                (probe_source / "dual-capable-shards.cmake").write_text(
                    "# both translated product targets are available\n"
                )
                (probe_source / "CMakeLists.txt").write_text(
                    f"""cmake_minimum_required(VERSION 3.20)
project(kartpad_tvos_target_probe NONE)
set(CMAKE_SYSTEM_NAME tvOS)
set(MKW_KARTPAD_REPO_ROOT "{runtime}")
set(MKW_KARTPAD_TVOS_TARGET "{requested_target}")
set(MKW_HAVE_RETRO_REWIND ON)
set(MKW_TRANSLATED_SHARD_MANIFEST
    "${{CMAKE_CURRENT_SOURCE_DIR}}/dual-capable-shards.cmake")
add_custom_target(WiiCompiled
    COMMAND "${{CMAKE_COMMAND}}" -E touch
            "${{CMAKE_BINARY_DIR}}/base.stamp")
add_custom_target(KartPadDual
    COMMAND "${{CMAKE_COMMAND}}" -E touch
            "${{CMAKE_BINARY_DIR}}/dual.stamp")
function(mkw_configure_tvos_target target)
    set(MKW_CONFIGURED_TARGET "${{target}}" PARENT_SCOPE)
endfunction()
{tvos_target_selector}
if(NOT MKW_CONFIGURED_TARGET STREQUAL "{requested_target}")
    message(FATAL_ERROR "tvOS target selection ignored {requested_target}")
endif()
add_custom_target(selected ALL DEPENDS "{requested_target}")
"""
                )
                probe_build = probe_source / "build"
                subprocess.run(
                    [
                        "cmake",
                        "-S",
                        str(probe_source),
                        "-B",
                        str(probe_build),
                        "-G",
                        "Ninja",
                    ],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                subprocess.run(
                    ["cmake", "--build", str(probe_build), "--target", "selected"],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                stamp = "base.stamp" if requested_target == "WiiCompiled" else "dual.stamp"
                self.assertTrue((probe_build / stamp).is_file())

    def test_patch_shares_tvos_bundle_configuration_with_optional_dual_target(self) -> None:
        source = PATCH.read_text()
        self.assertIn('CMAKE_SYSTEM_NAME STREQUAL "tvOS"', source)
        self.assertIn("function(mkw_configure_tvos_target target)", source)
        self.assertIn(
            "mkw_configure_tvos_target(${MKW_KARTPAD_TVOS_TARGET})", source
        )
        self.assertIn("TARGET ${MKW_KARTPAD_TVOS_TARGET}", source)
        tvos_block = source[
            source.index("+if(CMAKE_SYSTEM_NAME STREQUAL \"tvOS\""):source.index(
                "\n \n if(MKW_HAVE_RETRO_REWIND)"
            )
        ]
        self.assertNotIn("MKW_HAVE_RETRO_REWIND", tvos_block)
        self.assertNotIn("+    mkw_configure_tvos_target(WiiCompiled)", tvos_block)
        self.assertIn(
            "+if(CMAKE_SYSTEM_NAME STREQUAL \"tvOS\" AND MKW_KARTPAD_REPO_ROOT)\n"
            "+    if(NOT MKW_KARTPAD_TVOS_TARGET)\n"
            '+        message(FATAL_ERROR "MKW_KARTPAD_TVOS_TARGET must select the tvOS product")\n'
            "+    elseif(NOT TARGET ${MKW_KARTPAD_TVOS_TARGET})\n"
            '+        message(FATAL_ERROR "Requested tvOS target does not exist: ${MKW_KARTPAD_TVOS_TARGET}")\n'
            "+    else()\n"
            "+        mkw_configure_tvos_target(${MKW_KARTPAD_TVOS_TARGET})\n"
            "+    endif()\n"
            "+endif()",
            source,
        )
        self.assertIn("MKW_KARTPAD_TVOS_ASSETS", tvos_block)
        self.assertIn("MKW_KARTPAD_TVOS_TARGET", source)
        self.assertIn("target_sources(${target} PRIVATE", tvos_block)
        self.assertIn("kartpad-profile", tvos_block)
        self.assertIn(
            '+            XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "App Icon"',
            tvos_block,
        )
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
        self.assertIn('binary_relative="KartPad.app/KartPad"', prepare)
        self.assertIn(
            'binary_relative="Release-appletvsimulator/KartPadTV.app/KartPadTV"',
            prepare,
        )
        self.assertIn("Release-appletvos/KartPadTV.app/KartPadTV", prepare)
        self.assertIn(
            'if [[ "${platform}" == appletv* ]]; then\n'
            '  generator="Xcode"\n'
            '  configuration_args=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_CONFIGURATION_TYPES=Release)\n'
            '  build_args=(--config Release --parallel 2)',
            prepare,
        )
        self.assertIn(
            '"${runtime_build}/Release-appletvsimulator/KartPadTV.app/Info.plist"',
            prepare,
        )
        self.assertIn("aurora-tvos-package-discovery.patch", prepare)
        self.assertIn("wiicompiled-tvos-runtime.patch", prepare)
        self.assertIn("inject-tvos-offline-save-completion.py", prepare)
        self.assertIn("TVOSSIMULATOR", prepare)
        self.assertIn("KARTPAD_WII_BANNER_SOURCE", prepare)
        self.assertIn(
            "KARTPAD_WII_BANNER_SOURCE:-${repo_root}/private/self-build/disc/files/opening.bnr",
            prepare,
        )
        self.assertIn("generate-tvos-banner-assets.py", prepare)
        self.assertIn("MKW_KARTPAD_TVOS_ASSETS", prepare)
        self.assertIn('-DMKW_KARTPAD_TVOS_TARGET="${product_target}"', prepare)
        self.assertIn("missing private Wii banner source", prepare)
        self.assertNotIn('cp "${tvos_banner_source}"', prepare)
        self.assertLess(
            prepare.index("generate-tvos-banner-assets.py"),
            prepare.index('if [[ "${prepare_only}" == "1" ]]'),
        )
        for product in ("base", "dual"):
            accepted = subprocess.run(
                [
                    PREPARE,
                    "missing-translation",
                    f"/tmp/kartpad-{product}-source",
                    f"/tmp/kartpad-{product}-build",
                    product,
                    "appletvsimulator",
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(accepted.returncode, 1)
            self.assertIn("missing real-title translation", accepted.stderr)
            self.assertNotIn("tvOS does not support standalone", accepted.stderr)
        rejected = subprocess.run(
            [
                PREPARE,
                "missing-translation",
                "/tmp/kartpad-rejected-source",
                "/tmp/kartpad-rejected-build",
                "retro-rewind",
                "appletvsimulator",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(rejected.returncode, 64)
        self.assertIn(
            "tvOS does not support standalone product=retro-rewind; use product=dual",
            rejected.stderr,
        )
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

    def test_tvos_staging_modes_validate_inputs_and_write_marker_last(self) -> None:
        stage = STAGE.read_text()
        self.assertIn(
            "--simulator SIMULATOR_UDID GAME_DATA base|retro-rewind [RETRO_ROOT]",
            stage,
        )
        self.assertIn(
            "--device DEVICE_ID GAME_DATA base|retro-rewind [RETRO_ROOT]",
            stage,
        )
        self.assertIn("--simulator|--device", stage)
        self.assertIn('validate_game_data "${game_data}"', stage)
        self.assertIn('validate_retro_root "${retro_root}"', stage)
        self.assertLess(
            stage.index('validate_game_data "${game_data}"'),
            stage.index("xcrun simctl terminate"),
        )
        self.assertLess(
            stage.index('validate_retro_root "${retro_root}"'),
            stage.index("xcrun simctl terminate"),
        )
        self.assertIn('if [[ ! -f "${dol}" || ! -f "${rel}" ]]', stage)
        self.assertIn('if [[ ! -f "${version}" || ! -f "${code_pul}" || ! -f "${retro_xml}" ]]', stage)
        for pin in (
            'expected_retro_version="6.12.4"',
            "expected_code_pul_bytes=1718176",
            "expected_retro_xml_bytes=20949",
            "ea93f9b8bf6d7696a807c1da5be724f1b0ec3eea563c1fdc1adfab10cb6c98e2",
            "9493911ddd39df695016e2cb7069df4a5f2b4c3a9eeef4d91ea00438ca7952df",
        ):
            self.assertIn(pin, stage)
        self.assertIn(
            'xcrun simctl terminate "${target}" dev.kartpad.app || true',
            stage,
        )
        self.assertIn(
            'xcrun simctl get_app_container "${target}" dev.kartpad.app data',
            stage,
        )
        self.assertIn(
            "xcrun devicectl device info processes --quiet --json-output - --device",
            stage,
        )
        self.assertIn(
            "xcrun devicectl device process terminate --device",
            stage,
        )
        self.assertIn("--pid", stage)
        self.assertIn("--kill", stage)
        self.assertIn("/KartPadTV.app/KartPadTV", stage)
        self.assertNotIn("device process launch", stage)
        self.assertIn("Library/Caches/KartPad/GameData", stage)
        self.assertIn(
            "Library/Caches/KartPad/RetroRewind/RetroRewind6",
            stage,
        )
        self.assertIn("RuntimeProfile", stage)
        self.assertIn('printf \'%s\\n\' "${runtime_profile}" > "${marker}"', stage)
        self.assertLess(
            stage.index('ditto "${game_data}" "${local_game_destination}"'),
            stage.index('ditto "${marker}" "${local_marker_destination}"'),
        )
        self.assertLess(
            stage.index('ditto "${retro_root}" "${local_retro_destination}"'),
            stage.index('ditto "${marker}" "${local_marker_destination}"'),
        )
        self.assertLess(
            stage.index('device_copy_to "${marker}" "${marker_destination}"'),
            stage.index("xcrun devicectl device copy from"),
        )
        self.assertIn("--domain-type appDataContainer", stage)
        self.assertIn("--domain-identifier dev.kartpad.app", stage)
        self.assertIn("--remove-existing-content false", stage)
        self.assertIn("stage_device_tree", stage)
        self.assertIn("size_kb > 400000", stage)
        self.assertIn('device_copy_to "${marker}" "${marker_destination}"', stage)
        self.assertIn("--timeout 600", stage)
        self.assertIn("for attempt in 1 2 3", stage)
        self.assertIn('validate_game_data "${verify_dir}/GameData"', stage)
        self.assertIn('validate_retro_root "${verify_dir}/RetroRewind/RetroRewind6"', stage)

    def test_tvos_audit_requires_compiled_app_icon_and_rejects_raw_banner_data(self) -> None:
        audit = AUDIT.read_text()
        self.assertIn('assets_car="${app}/Assets.car"', audit)
        self.assertIn('test -f "${assets_car}"', audit)
        self.assertIn("xcrun --find assetutil", audit)
        self.assertIn("xcrun assetutil --info", audit)
        self.assertIn(
            '"Name"[[:space:]]*:[[:space:]]*"App Icon - (Small|Large)',
            audit,
        )
        self.assertIn("App Icon catalog asset", audit)
        for raw_banner in ("opening.bnr", "banner.bin", "icon.bin", "sound.bin"):
            self.assertIn(f"'{raw_banner}'", audit)
        for contract in (
            "retro_rewind",
            "KartPadMobileSelectedRuntimeProfile",
            "retro_rewind_root",
            "network",
            "KartPadMobileEnsureGameDataAvailable",
            "KartPadMobileReadClassicInputForPlayer",
        ):
            self.assertIn(f"'{contract}'", audit)

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
