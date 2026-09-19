from __future__ import annotations

import hashlib
import hmac
import os
import shutil
import stat
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any

from .errors import BuildError
from .profiles import Profile, sha256_file


RWFC_SIGNING_MODULUS = int(
    "e6e6ce416f350422cbe26c36a67eba613dddcd27d79afd077dcc593e5319eaa6"
    "080293400033876d3dbdfda12c15f46ac8e4f5b40c56e7b5f67e91647d618cb9"
    "99c041581b86d103bd7723fceac03ad3ad5134bf611cd47dc527002596821e94"
    "1c9470938fea07238a84767323e4a610bd996465e59d04dae4febd915c96fc07"
    "39e4e818300829d78f3f2275e1f3fbd2507f1bde74f24a5285e61007b959a583"
    "b4820d75eca76680866efe5d79590b82c3577b796155899530e305b94b4ceef4"
    "428644b719df3d8540c9588f5bb02d83d3938255d1a1e073d3408163ff93a615"
    "a2106a03923a397aad6a29ebb43031ed06de1575c8ee2b54678fa059e025f455",
    16,
)
RWFC_SIGNING_EXPONENT = 65537
RWFC_SIGNED_REGION_OFFSET = 0x110
RWFC_SIGNATURE_OFFSET = 0x10
RWFC_MAX_BYTES = 16 * 1024 * 1024
SHA256_DIGEST_INFO_PREFIX = bytes.fromhex("3031300d060960864801650304020105000420")


@dataclass(frozen=True)
class RetroRewindInputs:
    root: Path
    code_pul: Path
    payload: Path
    version: str


def _require_digest(value: Any, location: str) -> str:
    if not isinstance(value, str) or len(value) != 64:
        raise BuildError(f"{location} must be a 64-character SHA-256")
    try:
        bytes.fromhex(value)
    except ValueError as exc:
        raise BuildError(f"{location} is not hexadecimal") from exc
    return value.lower()


def validate_config(config: dict[str, Any], location: str = "retroRewind") -> None:
    if not isinstance(config, dict):
        raise BuildError(f"{location} must be an object")
    for key in (
        "version",
        "versionManifestUrl",
        "archive",
        "root",
        "codePul",
        "riivolutionXml",
        "payload",
    ):
        if key not in config:
            raise BuildError(f"{location} is missing {key}")
    if not isinstance(config["version"], str) or not config["version"]:
        raise BuildError(f"{location}.version must be a non-empty string")
    manifest_url = config["versionManifestUrl"]
    if not isinstance(manifest_url, str):
        raise BuildError(
            f"{location}.versionManifestUrl must be the official HTTPS Retro Rewind version feed"
        )
    parsed_manifest_url = urllib.parse.urlparse(manifest_url)
    if (
        parsed_manifest_url.scheme != "https"
        or parsed_manifest_url.netloc != "update.rwfc.net"
        or not parsed_manifest_url.path.endswith("/RetroRewindVersion.txt")
    ):
        raise BuildError(
            f"{location}.versionManifestUrl must be the official HTTPS Retro Rewind version feed"
        )
    archive = config["archive"]
    if not isinstance(archive, dict) or not isinstance(archive.get("url"), str):
        raise BuildError(f"{location}.archive must define url")
    _require_digest(archive.get("sha256"), f"{location}.archive.sha256")
    if not isinstance(archive.get("bytes"), int) or archive["bytes"] <= 0:
        raise BuildError(f"{location}.archive.bytes must be positive")
    if not isinstance(archive.get("maximumExpandedBytes"), int) or archive["maximumExpandedBytes"] <= 0:
        raise BuildError(f"{location}.archive.maximumExpandedBytes must be positive")
    if not isinstance(config["root"], str) or PurePosixPath(config["root"]).name != config["root"]:
        raise BuildError(f"{location}.root must be one directory name")
    for key in ("codePul", "riivolutionXml", "payload"):
        item = config[key]
        if not isinstance(item, dict) or not isinstance(item.get("path" if key != "payload" else "url"), str):
            raise BuildError(f"{location}.{key} is incomplete")
        _require_digest(item.get("sha256"), f"{location}.{key}.sha256")
        if not isinstance(item.get("bytes"), int) or item["bytes"] <= 0:
            raise BuildError(f"{location}.{key}.bytes must be positive")


def validate_rwfc_payload(path: Path, config: dict[str, Any]) -> None:
    expected_size = config["bytes"]
    if path.stat().st_size != expected_size or expected_size > RWFC_MAX_BYTES:
        raise BuildError("Retro-WFC payload size does not match the pinned profile")
    if sha256_file(path) != config["sha256"]:
        raise BuildError("Retro-WFC payload hash does not match the pinned profile")
    image = path.read_bytes()
    if len(image) < 0x130 or image[:12] != b"WWFC/Payload":
        raise BuildError("Retro-WFC payload header is invalid")
    if int.from_bytes(image[0x0C:0x10], "big") != len(image):
        raise BuildError("Retro-WFC payload declared size is invalid")

    signature = image[RWFC_SIGNATURE_OFFSET:RWFC_SIGNED_REGION_OFFSET]
    encoded = pow(int.from_bytes(signature, "big"), RWFC_SIGNING_EXPONENT, RWFC_SIGNING_MODULUS)
    encoded_message = encoded.to_bytes(len(signature), "big")
    digest_info = SHA256_DIGEST_INFO_PREFIX + hashlib.sha256(
        image[RWFC_SIGNED_REGION_OFFSET:]
    ).digest()
    padding_length = len(signature) - len(digest_info) - 3
    expected_message = b"\x00\x01" + b"\xff" * padding_length + b"\x00" + digest_info
    if padding_length < 8 or not hmac.compare_digest(encoded_message, expected_message):
        raise BuildError("Retro-WFC payload signature is not valid for the pinned production key")


def validate_pack(root: Path, config: dict[str, Any]) -> None:
    if not root.is_dir():
        raise BuildError(f"Retro Rewind installation is missing {config['root']}")
    version_path = root / "version.txt"
    if not version_path.is_file() or version_path.read_text().strip() != config["version"]:
        raise BuildError("Retro Rewind version does not match the pinned profile")
    for label, key in (("Code.pul", "codePul"), ("Riivolution XML", "riivolutionXml")):
        item = config[key]
        path = root / PurePosixPath(item["path"])
        if not path.is_file() or path.stat().st_size != item["bytes"]:
            raise BuildError(f"Retro Rewind {label} size does not match the pinned profile")
        if sha256_file(path) != item["sha256"]:
            raise BuildError(f"Retro Rewind {label} hash does not match the pinned profile")


def _validated_member_path(name: str) -> PurePosixPath:
    path = PurePosixPath(name)
    if path.is_absolute() or not path.parts or any(part in ("", ".", "..") for part in path.parts):
        raise BuildError(f"Retro Rewind archive contains an unsafe path: {name}")
    return path


def extract_archive(archive: Path, destination: Path, config: dict[str, Any]) -> Path:
    if archive.stat().st_size != config["archive"]["bytes"] or sha256_file(archive) != config["archive"]["sha256"]:
        raise BuildError("Retro Rewind archive does not match the pinned profile")
    root_name = config["root"]
    stage = destination.with_name(destination.name + f".partial.{os.getpid()}")
    if stage.exists():
        shutil.rmtree(stage)
    expanded = 0
    try:
        with zipfile.ZipFile(archive) as bundle:
            selected: list[tuple[zipfile.ZipInfo, PurePosixPath]] = []
            for info in bundle.infolist():
                path = _validated_member_path(info.filename)
                unix_mode = info.external_attr >> 16
                if stat.S_ISLNK(unix_mode):
                    raise BuildError(f"Retro Rewind archive contains a symbolic link: {info.filename}")
                if path.parts[0] != root_name:
                    continue
                expanded += info.file_size
                if expanded > config["archive"]["maximumExpandedBytes"]:
                    raise BuildError("Retro Rewind archive expands beyond the pinned safety limit")
                selected.append((info, path))
            if not selected:
                raise BuildError(f"Retro Rewind archive does not contain {root_name}")
            for info, path in selected:
                relative = Path(*path.parts[1:])
                output = stage / relative
                if info.is_dir():
                    output.mkdir(parents=True, exist_ok=True)
                    continue
                output.parent.mkdir(parents=True, exist_ok=True)
                with bundle.open(info) as source, output.open("xb") as target:
                    shutil.copyfileobj(source, target, 1024 * 1024)
        validate_pack(stage, config)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            validate_pack(destination, config)
            shutil.rmtree(stage)
            return destination
        os.replace(stage, destination)
        return destination
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def _download(
    url: str, output: Path, expected_size: int, expected_sha256: str,
    *, label: str = "Retro Rewind",
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_name(output.name + f".partial.{os.getpid()}")
    digest = hashlib.sha256()
    total = 0
    request = urllib.request.Request(url, headers={"User-Agent": "KartPad-Builder/0.3"})
    try:
        with urllib.request.urlopen(request) as response, partial.open("xb") as handle:
            if response.geturl() != url:
                raise BuildError(f"pinned {label} download redirected to an unexpected URL")
            while chunk := response.read(1024 * 1024):
                total += len(chunk)
                if total > expected_size:
                    raise BuildError(f"pinned {label} download is larger than expected")
                digest.update(chunk)
                handle.write(chunk)
        if total != expected_size or digest.hexdigest() != expected_sha256:
            raise BuildError(f"pinned {label} download identity does not match the profile")
        os.replace(partial, output)
    finally:
        if partial.exists():
            partial.unlink()


def prepare_inputs(profile: Profile, work_root: Path, install: bool) -> RetroRewindInputs:
    config = profile.data["retroRewind"]
    validate_config(config)
    cache = work_root / "retro-rewind-downloads"
    archive = cache / Path(urllib.parse.urlparse(config["archive"]["url"]).path).name
    root = cache / f"{config['version']}-extracted" / config["root"]
    payload = cache / "payload.RMCPD00.bin"

    try:
        validate_pack(root, config)
    except (BuildError, OSError):
        if not archive.is_file() or archive.stat().st_size != config["archive"]["bytes"] or sha256_file(archive) != config["archive"]["sha256"]:
            if not install:
                raise BuildError("missing pinned Retro Rewind pack; run ./scripts/build-user-ipa.sh bootstrap")
            _download(config["archive"]["url"], archive, config["archive"]["bytes"], config["archive"]["sha256"])
        extract_archive(archive, root, config)

    try:
        validate_rwfc_payload(payload, config["payload"])
    except (BuildError, OSError):
        if not install:
            raise BuildError("missing pinned Retro-WFC payload; run ./scripts/build-user-ipa.sh bootstrap")
        _download(config["payload"]["url"], payload, config["payload"]["bytes"], config["payload"]["sha256"], label="Retro-WFC payload")
        validate_rwfc_payload(payload, config["payload"])

    return RetroRewindInputs(
        root=root,
        code_pul=root / PurePosixPath(config["codePul"]["path"]),
        payload=payload,
        version=config["version"],
    )
