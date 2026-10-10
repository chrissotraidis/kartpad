from __future__ import annotations

import hashlib
import json
import os
import platform
import shutil
import subprocess
import urllib.request
from pathlib import Path
from typing import Any

from .pipeline import BuildError, run
from .profiles import Profile


REQUIRED_COMMANDS = {
    "ios": ("cmake", "ninja", "git", "rg", "python3", "dotnet", "nodtool", "xcrun"),
    # PadMint's Mac app recipe: PadMint supplies dotnet, cmake, ninja and nodtool;
    # Xcode supplies git, python3 and xcrun. No Homebrew tools are required.
    "macos": ("cmake", "ninja", "git", "python3", "dotnet", "nodtool", "xcrun"),
    # The game pack builds on Windows, Linux and macOS (PadMint supplies the tools).
    "android-pack": ("cmake", "ninja", "git", "dotnet", "nodtool"),
    "ios-pack": ("cmake", "ninja", "git", "dotnet", "nodtool", "xcrun"),
}
# Source checkouts each target reads; the iPhone build uses the profile's full list.
ANDROID_PACK_SOURCES = ("WiiCompiled",)
TRANSLATOR_GITLINK = "vendor/wiicompiled"
ANDROID_PACK_GITLINKS = ("vendor/runtimes/android", TRANSLATOR_GITLINK)
PACK_GITLINKS = {"android-pack": ANDROID_PACK_GITLINKS,
                 "ios-pack": ("vendor/runtimes/ios", TRANSLATOR_GITLINK)}


def load_lock(repo: Path) -> dict[str, Any]:
    lock = json.loads((repo / "dependencies.lock.json").read_text())
    if lock.get("schemaVersion") != 1 or not isinstance(lock.get("dependencies"), list):
        raise BuildError("dependencies.lock.json has an unsupported schema")
    return lock


def _dependency_map(lock: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {dependency["name"]: dependency for dependency in lock["dependencies"]}


def _verify_checkout(repo: Path, dependency: dict[str, Any]) -> None:
    path = repo / dependency["path"]
    if not (path / ".git").exists():
        raise BuildError(f"missing pinned source {dependency['name']}: {path}")
    head = subprocess.run(["git", "-C", str(path), "rev-parse", "HEAD^{commit}"],
                          capture_output=True, text=True)
    if head.returncode != 0:
        raise BuildError(
            f"{dependency['name']} checkout at {path} is incomplete (for example after an "
            "interrupted bootstrap). Move that folder aside and run "
            "./scripts/build-user-ipa.sh bootstrap again; nothing was changed.")
    commit = head.stdout.strip()
    tree = subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD^{tree}"], text=True).strip()
    if commit != dependency["commit"] or tree != dependency["tree"]:
        raise BuildError(f"{dependency['name']} does not match dependencies.lock.json")
    if subprocess.check_output(["git", "-C", str(path), "status", "--porcelain"], text=True):
        raise BuildError(f"{dependency['name']} source must be clean")


def _prepare_runtime_sources(repo: Path, dependency: dict[str, Any], install: bool) -> None:
    _prepare_gitlinks(repo, list(dependency["platformPaths"].values()), install)


def _prepare_gitlinks(repo: Path, relatives: list[str], install: bool) -> None:
    for relative in relatives:
        path = repo / relative
        tracked = subprocess.check_output([
            "git", "-C", str(repo), "ls-files", "--stage", "-z", "--", relative,
        ]).split(b"\0")
        records = [record for record in tracked if record]
        if len(records) != 1:
            raise BuildError(f"Missing or unresolved runtime gitlink: {relative}")
        descriptor, name = records[0].split(b"\t", 1)
        mode, expected, stage = descriptor.split()
        if mode != b"160000" or stage != b"0" or os.fsdecode(name) != relative:
            raise BuildError(f"Missing or unresolved runtime gitlink: {relative}")
        if not (path / ".git").exists():
            if not install:
                raise BuildError(f"missing runtime source {relative}; run ./scripts/build-user-ipa.sh bootstrap")
            if path.exists() and any(path.iterdir()):
                raise BuildError(f"Refusing to replace existing runtime files: {path}")
            run(["git", "-C", str(repo), "submodule", "update", "--init", "--recursive", "--", relative])
        actual = subprocess.check_output([
            "git", "-C", str(path), "rev-parse", "HEAD^{commit}",
        ]).strip()
        if actual != expected:
            raise BuildError(f"Runtime source {relative} does not match its staged gitlink; existing checkout was preserved")
        # Local tracked edits are intentional build inputs, hashed by the pipeline.
        # Never reset an initialized checkout or require the maintained source clean.


def _download(url: str, expected_sha256: str, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_name(output.name + ".partial")
    digest = hashlib.sha256()
    try:
        with urllib.request.urlopen(url) as response, partial.open("wb") as handle:
            while chunk := response.read(1024 * 1024):
                digest.update(chunk)
                handle.write(chunk)
        if digest.hexdigest() != expected_sha256:
            raise BuildError(f"downloaded artifact hash mismatch: {output.name}")
        os.replace(partial, output)
    finally:
        if partial.exists():
            partial.unlink()


def _has_command(command: str) -> bool:
    if command == "dotnet":
        from .pipeline import find_dotnet
        try:
            find_dotnet()
            return True
        except BuildError:
            return False
    return shutil.which(command) is not None


def prepare_dependencies(repo: Path, profile: Profile, install: bool, target: str = "ios") -> list[str]:
    commands = REQUIRED_COMMANDS[target]
    if target == "ios-pack" and platform.system() != "Darwin":
        # Off a Mac, PadMint's LLVM and open-source iOS headers take Xcode's place.
        commands = tuple(command for command in commands if command != "xcrun")
    missing_commands = [command for command in commands if not _has_command(command)]
    if missing_commands:
        raise BuildError(f"missing required commands: {', '.join(missing_commands)}")
    lock = load_lock(repo)
    dependencies = _dependency_map(lock)
    if target in PACK_GITLINKS:
        _prepare_gitlinks(repo, list(PACK_GITLINKS[target]), install)
        required = list(ANDROID_PACK_SOURCES)
    else:
        runtime = dependencies.get("KartPad WiiCompiled runtime fork")
        if runtime is not None:
            _prepare_runtime_sources(repo, runtime, install)
            # The translate stage (scripts/stage-maintained-translator.py) reads
            # this gitlink, so a clean Mac or IPA build needs it like the packs do.
            _prepare_gitlinks(repo, [TRANSLATOR_GITLINK], install)
        required = profile.data["sourceDependencies"]
    for name in required:
        if name not in dependencies:
            raise BuildError(f"profile names an unknown dependency: {name}")
        dependency = dependencies[name]
        path = repo / dependency["path"]
        if not (path / ".git").exists():
            if not install:
                raise BuildError(f"missing {name}; run ./scripts/build-user-ipa.sh bootstrap")
            path.parent.mkdir(parents=True, exist_ok=True)
            run(["git", "clone", "--recurse-submodules", dependency["repository"], str(path)])
            run(["git", "-C", str(path), "checkout", "--detach", dependency["commit"]])
            run(["git", "-C", str(path), "submodule", "update", "--init", "--recursive"])
            run(["git", "-C", str(path), "remote", "set-url", "--push", "origin", "DISABLED"])
        _verify_checkout(repo, dependency)

    if target in PACK_GITLINKS:
        from .retro_rewind import prepare_inputs

        inputs = prepare_inputs(profile, repo / "private/builder", install)
        return required + [f"Retro Rewind {inputs.version}", "Retro-WFC production payload"]
    dawn = dependencies["Dawn prebuilt"]
    dawn_output = repo / "build/dependency-cache" / f"dawn-ios-arm64-{dawn['version']}.tar.gz"
    if not dawn_output.is_file() or hashlib.sha256(dawn_output.read_bytes()).hexdigest() != dawn["iosArm64Sha256"]:
        if not install:
            raise BuildError("missing pinned physical-iOS Dawn archive; run ./scripts/build-user-ipa.sh bootstrap")
        _download(dawn["iosArm64Url"], dawn["iosArm64Sha256"], dawn_output)
    # The Mac app build (scripts/prepare-g7-game-runtime.sh) reads this archive
    # but nothing fetched it, so fresh clones could not build the Mac app.
    mac_output = repo / "build/dependency-cache" / f"dawn-darwin-arm64-{dawn['version']}.tar.gz"
    if install and (not mac_output.is_file()
                    or hashlib.sha256(mac_output.read_bytes()).hexdigest() != dawn["darwinArm64Sha256"]):
        mac_url = f"{dawn['repository']}/releases/download/{dawn['version']}/{dawn['darwinArm64Artifact']}"
        _download(mac_url, dawn["darwinArm64Sha256"], mac_output)
    if "retroRewind" in profile.data:
        from .retro_rewind import prepare_inputs

        inputs = prepare_inputs(profile, repo / "private/builder", install)
        return required + [f"Retro Rewind {inputs.version}", "Retro-WFC production payload"]
    return required
