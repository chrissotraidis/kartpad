#!/usr/bin/env python3
"""Update KartPad's Retro Rewind pins from the official full archive and optional update."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROFILE = ROOT / "builder/profiles/mkwii-rmcp01-rev0.json"
VERSION_PATTERN = re.compile(r"^[0-9]+(?:\.[0-9]+){1,3}$")
VERSION_FEED = "https://update.rwfc.net/RetroRewind/RetroRewindVersion.txt"


def member_digest(bundle: zipfile.ZipFile, name: str) -> tuple[int, str]:
    info = bundle.getinfo(name)
    digest = hashlib.sha256()
    with bundle.open(info) as source:
        while chunk := source.read(1024 * 1024):
            digest.update(chunk)
    return info.file_size, digest.hexdigest()


def version_key(version: str) -> tuple[int, ...]:
    if not VERSION_PATTERN.fullmatch(version):
        raise ValueError(f"invalid Retro Rewind version: {version!r}")
    return tuple(int(part) for part in version.split("."))


def read_manifest(name: str) -> str:
    url = VERSION_FEED.replace("RetroRewindVersion.txt", name)
    request = urllib.request.Request(url, headers={"User-Agent": "KartPad-Retro-Rewind-Updater/1"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def latest_version() -> str:
    lines = read_manifest("RetroRewindVersion.txt").splitlines()
    versions = [line.split()[0] for line in lines if line.strip()]
    if not versions:
        raise ValueError("official Retro Rewind feed is empty")
    for version in versions:
        version_key(version)
    return max(versions, key=version_key)


def download(url: str, output: Path) -> None:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.netloc != "cdn.update.rwfc.net":
        raise ValueError("archive URL must use the official HTTPS Retro Rewind CDN")
    if output.is_file() and zipfile.is_zipfile(output):
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_suffix(output.suffix + ".partial")
    start = partial.stat().st_size if partial.is_file() else 0
    headers = {"User-Agent": "KartPad-Retro-Rewind-Updater/1"}
    if start:
        headers["Range"] = f"bytes={start}-"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        if start and response.status != 206:
            start = 0
        mode = "ab" if start else "wb"
        with partial.open(mode) as target:
            while chunk := response.read(1024 * 1024):
                target.write(chunk)
    os.replace(partial, output)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Pin an official Retro Rewind full ZIP without weakening checks."
    )
    parser.add_argument("archive", type=Path, nargs="?")
    parser.add_argument("archive_url", nargs="?")
    parser.add_argument(
        "--latest",
        action="store_true",
        help="pin the official full pack and its required update",
    )
    parser.add_argument(
        "--download-dir",
        type=Path,
        default=ROOT / "private/builder/retro-rewind-downloads",
    )
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    parser.add_argument("--update-archive", type=Path)
    parser.add_argument("--update-url")
    args = parser.parse_args()

    expected_version = None
    if args.latest:
        if any((args.archive, args.archive_url, args.update_archive, args.update_url)):
            parser.error("--latest does not accept archive arguments")
        try:
            version = latest_version()
            expected_version = version
        except (OSError, UnicodeError, ValueError) as exc:
            parser.error(str(exc))
        args.archive_url = read_manifest("RetroRewindInstall.txt").strip()
        args.archive = args.download_dir / Path(urllib.parse.urlparse(args.archive_url).path).name
        try:
            download(args.archive_url, args.archive)
        except OSError as exc:
            parser.error(f"download failed: {exc}")
        with zipfile.ZipFile(args.archive) as bundle:
            base_version = bundle.read("RetroRewind6/version.txt").decode().strip()
        if base_version != version:
            pending = [line.split() for line in read_manifest("RetroRewindVersion.txt").splitlines()
                       if line.strip() and version_key(line.split()[0]) > version_key(base_version)]
            if len(pending) != 1 or pending[0][0] != version:
                parser.error("full pack requires multiple updates; review the update chain before pinning")
            for line in read_manifest("RetroRewindDelete.txt").splitlines():
                fields = line.split()
                if len(fields) >= 2 and version_key(base_version) < version_key(fields[0]) <= version_key(version):
                    if fields[1].rstrip("/") == "/RetroRewind6" or fields[1].startswith("/RetroRewind6/"):
                        parser.error("update requires content deletions; review before pinning")
            args.update_url = pending[0][1]
            args.update_archive = args.download_dir / Path(urllib.parse.urlparse(args.update_url).path).name
            download(args.update_url, args.update_archive)
    elif args.archive is None or args.archive_url is None:
        parser.error("provide ARCHIVE OFFICIAL_URL or use --latest")

    archive = args.archive.resolve()
    parsed = urllib.parse.urlparse(args.archive_url)
    if parsed.scheme != "https" or parsed.netloc != "cdn.update.rwfc.net":
        parser.error("archive URL must use the official HTTPS Retro Rewind CDN")
    if not archive.is_file() or not zipfile.is_zipfile(archive):
        parser.error("archive must be a readable ZIP")

    profile = json.loads(args.profile.read_text())
    config = profile["retroRewind"]
    root = config["root"]
    version_path = f"{root}/version.txt"
    code_path = f"{root}/{config['codePul']['path']}"
    xml_path = f"{root}/{config['riivolutionXml']['path']}"
    with zipfile.ZipFile(archive) as bundle:
        version = bundle.read(version_path).decode("utf-8").strip()
        if not VERSION_PATTERN.fullmatch(version):
            parser.error("archive contains an invalid Retro Rewind version")
        code_bytes, code_hash = member_digest(bundle, code_path)
        xml_bytes, xml_hash = member_digest(bundle, xml_path)

    update_pin = None
    if bool(args.update_archive) != bool(args.update_url):
        parser.error("--update-archive and --update-url are required together")
    if args.update_archive:
        parsed_update = urllib.parse.urlparse(args.update_url)
        if parsed_update.scheme != "https" or parsed_update.netloc != "cdn.update.rwfc.net":
            parser.error("update URL must use the official HTTPS Retro Rewind CDN")
        with zipfile.ZipFile(args.update_archive) as update:
            next_version = update.read(version_path).decode().strip()
            if version_key(next_version) <= version_key(version):
                parser.error("update must advance the base version")
            version = next_version
            if code_path in update.namelist():
                code_bytes, code_hash = member_digest(update, code_path)
            if xml_path in update.namelist():
                xml_bytes, xml_hash = member_digest(update, xml_path)
            expanded = sum(i.file_size for i in update.infolist() if i.filename.startswith(root + "/"))
        update_hash = hashlib.sha256()
        with args.update_archive.open("rb") as handle:
            while chunk := handle.read(1024 * 1024):
                update_hash.update(chunk)
        digest = update_hash.hexdigest()
        update_pin = dict(url=args.update_url, bytes=args.update_archive.stat().st_size,
                          sha256=digest, maximumExpandedBytes=((expanded // 1000000) + 1) * 1000000)

    archive_hash = hashlib.sha256()
    with archive.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            archive_hash.update(chunk)

    if expected_version is not None and version != expected_version:
        parser.error("downloaded pack version differs from the official version feed")
    config["version"] = version
    if update_pin:
        config["updateArchive"] = update_pin
    else:
        config.pop("updateArchive", None)
    config["archive"].update(
        url=args.archive_url,
        bytes=archive.stat().st_size,
        sha256=archive_hash.hexdigest(),
    )
    config["codePul"].update(bytes=code_bytes, sha256=code_hash)
    config["riivolutionXml"].update(bytes=xml_bytes, sha256=xml_hash)
    args.profile.write_text(json.dumps(profile, indent=2) + "\n")
    print(f"Pinned Retro Rewind {version}")
    print(f"archive {archive.stat().st_size} {archive_hash.hexdigest()}")
    print(f"Code.pul {code_bytes} {code_hash}")
    print(f"XML {xml_bytes} {xml_hash}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
