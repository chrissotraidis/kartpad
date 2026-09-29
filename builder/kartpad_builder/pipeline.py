from __future__ import annotations

import contextlib
import hashlib
import json
import os
import shutil
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .errors import BuildError
from .packaging import audit_app, load_version, package_unsigned_ipa
from .profiles import Profile, canonical_json, sha256_file
from .retro_rewind import RetroRewindInputs, prepare_inputs


PIPELINE_VERSION = 1


class ProgressLog:
    """Newline-delimited JSON stage events that frontends such as PadForge read.

    Written to `<work-root>/logs/progress.jsonl`. Events describe stages only;
    compiler output stays in the ordinary build log.
    """

    def __init__(self, path: Path | None) -> None:
        self.path = path
        self.started = time.monotonic()

    def emit(self, event: str, stage: str, **fields: Any) -> None:
        if self.path is None:
            return
        self.path.parent.mkdir(parents=True, exist_ok=True)
        record = {"schema_version": 1, "event": event, "stage": stage,
                  "elapsed_seconds": round(time.monotonic() - self.started, 2), **fields}
        with self.path.open("a") as stream:
            stream.write(json.dumps(record) + "\n")

    @contextlib.contextmanager
    def stage(self, name: str):
        self.emit("stage_started", name)
        begun = time.monotonic()
        try:
            yield
        except BaseException as error:
            self.emit("stage_failed", name, stage_elapsed_seconds=round(time.monotonic() - begun, 2),
                      error=type(error).__name__)
            raise
        self.emit("stage_completed", name, stage_elapsed_seconds=round(time.monotonic() - begun, 2))


def source_fingerprint(repo: Path) -> str:
    # Git's parent diff only records a submodule's "dirty" flag. Hash each
    # initialized source repository so two different local edits cannot reuse
    # the same build cache.
    def fingerprint(root: Path) -> bytes:
        tracked = subprocess.check_output(["git", "-C", str(root), "ls-files", "-s", "-z"])
        diff = subprocess.check_output([
            "git", "-C", str(root), "diff", "--binary", "--no-ext-diff",
            "--no-textconv", "--ignore-submodules=none", "HEAD", "--",
        ])
        digest = hashlib.sha256(tracked + b"\0" + diff)
        for record in tracked.split(b"\0"):
            if not record:
                continue
            descriptor, name = record.split(b"\t", 1)
            mode, _, stage = descriptor.split()
            if stage != b"0":
                raise BuildError(f"Unresolved source conflict in {root}: {os.fsdecode(name)}")
            if mode != b"160000":
                continue
            child = root / os.fsdecode(name)
            if not (child / ".git").exists():
                raise BuildError(f"Missing initialized source submodule: {child}; run git submodule update --init --recursive")
            digest.update(name + b"\0" + fingerprint(child))
        return digest.digest()

    return fingerprint(repo).hex()


def cache_key(profile: Profile, image_sha256: str, source_sha256: str) -> str:
    payload = {
        "pipelineVersion": PIPELINE_VERSION,
        "profileSHA256": profile.profile_sha256,
        "imageSHA256": image_sha256,
        "sourceSHA256": source_sha256,
    }
    return hashlib.sha256(canonical_json(payload)).hexdigest()[:20]


def dependency_cache_key(repo: Path, paths: tuple[str, ...]) -> str:
    digest = hashlib.sha256()
    for relative in paths:
        path = repo / relative
        digest.update(relative.encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()[:16]


def run(command: list[str], *, env: dict[str, str] | None = None) -> None:
    printable = " ".join(command)
    print(f"+ {printable}", flush=True)
    completed = subprocess.run(command, env=env)
    if completed.returncode:
        raise BuildError(f"command failed with exit code {completed.returncode}: {printable}")


def _hex(value: int | str) -> str:
    return value if isinstance(value, str) else f"0x{value:08X}"


def write_translator_manifest(
    profile: Profile,
    repo: Path,
    extraction: Path,
    translation: Path,
    path: Path,
    retro: RetroRewindInputs,
    mod_output: Path,
) -> None:
    config = profile.data["translation"]
    executables = profile.data["extraction"]["executables"]
    dol = executables["dol"]
    rel = executables["rel"]
    entry_points = "\n".join(f"    - {_hex(value)}" for value in config["entryPoints"])
    text = f"""schema_version: 1
workspace_root: {repo}

project:
  id: {profile.id}
  display_name: {profile.display_name}
  game_id: {profile.data['game']['discId']}
  region: {profile.data['game']['region']}

memory:
  base: {_hex(config['memoryBase'])}
  size: {_hex(config['memorySize'])}
  sda_base: {_hex(config['sdaBase'])}
  sda2_base: {_hex(config['sda2Base'])}

inputs:
  dol:
    path: {extraction / dol['path']}
    sha256: {dol['sha256']}
  rel:
    path: {extraction / rel['path']}
    load_address: {_hex(rel['loadAddress'])}
    sha256: {rel['sha256']}

translation:
  entry_points:
{entry_points}
  function_map:
    path: {repo / config['functionMap']}
  allow_unsupported_instructions: false

runtime:
  native_registration_root: {repo / 'build/wiicompiled-fpscr/runtime/src'}
  native_abi_directories:
    - {repo / 'build/wiicompiled-fpscr/runtime/src/hle/gx'}

output:
  root: {translation}
  functions: functions
  runtime_config: RuntimeConfig.h
  data_initializer: data_sections_init.cpp
  base_manifest: base/base_manifest.json

profiles:
  retro-rewind:
    enabled: true
    requires_game_id: {profile.data['game']['discId']}
    requires_dol_sha256: {dol['sha256']}
    code_pul: {retro.code_pul}
    mod_root: {retro.root}
    region: {profile.data['game']['region']}
    module_guest_base: 0x81800000
    module_link_base: 0x803992E0
    output: {mod_output}
    enable_retro_wfc: true
    retro_wfc_payload: {retro.payload}
    retro_wfc_legacy_bootstrap_hook: 0x800ED6E8
    riivolution:
      xml: xml/RetroRewind6.xml
      options:
        - section: Retro Rewind
          option: Pack
          choice: 1
"""
    path.write_text(text)


def _validate_extraction(profile: Profile, root: Path) -> None:
    extraction = profile.data["extraction"]
    for relative in extraction["requiredFiles"]:
        if not (root / relative).is_file():
            raise BuildError(f"extraction is missing {relative}")
    boot = (root / "sys/boot.bin").read_bytes()[:28]
    game = profile.data["game"]
    expected_header = game["discId"].encode() + bytes([game["discNumber"], game["revision"]])
    if boot[:8] != expected_header or boot[24:28].hex() != game["wiiMagic"].lower():
        raise BuildError("extracted disc identity does not match the selected profile")
    for name, executable in extraction["executables"].items():
        actual = sha256_file(root / executable["path"])
        if actual != executable["sha256"]:
            raise BuildError(f"extracted {name} does not match the selected profile")


def extract(profile: Profile, image: Path, output: Path) -> None:
    if output.is_dir():
        _validate_extraction(profile, output)
        print(f"Reused validated extraction: {output}")
        return
    if output.exists():
        raise BuildError(f"extraction output exists and is not a directory: {output}")
    extractor = profile.data["extraction"]["extractor"]
    executable = shutil.which(extractor["command"])
    if not executable:
        raise BuildError(f"missing {extractor['command']} {extractor['version']}")
    version = subprocess.check_output([executable, "--version"], text=True).strip()
    if version != f"{extractor['command']} {extractor['version']}":
        raise BuildError(f"expected {extractor['command']} {extractor['version']}, found {version}")
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = output.with_name(output.name + f".partial.{os.getpid()}")
    if stage.exists():
        shutil.rmtree(stage)
    try:
        run([executable, "extract", "--quiet", str(image), str(stage)])
        _validate_extraction(profile, stage)
        manifest = {
            "schemaVersion": 1,
            "profileId": profile.id,
            "profileSHA256": profile.profile_sha256,
            "imageSHA256": sha256_file(image),
            "executables": profile.data["extraction"]["executables"],
            "extractor": version,
        }
        (stage / "kartpad-disc-manifest.json").write_bytes(canonical_json(manifest))
        stage.rename(output)
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def translate(
    profile: Profile,
    repo: Path,
    extraction: Path,
    output: Path,
    jobs: int,
    retro: RetroRewindInputs,
) -> None:
    shards = output / "build_shards/shards.cmake"
    expected_generated = profile.data["translation"]["expectedGeneratedFunctions"]
    expected_base = profile.data["translation"]["expectedBaseFunctions"]
    expected_retro = profile.data["translation"]["expectedRetroFunctions"]
    if shards.is_file():
        count = len(list((output / "functions").glob("func_*.cpp")))
        graph = shards.read_text()
        if (
            count != expected_generated
            or f"set(MKW_BASE_FUNCTION_COUNT {expected_base})" not in graph
            or f"set(MKW_RETRO_REWIND_FUNCTION_COUNT {expected_retro})" not in graph
            or "set(MKW_HAVE_RETRO_REWIND_SHARDS ON)" not in graph
        ):
            raise BuildError("cached translation failed profile validation")
        guard = repo / "scripts/inject-retro-rel-report-guard.py"
        run([str(guard), "--verify", str(output / "functions" / "func_8000A440.cpp")])
        run([str(guard), "--verify-shards", str(output / "build_shards")])
        print(f"Reused validated translation: {output}")
        return
    run([str(repo / "scripts/prepare-patched-translator.sh")])
    output.mkdir(parents=True, exist_ok=True)
    mod_output = output.parent / "mod"
    manifest = output / "kartpad-builder-profile.yml"
    write_translator_manifest(profile, repo, extraction, output, manifest, retro, mod_output)
    translator = repo / "build/wiicompiled-fpscr/translator/src/Translator.Cli/bin/Release/net8.0/Translator.Cli.dll"
    dotnet = shutil.which("dotnet") or "/opt/homebrew/opt/dotnet@8/bin/dotnet"
    config = profile.data["translation"]
    metadata = output / "base_translation_output.json"
    entry = _hex(config["entryPoints"][0])
    run([dotnet, str(translator), "translate-recursive", entry, "--project", str(manifest), "--profile", "retro-rewind", "--threads", str(jobs), "--prune-stale", "--output-metadata", str(metadata)])
    for injector in config["injectors"]:
        run([str(repo / injector["script"]), str(output / "functions" / injector["function"])])
    base_manifest = output / "base/base_manifest.json"
    run([dotnet, str(translator), "emit-base-manifest", "--project", str(manifest), "--profile", "retro-rewind", "--out", str(base_manifest.parent), "--functions-dir", str(output / "functions"), "--translation-output-metadata", str(metadata), "--region", profile.data["game"]["region"]])
    run([dotnet, str(translator), "translate-mod", "--project", str(manifest), "--profile", "retro-rewind", "--base-manifest", str(base_manifest), "--base-translation-output-metadata", str(metadata), "--code-pul", str(retro.code_pul), "--mod-root", str(retro.root), "--mod-name", "Retro Rewind", "--region", profile.data["game"]["region"], "--out", str(mod_output), "--prefer-cached-inputs", "--emit-cpp", "--threads", str(jobs), "--retro-wfc-payload", str(retro.payload)])
    run([dotnet, str(translator), "generate-data-init", "--project", str(manifest), "--profile", "retro-rewind"])
    blob = output / "data_sections_init_blobs.S"
    if ".globl _kData_" not in blob.read_text():
        run(["perl", "-0pi", "-e", r"s/^\.globl (kData_[^\n]+)\n\1:/.globl $1\n.globl _$1\n$1:\n_$1:/mg", str(blob)])
    mod_blob = mod_output / "cpp/mod_data_patches_blobs.S"
    if mod_blob.is_file() and ".globl _k" not in mod_blob.read_text():
        run(["perl", "-0pi", "-e", r"s/^\.globl (k[^\n]+)\n\1:/.globl $1\n.globl _$1\n$1:\n_$1:/mg", str(mod_blob)])
    run([dotnet, str(translator), "emit-build-shards", "--project", str(manifest), "--profile", "retro-rewind", "--base-metadata", str(metadata), "--base-functions-dir", str(output / "functions"), "--native-source-dir", str(repo / "build/wiicompiled-fpscr/runtime/src"), "--resolved-profile", str(mod_output / "resolved_dispatch_profile.json"), "--retro-cpp-dir", str(mod_output / "cpp"), "--out", str(output / "build_shards")])
    guard = repo / "scripts/inject-retro-rel-report-guard.py"
    run([str(guard), "--inject-shards", str(output / "build_shards")])
    run([str(guard), "--verify", str(output / "functions" / "func_8000A440.cpp")])
    run([str(guard), "--verify-shards", str(output / "build_shards")])
    count = len(list((output / "functions").glob("func_*.cpp")))
    graph = shards.read_text()
    if (
        count != expected_generated
        or f"set(MKW_BASE_FUNCTION_COUNT {expected_base})" not in graph
        or f"set(MKW_RETRO_REWIND_FUNCTION_COUNT {expected_retro})" not in graph
        or "set(MKW_HAVE_RETRO_REWIND_SHARDS ON)" not in graph
    ):
        raise BuildError("new translation failed profile validation")


@dataclass
class BuildResult:
    ipa: Path
    ipa_sha256: str
    app: Path
    cache_key: str


def build(
    repo: Path,
    profile: Profile,
    image: Path,
    image_sha256: str,
    output: Path,
    work_root: Path,
    jobs: int = 2,
    translation_override: Path | None = None,
    app_override: Path | None = None,
) -> BuildResult:
    fingerprint = source_fingerprint(repo)
    key = cache_key(profile, image_sha256, fingerprint)
    profile_root = work_root / profile.id
    workspace = profile_root / "builds" / key
    extraction = profile_root / "inputs" / image_sha256 / "disc"
    translation = translation_override or workspace / "translation"
    progress = ProgressLog(work_root / "logs/progress.jsonl")
    with progress.stage("preflight"):
        # Bootstrap downloads pinned inputs to the checkout's shared cache; builds in
        # any --work-root read them from there rather than expecting a second copy.
        retro = prepare_inputs(profile, repo / "private/builder", install=False)
    if app_override is None:
        with progress.stage("extract"):
            extract(profile, image, extraction)
        if translation_override is None:
            with progress.stage("translate"):
                translate(profile, repo, extraction, translation, jobs, retro)
        else:
            progress.emit("stage_skipped", "translate", reason="translation override supplied")
        runtime_source = workspace / "ios-runtime-source"
        xcode_build = workspace / "ios-device-xcode"
        discio_key = dependency_cache_key(
            repo,
            (
                "scripts/build-ios-discio-probe.sh",
                "patches/dolphin-ios-discio.patch",
                "patches/dolphin-ios-discio-coreless.patch",
                "patches/dolphin-curl-ios-pipe2.patch",
            ),
        )
        discio_source = repo / f"build/builder-dependencies/discio-iphoneos-{discio_key}-source"
        discio_build = repo / f"build/builder-dependencies/discio-iphoneos-{discio_key}-build"
        with progress.stage("dependencies"):
            if not (discio_build / "Source/Core/DiscIO/libdiscio.a").is_file():
                run([str(repo / "scripts/build-ios-discio-probe.sh"), str(repo / "ref/upstream/dolphin"), str(discio_source), str(discio_build), "iphoneos"])
        with progress.stage("generate"):
            if not runtime_source.exists():
                runtime_stage = runtime_source.with_name(runtime_source.name + ".partial")
                if runtime_stage.exists():
                    shutil.rmtree(runtime_stage)
                env = os.environ.copy()
                env["KARTPAD_PREPARE_ONLY"] = "1"
                env["KARTPAD_DISCIO_SOURCE_DIR"] = str(discio_source)
                env["KARTPAD_DISCIO_BUILD_DIR"] = str(discio_build)
                try:
                    run([str(repo / "scripts/prepare-ios-game-runtime.sh"), str(translation), str(runtime_stage), str(workspace / "runtime-build"), "dual"], env=env)
                    runtime_stage.rename(runtime_source)
                except Exception:
                    if runtime_stage.exists():
                        shutil.rmtree(runtime_stage)
                    raise
        with progress.stage("compile"):
            env = os.environ.copy()
            env["KARTPAD_DISCIO_SOURCE_DIR"] = str(discio_source)
            env["KARTPAD_DISCIO_BUILD_DIR"] = str(discio_build)
            run([str(repo / "scripts/build-ios-device-game-app.sh"), str(runtime_source), str(xcode_build), str(translation), "dual"], env=env)
        app = xcode_build / "Release-iphoneos/KartPad.app"
    else:
        for skipped in ("extract", "translate", "dependencies", "generate", "compile"):
            progress.emit("stage_skipped", skipped, reason="prebuilt app override supplied")
        app = app_override
    with progress.stage("package"):
        return _package(repo, profile, image_sha256, output, fingerprint, key, app, workspace)


def _package(repo: Path, profile: Profile, image_sha256: str, output: Path, fingerprint: str,
             key: str, app: Path, workspace: Path) -> BuildResult:
    audit_app(app, (str(repo), str(Path.home()), str(workspace)))
    version = load_version(repo)
    provenance = {
        "schemaVersion": 1,
        "builderVersion": "0.2.0-preview.3",
        "appVersion": version["version"],
        "appBuild": version["build"],
        "pipelineVersion": PIPELINE_VERSION,
        "profileId": profile.id,
        "profileSHA256": profile.profile_sha256,
        "imageSHA256": image_sha256,
        "sourceSHA256": fingerprint,
        "cacheKey": key,
        "containsUserSuppliedTranslatedCode": True,
        "softwareLicense": "GPL-3.0-only",
        "gameCodeRedistributionRights": "not-cleared",
    }
    license_entries = {
        name: repo / name
        for name in ("LICENSE", "RIGHTS_AND_LICENSES.md", "THIRD_PARTY_NOTICES.md")
    }
    digest = package_unsigned_ipa(app, output, provenance, license_entries, version)
    return BuildResult(ipa=output, ipa_sha256=digest, app=app, cache_key=key)
