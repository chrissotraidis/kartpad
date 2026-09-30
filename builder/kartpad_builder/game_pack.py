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
import shutil
import subprocess
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path

from . import game_data, pack_fingerprint, runtime_stage
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


LLVM_TOOLS = ("ld.lld", "lld", "llvm-ar", "llvm-ranlib", "llvm-nm", "llvm-strip", "llvm-objcopy",
              "llvm-readelf", "llvm-readobj", "llvm-cxxfilt")


def linux_arm64() -> bool:
    return platform.system() == "Linux" and platform.machine().lower() in ("aarch64", "arm64")


def arm64_ndk(ndk: Path, llvm: Path, shim: Path) -> Path:
    """An NDK layout for Linux arm64, where Google publishes no NDK.

    PadForge installs the Linux NDK's host-independent parts (CMake scripts,
    sysroot, Android runtime libraries) and LLVM's own arm64 build of the same
    clang major version. The NDK's CMake expects its x86_64 prebuilt folder on
    any Linux, so that folder is assembled here from links and two small
    compiler wrappers with the NDK clang's defaults.
    """
    clang_root = ndk / "toolchains/llvm/prebuilt/linux-x86_64/lib/clang"
    versions = sorted(path.name for path in clang_root.iterdir()) if clang_root.is_dir() else []
    if len(versions) != 1 or not (llvm / "lib/clang" / versions[0] / "include").is_dir():
        raise BuildError(f"LLVM at {llvm} does not match the NDK's clang {versions or '?'}; "
                         "run PadForge again to install the matching tools")
    major = versions[0]
    check_linker(llvm)
    prebuilt = shim / "toolchains/llvm/prebuilt/linux-x86_64"
    if shim.exists():
        shutil.rmtree(shim)
    (prebuilt / "bin").mkdir(parents=True)
    (prebuilt / f"lib/clang/{major}/lib").mkdir(parents=True)
    for name in ("build", "meta", "source.properties"):
        (shim / name).symlink_to(ndk / name)
    (prebuilt / "sysroot").symlink_to(ndk / "toolchains/llvm/prebuilt/linux-x86_64/sysroot")
    resources = prebuilt / f"lib/clang/{major}"
    # Built-in headers must come from the compiler; runtime libraries from the NDK.
    (resources / "include").symlink_to(llvm / f"lib/clang/{major}/include")
    (resources / "lib/linux").symlink_to(clang_root / major / "lib/linux")
    for name in ("clang", "clang++"):
        wrapper = prebuilt / "bin" / name
        wrapper.write_text(f'#!/bin/sh\nexec "{llvm / "bin" / name}" -resource-dir "{resources}" '
                           '-rtlib=compiler-rt -unwindlib=libunwind -fuse-ld=lld "$@"\n')
        wrapper.chmod(0o755)
    for name in LLVM_TOOLS:
        (prebuilt / "bin" / name).symlink_to(llvm / "bin" / name)
    (prebuilt / "bin/ld").symlink_to(llvm / "bin/ld.lld")
    return shim


def check_linker(llvm: Path) -> None:
    """LLVM's arm64 linker loads libxml2, which minimal systems (a fresh Ubuntu,
    Termux's Ubuntu) do not have; say so before CMake fails obscurely."""
    try:
        result = subprocess.run([str(llvm / "bin/ld.lld"), "--version"], capture_output=True, text=True)
    except OSError as error:
        raise BuildError(f"LLVM's linker cannot start: {error}") from error
    if result.returncode == 0:
        return
    detail = (result.stderr or result.stdout).strip().splitlines()
    detail = detail[-1] if detail else f"exit code {result.returncode}"
    if "libxml2" in detail:
        raise BuildError("LLVM's linker needs the libxml2 library. Install it (Debian, Ubuntu, "
                         "Raspberry Pi OS: sudo apt install libxml2) and run PadForge again. "
                         f"({detail})")
    raise BuildError(f"LLVM's linker cannot start: {detail}")


PACK_RECORD = "pack-symbols.json"
PACK_FILES = {"android": "libkartpad_game.so", "ios": "libkartpad_game.dylib"}


def _pack_cache(platform_name: str, fingerprint: str, image_sha256: str) -> Path | None:
    """PadForge's cache folder for one player's pack (PADFORGE_CACHE), if any."""
    root = os.environ.get("PADFORGE_CACHE")
    if not root:
        return None
    return Path(root) / "kartpad/packs" / f"{platform_name}-{fingerprint[:32]}-{image_sha256[:16]}"


def reusable_pack(platform_name: str, fingerprint: str, image_sha256: str) -> Path | None:
    """A pack built earlier from the same disc for the same pack interface.

    After a KartPad update with an unchanged fingerprint the new app accepts the
    same pack, so the compile is skipped. The caller still checks it against the
    new app from its recorded symbols."""
    folder = _pack_cache(platform_name, fingerprint, image_sha256)
    if folder and (folder / PACK_FILES[platform_name]).is_file() and (folder / PACK_RECORD).is_file():
        print(f"Reusing your game pack: this KartPad keeps the same pack interface ({fingerprint[:12]}).",
              flush=True)
        return folder
    return None


def keep_pack(platform_name: str, fingerprint: str, image_sha256: str, pack: Path, record: Path) -> None:
    """Keep a checked pack and its symbol record for the next KartPad version (best effort)."""
    folder = _pack_cache(platform_name, fingerprint, image_sha256)
    if folder is None:
        return
    stage = folder.with_name(folder.name + f".partial.{os.getpid()}")
    try:
        if stage.exists():
            shutil.rmtree(stage)
        stage.mkdir(parents=True)
        shutil.copyfile(pack, stage / PACK_FILES[platform_name])
        shutil.copyfile(record, stage / PACK_RECORD)
        if folder.exists():
            shutil.rmtree(folder)
        stage.rename(folder)
    except OSError as error:
        print(f"Could not keep the game pack for the next update: {error}", flush=True)
    finally:
        if stage.exists():
            shutil.rmtree(stage, ignore_errors=True)


def host_ndk(repo: Path, work_root: Path) -> Path:
    """The NDK for this computer (assembled on Linux arm64, see arm64_ndk)."""
    ndk = find_ndk(repo)
    if not linux_arm64():
        return ndk
    llvm = os.environ.get("PADFORGE_LLVM_ROOT")
    if not llvm:
        raise BuildError("Linux arm64 builds need the LLVM 21 that PadForge installs there "
                         "(PADFORGE_LLVM_ROOT); update PadForge to its latest release and run it again")
    return arm64_ndk(ndk, Path(llvm), work_root / "ndk-linux-arm64")


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
    extraction = game_data.extraction_root(work_root, profile.id, image_sha256)
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
    ndk = host_ndk(repo, work_root)
    workspace, translation, progress = _translated(
        repo, profile, image, image_sha256, work_root, jobs, ANDROID_PACK_GITLINKS)
    with progress.stage("compile"):
        runtime = workspace / "android-runtime"
        if not runtime.is_dir():
            runtime_stage.stage(repo, "android", runtime)
        fingerprint = pack_fingerprint.fingerprint(repo, "android", runtime)
        app_version = load_version(repo)["version"]
        library = app_runtime(app, workspace / "app")
        cached = reusable_pack("android", fingerprint, image_sha256)
        build = workspace / "android-pack-build"
        record = workspace / "android-pack.pack-symbols.json"
        if cached is None:
            definitions = ";".join(pack_fingerprint.definitions(repo, "android"))
            run(["cmake", "-S", str(runtime / "game_pack"), "-B", str(build), "-G", "Ninja",
             f"-DCMAKE_TOOLCHAIN_FILE={ndk / 'build/cmake/android.toolchain.cmake'}",
             "-DANDROID_ABI=arm64-v8a",
             f"-DANDROID_PLATFORM=android-{_toolchain_setting(repo, 'KARTPAD_ANDROID_MIN_SDK')}",
             "-DANDROID_STL=c++_shared", "-DCMAKE_BUILD_TYPE=Release",
             f"-DMKW_TRANSLATED_SHARD_MANIFEST={translation / 'build_shards/shards.cmake'}",
             f"-DMKW_GAME_PACK_RUNTIME={library}",
             f"-DMKW_KARTPAD_RUNTIME_INCLUDE={repo / 'runtime/include'}",
             f"-DKARTPAD_APP_VERSION={app_version}",
             f"-DKARTPAD_PACK_FINGERPRINT={fingerprint}",
             f"-DMKW_GAME_PACK_DEFINITIONS={definitions}"])
            run(["cmake", "--build", str(build), "--target", "kartpad_game", "--parallel", str(jobs)])
    built = build / "libkartpad_game.so"
    with progress.stage("check"):
        # A reused pack is checked again, against this app, from its recorded symbols.
        checked = cached / PACK_RECORD if cached else built
        run([sys.executable, str(repo / "scripts/check-game-pack-state.py"),
             str(_ndk_tool(ndk, "llvm-nm")), str(checked), str(library)]
            + ([] if cached else ["--record", str(record)]))
    with progress.stage("package"):
        output.parent.mkdir(parents=True, exist_ok=True)
        if cached:
            shutil.copyfile(cached / "libkartpad_game.so", output)
        else:
            run([str(_ndk_tool(ndk, "llvm-strip")), "--strip-unneeded", "-o", str(output), str(built)])
            keep_pack("android", fingerprint, image_sha256, output, record)
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
        fingerprint = pack_fingerprint.fingerprint(repo, "ios", runtime)
        executable = workspace / "app" / "KartPad"
        executable.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(app) as archive:
            try:
                executable.write_bytes(archive.read("Payload/KartPad.app/KartPad"))
            except KeyError as error:
                raise BuildError(f"not a KartPad IPA: {app}") from error
            if "Payload/KartPad.app/Frameworks/libkartpad_game.dylib" in archive.namelist():
                raise BuildError(f"this IPA already contains a game pack: {app}")
        cached = reusable_pack("ios", fingerprint, image_sha256)
        build = workspace / "ios-pack-build"
        record = workspace / "ios-pack.pack-symbols.json"
        if cached is None:
            run(["cmake", "-S", str(runtime / "game_pack"), "-B", str(build), "-G", "Ninja",
             "-DCMAKE_SYSTEM_NAME=iOS", "-DCMAKE_SYSTEM_PROCESSOR=arm64",
             "-DCMAKE_OSX_SYSROOT=iphoneos", "-DCMAKE_OSX_ARCHITECTURES=arm64",
             "-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0", "-DCMAKE_BUILD_TYPE=Release",
             f"-DMKW_TRANSLATED_SHARD_MANIFEST={translation / 'build_shards/shards.cmake'}",
             f"-DMKW_GAME_PACK_RUNTIME={executable}",
             f"-DMKW_KARTPAD_RUNTIME_INCLUDE={repo / 'runtime/include'}",
             f"-DKARTPAD_APP_VERSION={load_version(repo)['version']}",
             f"-DKARTPAD_PACK_FINGERPRINT={fingerprint}",
             "-DMKW_GAME_PACK_DEFINITIONS=" + ";".join(pack_fingerprint.definitions(repo, "ios"))])
            run(["cmake", "--build", str(build), "--target", "kartpad_game", "--parallel", str(jobs)])
    built = build / "libkartpad_game.dylib"
    with progress.stage("check"):
        checked = cached / PACK_RECORD if cached else built
        run([sys.executable, str(repo / "scripts/check-game-pack-state.py"),
             _xcrun("llvm-nm"), str(checked), str(executable)] + ([] if cached else ["--record", str(record)]))
    with progress.stage("package"):
        pack = workspace / "libkartpad_game.dylib"
        if cached:
            shutil.copyfile(cached / PACK_FILES["ios"], pack)
        else:
            pack.write_bytes(built.read_bytes())
            run([_xcrun("strip"), "-x", str(pack)])
            run([_xcrun("install_name_tool"), "-id", "@rpath/libkartpad_game.dylib", str(pack)])
            keep_pack("ios", fingerprint, image_sha256, pack, record)
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
