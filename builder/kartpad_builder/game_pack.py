"""Build a player's KartPad game pack from their own disc.

The published apps contain no game code. This extracts the disc, translates
it, and compiles one library against the published app's runtime:

- Android (Windows, Linux or macOS): libkartpad_game.so, linked against the
  APK's lib/arm64-v8a/libmain.so and loaded from the app's storage. Tools: the
  Android NDK, CMake, Ninja, .NET 8 and nodtool (PadMint supplies them).
- iPhone: libkartpad_game.dylib, placed in the published IPA's Frameworks
  folder; the player's sideloading tool signs the result. On a Mac it is built
  with Xcode; on Windows and Linux with LLVM and an SDK assembled from
  open-source parts (ios_sdk.py), which PadMint supplies with the other tools.
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

from . import game_data, ios_sdk, pack_fingerprint, runtime_stage
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

    PadMint installs the Linux NDK's host-independent parts (CMake scripts,
    sysroot, Android runtime libraries) and LLVM's own arm64 build of the same
    clang major version. The NDK's CMake expects its x86_64 prebuilt folder on
    any Linux, so that folder is assembled here from links and two small
    compiler wrappers with the NDK clang's defaults.
    """
    clang_root = ndk / "toolchains/llvm/prebuilt/linux-x86_64/lib/clang"
    versions = sorted(path.name for path in clang_root.iterdir()) if clang_root.is_dir() else []
    if len(versions) != 1 or not (llvm / "lib/clang" / versions[0] / "include").is_dir():
        raise BuildError(f"LLVM at {llvm} does not match the NDK's clang {versions or '?'}; "
                         "run PadMint again to install the matching tools")
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
                         "Raspberry Pi OS: sudo apt install libxml2) and run PadMint again. "
                         f"({detail})")
    raise BuildError(f"LLVM's linker cannot start: {detail}")


PACK_RECORD = "pack-symbols.json"
PACK_FILES = {"android": "libkartpad_game.so", "ios": "libkartpad_game.dylib"}


def _pack_cache(platform_name: str, fingerprint: str, image_sha256: str) -> Path | None:
    """PadMint's cache folder for one player's pack (PADMINT_CACHE), if any."""
    # PadForge was PadMint's name before 0.2.0; older copies set PADFORGE_*.
    root = os.environ.get("PADMINT_CACHE") or os.environ.get("PADFORGE_CACHE")
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
    llvm = os.environ.get("PADMINT_LLVM_ROOT") or os.environ.get("PADFORGE_LLVM_ROOT")
    if not llvm:
        raise BuildError("Linux arm64 builds need the LLVM 21 that PadMint installs there "
                         "(PADMINT_LLVM_ROOT); update PadMint to its latest release and run it again")
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
        else:
            runtime_stage.stage_extras(repo, runtime)
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


def _ios_llvm() -> Path | None:
    """PadMint's LLVM when building off a Mac (None on a Mac: Xcode builds there)."""
    if platform.system() == "Darwin":
        return None
    llvm = os.environ.get("PADMINT_LLVM_ROOT") or os.environ.get("PADFORGE_LLVM_ROOT")
    if not llvm:
        raise BuildError("iPhone game packs off a Mac need the LLVM that PadMint installs "
                         "(PADMINT_LLVM_ROOT); update PadMint to its latest release and run it again")
    return Path(llvm)


def _names(command: list[str]) -> set[str]:
    return set(subprocess.run(command, check=True, capture_output=True, text=True).stdout.split())


def mach_o_blobs(translation: Path) -> None:
    """Write the translation's data blobs as the translator writes them on a Mac.

    The translator spells its blob assembly for the computer it runs on
    (AssemblyBlobWriter.cs: ELF on Linux, COFF on Windows, Mach-O on a Mac), and
    the pack project assembles blobs for Apple targets as written. Off a Mac
    they are rewritten here: Mach-O's read-only section, the leading-underscore
    symbol names (the builder already adds them as aliases) and no ELF stack note."""
    manifest = (translation / "build_shards/shards.cmake").read_text()
    blobs = {translation / "data_sections_init_blobs.S",
             *(Path(path) for path in re.findall(r'"([^"]+\.S)"', manifest))}
    for path in sorted(blobs):
        if not path.is_file():
            continue
        text = path.read_text()
        text = text.replace('.section .rodata,"a",@progbits', ".section __TEXT,__const")
        text = text.replace('.section .rdata,"dr"', ".section __TEXT,__const")
        text = re.sub(r'(?m)^\.section \.note\.GNU-stack,"",@progbits\n', "", text)
        if re.search(r"(?m)^\.globl _k", text):
            text = re.sub(r"(?m)^(\.globl k[^\n]*|k[^\n]*:)\n", "", text)
        else:
            text = re.sub(r"(?m)^(\.globl )?k([^\n]*)$", lambda m: f"{m.group(1) or ''}_k{m.group(2)}", text)
        path.write_text(text)


def app_thread_locals(llvm: Path, executable: Path) -> list[str]:
    """The published app's thread-local exports (its __thread_vars section)."""
    listing = subprocess.run([str(ios_sdk.llvm_tool(llvm, "llvm-nm")), "-m", "-g", "--defined-only",
                              str(executable)], check=True, capture_output=True, text=True).stdout
    return sorted(line.split()[-1] for line in listing.splitlines() if "(__DATA,__thread_vars)" in line)


def check_pack_imports(llvm: Path, pack: Path, executable: Path) -> None:
    """Every name an off-Mac pack imports is looked up by name when it loads.
    Those the app does not export must be the C++ standard library's or C's
    (libSystem): a missing KartPad runtime name would otherwise only show on
    the phone."""
    nm = str(ios_sdk.llvm_tool(llvm, "llvm-nm"))
    imports = _names([nm, "-u", "-j", str(pack)])
    system = sorted(imports - _names([nm, "-g", "--defined-only", "-j", str(executable)]))
    cxx = [name for name in system if name.startswith("__Z")]
    readable = subprocess.run([str(ios_sdk.llvm_tool(llvm, "llvm-cxxfilt"))], input="\n".join(cxx),
                              capture_output=True, text=True, check=True).stdout.splitlines()
    standard = re.compile(r"((typeinfo name|typeinfo|construction vtable|vtable|VTT|guard variable) for "
                          r"|(non-)?virtual thunk to )?(std::|__cxxabiv1::|operator (new|delete))")
    unknown = [text for text in readable if not standard.match(text)]
    if unknown:
        raise BuildError("the game pack needs names the published app does not export: " + ", ".join(unknown[:10]))
    print(f"Game pack imports: {len(imports) - len(system)} from the app, {len(system)} from the "
          "iPhone's libSystem and libc++.", flush=True)


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
    llvm = _ios_llvm()
    sources = ios_sdk.source_roots() if llvm else None
    workspace, translation, progress = _translated(
        repo, profile, image, image_sha256, work_root, jobs, IOS_PACK_GITLINKS)
    with progress.stage("compile"):
        runtime = workspace / "ios-runtime"
        if not runtime.is_dir():
            runtime_stage.stage(repo, "ios", runtime)
        else:
            runtime_stage.stage_extras(repo, runtime)
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
            if llvm:
                mach_o_blobs(translation)
                sdk = ios_sdk.assemble(repo, workspace / ios_sdk.FOLDER, sources)
                ios_sdk.write_stubs(sdk, app_thread_locals(llvm, executable))
                target = [f"-DCMAKE_TOOLCHAIN_FILE={ios_sdk.toolchain(sdk, llvm)}"]
            else:
                target = ["-DCMAKE_SYSTEM_NAME=iOS", "-DCMAKE_SYSTEM_PROCESSOR=arm64",
                          "-DCMAKE_OSX_SYSROOT=iphoneos", "-DCMAKE_OSX_ARCHITECTURES=arm64",
                          "-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0"]
            run(["cmake", "-S", str(runtime / "game_pack"), "-B", str(build), "-G", "Ninja",
             *target, "-DCMAKE_BUILD_TYPE=Release",
             f"-DMKW_TRANSLATED_SHARD_MANIFEST={translation / 'build_shards/shards.cmake'}",
             f"-DMKW_GAME_PACK_RUNTIME={executable}",
             f"-DMKW_KARTPAD_RUNTIME_INCLUDE={repo / 'runtime/include'}",
             f"-DKARTPAD_APP_VERSION={load_version(repo)['version']}",
             f"-DKARTPAD_PACK_FINGERPRINT={fingerprint}",
             "-DMKW_GAME_PACK_DEFINITIONS=" + ";".join(pack_fingerprint.definitions(repo, "ios"))])
            run(["cmake", "--build", str(build), "--target", "kartpad_game", "--parallel", str(jobs)])
            if llvm:
                check_pack_imports(llvm, build / "libkartpad_game.dylib", executable)
    built = build / "libkartpad_game.dylib"
    tool = (lambda name: str(ios_sdk.llvm_tool(llvm, name))) if llvm else _xcrun
    with progress.stage("check"):
        checked = cached / PACK_RECORD if cached else built
        run([sys.executable, str(repo / "scripts/check-game-pack-state.py"),
             tool("llvm-nm"), str(checked), str(executable)] + ([] if cached else ["--record", str(record)]))
    with progress.stage("package"):
        pack = workspace / "libkartpad_game.dylib"
        if cached:
            shutil.copyfile(cached / PACK_FILES["ios"], pack)
        else:
            pack.write_bytes(built.read_bytes())
            run([tool("llvm-strip" if llvm else "strip"), "-x", str(pack)])
            run([tool("llvm-install-name-tool" if llvm else "install_name_tool"),
                 "-id", "@rpath/libkartpad_game.dylib", str(pack)])
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
