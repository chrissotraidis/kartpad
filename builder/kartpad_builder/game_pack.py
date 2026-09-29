"""Build a player's KartPad game pack from their own disc.

The published apps contain no game code. This extracts the disc, translates
it, and compiles one library against the published app's runtime:

- Android (Windows, Linux or macOS): libkartpad_game.so, linked against the
  APK's lib/arm64-v8a/libmain.so and loaded from the app's storage. Tools: the
  Android NDK, CMake, Ninja, .NET 8 and nodtool (PadForge supplies them).
- iPhone (macOS with Xcode): libkartpad_game.dylib, placed in the published
  IPA's Frameworks folder; the player's sideloading tool signs the result.
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
IOS_PACK_GITLINKS = ("vendor/runtimes/ios", "vendor/wiicompiled")


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


def _translated(repo, profile, image, image_sha256, work_root, jobs, gitlinks):
    """Extract and translate the disc (cached); returns (workspace, translation, progress)."""
    fingerprint = source_fingerprint(repo, gitlinks)
    key = cache_key(profile, image_sha256, fingerprint)
    profile_root = work_root / profile.id
    workspace = profile_root / "builds" / key
    # Short folder names keep extracted paths under Windows' 260-character limit.
    extraction = profile_root / "inputs" / image_sha256[:16] / "disc"
    translation = workspace / "translation"
    progress = ProgressLog(work_root / "logs/progress.jsonl")
    with progress.stage("preflight"):
        retro = prepare_inputs(profile, repo / "private/builder", install=False)
    with progress.stage("extract"):
        extract(profile, image, extraction)
    with progress.stage("translate"):
        translate(profile, repo, extraction, translation, jobs, retro)
    return workspace, translation, progress


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
    ndk = find_ndk(repo)
    workspace, translation, progress = _translated(
        repo, profile, image, image_sha256, work_root, jobs, ANDROID_PACK_GITLINKS)
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


def _xcrun(tool: str) -> str:
    import subprocess
    return subprocess.check_output(["xcrun", "--find", tool], text=True).strip()


def build_ios_pack(
    repo: Path,
    profile: Profile,
    image: Path,
    image_sha256: str,
    app: Path,
    output: Path,
    work_root: Path,
    jobs: int = 2,
) -> PackResult:
    """The published empty IPA with the player's game pack inside (unsigned)."""
    if platform.system() != "Darwin":
        raise BuildError("iPhone game packs need a Mac with Xcode for now")
    workspace, translation, progress = _translated(
        repo, profile, image, image_sha256, work_root, jobs, IOS_PACK_GITLINKS)
    with progress.stage("compile"):
        runtime = workspace / "ios-runtime"
        if not runtime.is_dir():
            runtime_stage.stage(repo, "ios", runtime)
        executable = workspace / "app" / "KartPad"
        executable.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(app) as archive:
            try:
                executable.write_bytes(archive.read("Payload/KartPad.app/KartPad"))
            except KeyError as error:
                raise BuildError(f"not a KartPad IPA: {app}") from error
            if "Payload/KartPad.app/Frameworks/libkartpad_game.dylib" in archive.namelist():
                raise BuildError(f"this IPA already contains a game pack: {app}")
        build = workspace / "ios-pack-build"
        run(["cmake", "-S", str(runtime / "game_pack"), "-B", str(build), "-G", "Ninja",
             "-DCMAKE_SYSTEM_NAME=iOS", "-DCMAKE_SYSTEM_PROCESSOR=arm64",
             "-DCMAKE_OSX_SYSROOT=iphoneos", "-DCMAKE_OSX_ARCHITECTURES=arm64",
             "-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0", "-DCMAKE_BUILD_TYPE=Release",
             f"-DMKW_TRANSLATED_SHARD_MANIFEST={translation / 'build_shards/shards.cmake'}",
             f"-DMKW_GAME_PACK_RUNTIME={executable}",
             f"-DMKW_KARTPAD_RUNTIME_INCLUDE={repo / 'runtime/include'}",
             f"-DKARTPAD_APP_VERSION={load_version(repo)['version']}",
             "-DMKW_GAME_PACK_DEFINITIONS=KARTPAD_UNOBSERVED_FP_STATUS=1"])
        run(["cmake", "--build", str(build), "--target", "kartpad_game", "--parallel", str(jobs)])
    built = build / "libkartpad_game.dylib"
    with progress.stage("check"):
        run([sys.executable, str(repo / "scripts/check-game-pack-state.py"),
             _xcrun("llvm-nm"), str(built), str(executable)])
    with progress.stage("package"):
        pack = workspace / "libkartpad_game.dylib"
        pack.write_bytes(built.read_bytes())
        run([_xcrun("strip"), "-x", str(pack)])
        run([_xcrun("install_name_tool"), "-id", "@rpath/libkartpad_game.dylib", str(pack)])
        output.parent.mkdir(parents=True, exist_ok=True)
        partial = output.with_name(output.name + ".partial")
        with zipfile.ZipFile(app) as source, zipfile.ZipFile(
                partial, "w", compression=zipfile.ZIP_DEFLATED) as target:
            for item in source.infolist():
                target.writestr(item, source.read(item))
            info = zipfile.ZipInfo("Payload/KartPad.app/Frameworks/libkartpad_game.dylib",
                                   (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100755 << 16
            target.writestr(info, pack.read_bytes(), compress_type=zipfile.ZIP_DEFLATED)
        partial.replace(output)
    return PackResult(pack=output, pack_sha256=sha256_file(output))
