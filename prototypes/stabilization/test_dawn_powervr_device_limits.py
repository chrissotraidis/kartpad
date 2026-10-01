#!/usr/bin/env python3
"""Build/run real Dawn frontend regression with a controlled physical-device fixture.

The candidate must be an already built Android source/build/install tree. Native
compile flags come from its own compile_commands.json, preserving header/ABI
configuration. Run only a standalone executable; never install or change an app.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--serial", default="emulator-5554")
    sdk = Path(os.environ.get("ANDROID_SDK_ROOT", str(Path.home() / "Library/Android/sdk")))
    parser.add_argument("--adb", default=shutil.which("adb") or str(sdk / "platform-tools/adb"))
    parser.add_argument("--build-only", action="store_true")
    parser.add_argument("--production-wgsl", type=Path,
                        help="optional renderer-generated WGSL with vs_main/fs_main entry points")
    args = parser.parse_args()
    candidate = args.candidate.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    binary = args.output.resolve() / "dawn-powervr-device-limits"
    commands = json.loads((candidate / "build/compile_commands.json").read_text())
    entry = next(item for item in commands if item["file"].endswith("/src/dawn/native/null/DeviceNull.cpp"))
    original = entry.get("arguments") or shlex.split(entry["command"])
    source_suffix = "/src/dawn/native/null/DeviceNull.cpp"
    original_source = entry["file"][:-len(source_suffix)]
    original_build = str(Path(entry["directory"]))
    command = []
    skip = False
    for item in original:
        if skip:
            skip = False
            continue
        if item in ("-c", "-o"):
            skip = True
            continue
        # A copied CMake tree can retain the old owner's absolute source/build
        # paths. Resolve all candidate-local paths to this selected candidate.
        item = item.replace(original_source, str(candidate / "source"))
        item = item.replace(original_build, str(candidate / "build"))
        command.append(item)
    source = Path(__file__).with_name("dawn_powervr_device_limits.cpp")
    command.extend([str(source), str(candidate / "install/lib/libwebgpu_dawn.a"),
                    "-static-libstdc++", "-llog", "-landroid", "-ldl", "-o", str(binary)])
    subprocess.run(command, check=True, cwd=candidate / "build")
    print(f"Built {binary}", flush=True)
    if args.build_only:
        return
    remote = "/data/local/tmp/kartpad-focused-powervr-device-limits"
    adb = [args.adb, "-s", args.serial]
    subprocess.run(adb + ["push", str(binary), remote], check=True)
    subprocess.run(adb + ["shell", "chmod", "700", remote], check=True)
    arguments = [remote]
    evidence = ""
    if args.production_wgsl:
        shader = args.production_wgsl.resolve()
        remote_shader = remote + ".wgsl"
        subprocess.run(adb + ["push", str(shader), remote_shader], check=True)
        arguments.append(remote_shader)
        evidence = f"Production WGSL SHA256: {hashlib.sha256(shader.read_bytes()).hexdigest()}\n"
    result = subprocess.run(adb + ["shell"] + arguments, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT)
    (args.output / "native-device-limits.log").write_text(evidence + result.stdout)
    print(evidence + result.stdout, end="")
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
