#!/usr/bin/env python3
"""Build KartPad's real iOS pack project with synthetic inputs, without a game disc.

Run on a Mac with Xcode's iOS SDK, CMake and Ninja:
    python3 scripts/probe-ios-pack.py WORK_FOLDER

Only disc extraction/translation is substituted. Runtime staging, fingerprinting,
CMake, ARM64 compilation, symbol validation, stripping and IPA insertion are real.
The output is a test fixture, not a playable app. Full game/device acceptance is separate.
"""
import json
import os
from pathlib import Path
import platform
import plistlib
import subprocess
import sys
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "builder"))
from kartpad_builder import game_pack  # noqa: E402
from kartpad_builder.profiles import load_profiles  # noqa: E402


def main():
    if platform.system() != "Darwin" or len(sys.argv) != 2:
        raise SystemExit(__doc__)
    root = Path(sys.argv[1]).resolve()
    root.mkdir(parents=True, exist_ok=False)
    # Never place synthetic output in a player's real pack cache.
    os.environ["PADMINT_CACHE"] = str(root / "cache")
    for name in ("SDKROOT", "CPATH", "LIBRARY_PATH"):
        os.environ.pop(name, None)
    source = root / "app.cpp"
    source.write_text('extern "C" int fixture_runtime() { return 7; }\nint main() { return 0; }\n')
    executable = root / "KartPad"
    sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
    subprocess.run(["xcrun", "--sdk", "iphoneos", "clang++", "-arch", "arm64",
                    "-isysroot", sdk, "-miphoneos-version-min=16.0", str(source),
                    "-Wl,-export_dynamic", "-o", str(executable)], check=True)
    app = root / "fixture.ipa"
    with zipfile.ZipFile(app, "w") as archive:
        archive.write(executable, "Payload/KartPad.app/KartPad")
        archive.writestr("Payload/KartPad.app/Info.plist", plistlib.dumps({
            "CFBundleIdentifier": "dev.kartpad.build-probe", "CFBundleExecutable": "KartPad",
            "CFBundlePackageType": "APPL", "MinimumOSVersion": "16.0",
        }))

    def translated(*args, workspace, **kwargs):
        translation = workspace / "translation"
        shards = translation / "build_shards"
        shards.mkdir(parents=True)
        (shards / "shards.cmake").write_text('set(MKW_HAVE_RETRO_REWIND_SHARDS OFF)\n')
        (translation / "RuntimeConfig.h").write_text(
            '#pragma once\n#include <cstdint>\nnamespace RuntimeConfig {\n'
            'constexpr uint32_t SDA1_BASE = 0, SDA2_BASE = 0;\n}\n')
        # Compile the production pack interface plus ARM NEON and C++ library use.
        (translation / "data_sections_init.cpp").write_text(
            '#include "game_pack.h"\n#include <arm_neon.h>\n#include <vector>\n'
            'extern "C" int fixture_runtime();\n'
            'extern "C" void InitializeDataSections() {\n'
            '  std::vector<int> values(4, fixture_runtime());\n'
            '  volatile int sum = vaddvq_s32(vld1q_s32(values.data())); (void)sum;\n}\n'
            '#define FIXTURE_ORIGINAL(hex) extern "C" void func_##hex(CpuContext*) {}\n'
            'KARTPAD_GAME_PACK_ORIGINALS(FIXTURE_ORIGINAL)\n')
        (translation / "data_sections_init_blobs.S").write_text(
            '.section __TEXT,__const\n.p2align 2\n.globl _fixture_constant\n_fixture_constant:\n.long 7\n')
        return workspace, translation, game_pack.ProgressLog(root / "progress.jsonl")

    output = root / "probe.ipa"
    with mock.patch.object(game_pack, "_translated", side_effect=translated):
        result = game_pack.build_ios_pack(
            ROOT, load_profiles(ROOT / "builder/profiles")[0], root / "synthetic.iso",
            "0" * 64, app, output, root / "work", jobs=2)
    module = root / "module.dylib"
    with zipfile.ZipFile(result.pack) as archive:
        assert archive.read("Payload/KartPad.app/KartPad") == executable.read_bytes()
        module.write_bytes(archive.read("Payload/KartPad.app/Frameworks/libkartpad_game.dylib"))
    arch = subprocess.check_output(["xcrun", "lipo", "-archs", str(module)], text=True).strip()
    metadata = subprocess.check_output(["xcrun", "vtool", "-show-build", str(module)], text=True)
    assert arch == "arm64", arch
    assert "platform IOS" in metadata and "minos 16.0" in metadata, metadata
    exports = subprocess.check_output(["xcrun", "nm", "-g", str(module)], text=True)
    assert "_kartpad_game_pack_info" in exports, exports
    assert "_fixture_runtime" in exports, exports
    print(json.dumps({"host": platform.machine(), "target": arch, "build": metadata,
                      "ipa": str(result.pack), "sha256": result.pack_sha256}, indent=2))
    print("PASS: production iOS pack build with synthetic inputs; no gameplay claim.")


if __name__ == "__main__":
    main()
