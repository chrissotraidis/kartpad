#!/usr/bin/env python3
"""Synthetic cold-start regression using the maintained Android config parser.

Host execution checks cached config and static settings, not Android provider
ordering or SDL/JNI startup. Each startup order gets a fresh process and storage.
"""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parents[1]
    runtime = repo / "vendor/runtimes/android/runtime"
    with tempfile.TemporaryDirectory(prefix="kartpad-cold-config-") as temporary:
        scratch = Path(temporary).resolve()
        binary = scratch / "cold-config-tests"
        subprocess.run(shlex.split(os.environ.get("CXX", "clang++")) + [
            "-std=c++20", "-O1", "-g", "-Wall", "-Wextra", "-Werror",
            "-Wno-deprecated-literal-operator", "-fsanitize=address,undefined",
            "-I" + str(runtime / "include"), "-I" + str(runtime / "third_party/toml11"),
            str(repo / "runtime/tests/android_cold_config_tests.cpp"), "-o", str(binary),
        ], check=True)
        for mode in ("late-env", "early-env"):
            root = scratch / mode
            (root / "files/KartPad").mkdir(parents=True)
            (root / "cache").mkdir()
            env = os.environ.copy()
            env.pop("KARTPAD_ANDROID_FILES_DIR", None)
            env.pop("KARTPAD_ANDROID_CACHE_DIR", None)
            if mode == "early-env":
                env["KARTPAD_ANDROID_FILES_DIR"] = str(root / "files")
                env["KARTPAD_ANDROID_CACHE_DIR"] = str(root / "cache")
                (root / "files/KartPad/Config.toml").write_text(
                    '[paths]\ndvd_root = "DVD"\n[audio]\nvolume = 0.25\nmuted = true\n',
                    encoding="utf-8",
                )
            subprocess.run([str(binary), mode, str(root)], cwd=root, env=env, check=True)


if __name__ == "__main__":
    main()
