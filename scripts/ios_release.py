"""Exact clean full-build identity for the 0.5.2 iOS candidate; not publication approval."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import subprocess

RECORD = json.loads((Path(__file__).resolve().parents[1] / "docs/releases/v0.5.2-ios-build.json").read_text())
RELEASE_TAG = RECORD["releaseTag"]
APP_VERSION = RECORD["appVersion"]
APP_BUILD = RECORD["appBuild"]
COMPILED_SOURCE = RECORD["buildManifest"]["source_revision"]
EXECUTABLE_SHA256 = RECORD["executableSHA256"]
RUNTIME_SHA256 = RECORD["buildManifest"]["prepared_runtime"]["sha256"]
TRANSLATION_SHA256 = RECORD["buildManifest"]["translation"]["sha256"]


def accepted_build(app: Path) -> dict:
    manifest_bytes = (app / "kartpad-build.json").read_bytes()
    manifest = json.loads(manifest_bytes)
    if manifest != RECORD["buildManifest"] or manifest.get("source_dirty") is not False:
        raise ValueError("app does not identify the exact clean audited full build")
    if hashlib.sha256((app / "KartPad").read_bytes()).hexdigest() != EXECUTABLE_SHA256:
        raise ValueError("app executable differs from the audited build")
    return {
        "compiledBaseSourceCommit": COMPILED_SOURCE,
        "preparedRuntimeSHA256": RUNTIME_SHA256,
        "translationSHA256": TRANSLATION_SHA256,
        "compilationManifestSHA256": hashlib.sha256(manifest_bytes).hexdigest(),
        "compilationScope": "full clean source build",
        "fullSourceRebuild": True,
    }


def verify_source_equivalence(repo: Path, packaging_commit: str) -> None:
    changed = subprocess.check_output(
        ["git", "-C", str(repo), "diff", "--name-only", COMPILED_SOURCE, packaging_commit], text=True
    ).splitlines()
    packaging = {
        "scripts/ios_release.py", "scripts/package-public-unsigned-ipa.py",
        "scripts/audit-public-unsigned-ipa.py", "scripts/package-android-release-notices.py",
        "tests/test_ios_release_provenance.py", "tests/test_android_public_release_contract.py",
        "scripts/package-public-macos.py", "scripts/audit-public-macos.py",
        "tests/test_macos_dual_mode_contract.py",
    }
    if any(not p.startswith("docs/") and p not in packaging for p in changed):
        raise ValueError("packaging commit changes inputs beyond documentation and release packaging")
