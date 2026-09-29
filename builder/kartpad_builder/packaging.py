from __future__ import annotations

import hashlib
import json
import os
import plistlib
import stat
import zipfile
from pathlib import Path
from typing import Any


class PackageError(ValueError):
    pass


ZIP_TIMESTAMP = (2020, 1, 1, 0, 0, 0)
FORBIDDEN_SUFFIXES = {".iso", ".wbfs", ".rvz", ".wia", ".gcz", ".gcm", ".ciso"}
FORBIDDEN_NAMES = {"embedded.mobileprovision", "rksys.dat", "_CodeSignature"}


def _walk_files(root: Path) -> list[Path]:
    return sorted((path for path in root.rglob("*") if path.is_file()), key=lambda p: p.as_posix())


def load_version(repo: Path) -> dict[str, Any]:
    """Read the single KartPad version (version.json) shared by every platform."""
    data = json.loads((repo / "version.json").read_text())
    version, build = data.get("version"), data.get("build")
    if not isinstance(version, str) or not version or not isinstance(build, int) or build < 1:
        raise PackageError("version.json needs a version string and a positive integer build")
    return {"version": version, "build": build}


def _stamped_plist(path: Path, version: dict[str, Any]) -> bytes:
    with path.open("rb") as handle:
        raw = handle.read()
    plist = plistlib.loads(raw)
    plist["CFBundleShortVersionString"] = version["version"]
    plist["CFBundleVersion"] = str(version["build"])
    binary = raw.startswith(b"bplist")
    return plistlib.dumps(plist, fmt=plistlib.FMT_BINARY if binary else plistlib.FMT_XML)


def audit_app(app: Path, private_prefixes: tuple[str, ...] = ()) -> dict[str, Any]:
    if not app.is_dir() or app.suffix != ".app":
        raise PackageError(f"not an app bundle: {app}")
    plist_path = app / "Info.plist"
    if not plist_path.is_file():
        raise PackageError("app is missing Info.plist")
    with plist_path.open("rb") as handle:
        plist = plistlib.load(handle)
    executable_name = plist.get("CFBundleExecutable")
    if not executable_name or not (app / executable_name).is_file():
        raise PackageError("app is missing its declared executable")
    files = _walk_files(app)
    for path in app.rglob("*"):
        if path.name in FORBIDDEN_NAMES or path.suffix.lower() in FORBIDDEN_SUFFIXES:
            raise PackageError(f"app contains forbidden private/signing data: {path.relative_to(app)}")
    executable = app / executable_name
    data = executable.read_bytes()
    for prefix in private_prefixes:
        if prefix and prefix.encode() in data:
            raise PackageError(f"app executable exposes private build path: {prefix}")
    return {
        "bundleIdentifier": plist.get("CFBundleIdentifier"),
        "executable": executable_name,
        "fileCount": len(files),
        "executableSHA256": hashlib.sha256(data).hexdigest(),
    }


def package_unsigned_ipa(
    app: Path,
    output: Path,
    provenance: dict[str, Any],
    additional_entries: dict[str, Path] | None = None,
    version: dict[str, Any] | None = None,
) -> str:
    audit_app(app)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(output.name + ".partial")
    if temporary.exists():
        temporary.unlink()
    entries: list[tuple[str, bytes, int]] = []
    app_root = f"Payload/{app.name}"
    for path in _walk_files(app):
        relative = path.relative_to(app).as_posix()
        mode = stat.S_IMODE(path.stat().st_mode)
        data = _stamped_plist(path, version) if version and relative == "Info.plist" else path.read_bytes()
        entries.append((f"{app_root}/{relative}", data, mode))
    for name, path in sorted((additional_entries or {}).items()):
        parts = Path(name).parts
        if not name or name.startswith("/") or ".." in parts or not path.is_file():
            raise PackageError(f"invalid additional package entry: {name}")
        entries.append((name, path.read_bytes(), stat.S_IMODE(path.stat().st_mode)))
    entries.append(
        (
            "KartPadBuilderProvenance.json",
            (json.dumps(provenance, indent=2, sort_keys=True) + "\n").encode(),
            0o644,
        )
    )
    with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data, mode in sorted(entries):
            info = zipfile.ZipInfo(name, ZIP_TIMESTAMP)
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data, compresslevel=9)
    os.replace(temporary, output)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise PackageError("IPA ZIP integrity check failed")
        names = archive.namelist()
        if not any(name == f"{app_root}/Info.plist" for name in names):
            raise PackageError("IPA is missing the app Info.plist")
    return digest
