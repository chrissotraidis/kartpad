"""Build a player's KartPad game pack for Android, on Windows, Linux or macOS.

The published APK contains no game code. This extracts the player's own disc,
translates it, and compiles the result into one library (libkartpad_game.so)
that links against the published app's runtime (lib/arm64-v8a/libmain.so) and
is loaded from the app's storage. Tools: the Android NDK, CMake, Ninja, .NET 8
and nodtool; PadForge downloads and checks them.
"""
from __future__ import annotations

import os
import platform
import re
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path

from . import runtime_stage
from .bootstrap import ANDROID_PACK_GITLINKS
from .errors import BuildError
from .packaging import load_version
from .pipeline import ProgressLog, cache_key, extract, run, source_fingerprint, translate
from .profiles import Profile, sha256_file
from .retro_rewind import prepare_inputs

HOST_TAGS = {"Darwin": "darwin-x86_64", "Linux": "linux-x86_64", "Windows": "windows-x86_64"}


@dataclass(frozen=True)
class PackResult:
    pack: Path
    pack_sha256: str


def _toolchain_setting(repo: Path, name: str) -> str:
    text = (repo / "scripts/android-toolchain-versions.sh").read_text()
    match = re.search(rf'^{name}="([^"]+)"', text, re.M)
    if not match:
        raise BuildError(f"missing {name} in scripts/android-toolchain-versions.sh")
    return match.group(1)


def find_ndk(repo: Path) -> Path:
    version = _toolchain_setting(repo, "KARTPAD_ANDROID_NDK")
    candidates = [os.environ.get("ANDROID_NDK_ROOT"), os.environ.get("ANDROID_NDK_HOME")]
    for sdk in (os.environ.get("ANDROID_SDK_ROOT"), os.environ.get("ANDROID_HOME"),
                str(Path.home() / "Library/Android/sdk"), str(Path.home() / "Android/Sdk")):
        if sdk:
            candidates.append(str(Path(sdk) / "ndk" / version))
    for candidate in filter(None, candidates):
        root = Path(candidate)
        if (root / "build/cmake/android.toolchain.cmake").is_file():
            return root
    raise BuildError(f"missing Android NDK {version}; set ANDROID_NDK_ROOT")


def _ndk_tool(ndk: Path, name: str) -> Path:
    suffix = ".exe" if os.name == "nt" else ""
    tool = ndk / "toolchains/llvm/prebuilt" / HOST_TAGS[platform.system()] / "bin" / (name + suffix)
    if not tool.is_file():
        raise BuildError(f"missing NDK tool: {tool}")
    return tool


def app_runtime(app: Path, destination: Path) -> Path:
    """The published app's runtime library, from the APK or given directly."""
    if app.suffix == ".so":
        return app
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(app) as archive:
        try:
            data = archive.read("lib/arm64-v8a/libmain.so")
        except KeyError as error:
            raise BuildError(f"not a KartPad APK (no lib/arm64-v8a/libmain.so): {app}") from error
    library = destination / "libmain.so"
    library.write_bytes(data)
    return library


def build_android_pack(
    repo: Path,
    profile: Profile,
    image: Path,
    image_sha256: str,
    app: Path,
    output: Path,
    work_root: Path,
    jobs: int = 2,
) -> PackResult:
    fingerprint = source_fingerprint(repo, ANDROID_PACK_GITLINKS)
    key = cache_key(profile, image_sha256, fingerprint)
    profile_root = work_root / profile.id
    workspace = profile_root / "builds" / key
    extraction = profile_root / "inputs" / image_sha256 / "disc"
    translation = workspace / "translation"
    progress = ProgressLog(work_root / "logs/progress.jsonl")
    ndk = find_ndk(repo)
    with progress.stage("preflight"):
        retro = prepare_inputs(profile, repo / "private/builder", install=False)
    with progress.stage("extract"):
        extract(profile, image, extraction)
    with progress.stage("translate"):
        translate(profile, repo, extraction, translation, jobs, retro)
    with progress.stage("compile"):
        runtime = workspace / "android-runtime"
        if not runtime.is_dir():
            runtime_stage.stage(repo, "android", runtime)
        app_version = load_version(repo)["version"]
        library = app_runtime(app, workspace / "app")
        definitions = ";".join(
            line.strip() for line in
            (repo / "android/app/src/main/cpp/translated-definitions.txt").read_text().splitlines()
            if line.strip())
        build = workspace / "android-pack-build"
        run(["cmake", "-S", str(runtime / "game_pack"), "-B", str(build), "-G", "Ninja",
             f"-DCMAKE_TOOLCHAIN_FILE={ndk / 'build/cmake/android.toolchain.cmake'}",
             "-DANDROID_ABI=arm64-v8a",
             f"-DANDROID_PLATFORM=android-{_toolchain_setting(repo, 'KARTPAD_ANDROID_MIN_SDK')}",
             "-DANDROID_STL=c++_shared", "-DCMAKE_BUILD_TYPE=Release",
             f"-DMKW_TRANSLATED_SHARD_MANIFEST={translation / 'build_shards/shards.cmake'}",
             f"-DMKW_GAME_PACK_RUNTIME={library}",
             f"-DMKW_KARTPAD_RUNTIME_INCLUDE={repo / 'runtime/include'}",
             f"-DKARTPAD_APP_VERSION={app_version}",
             f"-DMKW_GAME_PACK_DEFINITIONS={definitions}"])
        run(["cmake", "--build", str(build), "--target", "kartpad_game", "--parallel", str(jobs)])
    built = build / "libkartpad_game.so"
    with progress.stage("check"):
        run([sys.executable, str(repo / "scripts/check-game-pack-state.py"),
             str(_ndk_tool(ndk, "llvm-nm")), str(built), str(library)])
    with progress.stage("package"):
        output.parent.mkdir(parents=True, exist_ok=True)
        run([str(_ndk_tool(ndk, "llvm-strip")), "--strip-unneeded", "-o", str(output), str(built)])
    return PackResult(pack=output, pack_sha256=sha256_file(output))
