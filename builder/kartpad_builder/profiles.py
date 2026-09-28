from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


class ProfileError(ValueError):
    pass


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(chunk_size):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


@dataclass(frozen=True)
class Profile:
    path: Path
    data: dict[str, Any]

    @property
    def id(self) -> str:
        return self.data["id"]

    @property
    def display_name(self) -> str:
        return self.data["displayName"]

    @property
    def profile_sha256(self) -> str:
        return hashlib.sha256(canonical_json(self.data)).hexdigest()

    @property
    def accepted_images(self) -> list[dict[str, Any]]:
        return self.data["containers"]["acceptedImages"]

    def accepts(self, image_sha256: str) -> bool:
        return any(item["sha256"] == image_sha256 for item in self.accepted_images)

    @property
    def accepts_verified_extraction(self) -> bool:
        """Other containers are allowed only if extraction proves the pinned executables."""
        return self.data["containers"].get("acceptVerifiedExtraction") is True


def _require(value: Any, expected: type, location: str) -> Any:
    if not isinstance(value, expected):
        raise ProfileError(f"{location} must be {expected.__name__}")
    return value


def validate_profile(data: dict[str, Any], source: str = "profile") -> None:
    _require(data, dict, source)
    if data.get("schemaVersion") != 1:
        raise ProfileError(f"{source}: unsupported schemaVersion")
    for key in (
        "id",
        "displayName",
        "sourceDependencies",
        "game",
        "containers",
        "extraction",
        "translation",
    ):
        if key not in data:
            raise ProfileError(f"{source}: missing {key}")
    for key in ("id", "displayName"):
        if not isinstance(data[key], str) or not data[key]:
            raise ProfileError(f"{source}: {key} must be a non-empty string")
    dependencies = _require(data["sourceDependencies"], list, f"{source}.sourceDependencies")
    if not dependencies or not all(isinstance(name, str) and name for name in dependencies):
        raise ProfileError(f"{source}.sourceDependencies must contain dependency names")

    game = _require(data["game"], dict, f"{source}.game")
    for key in ("discId", "region", "discNumber", "revision", "wiiMagic"):
        if key not in game:
            raise ProfileError(f"{source}.game: missing {key}")
    if len(game["discId"]) != 6:
        raise ProfileError(f"{source}.game.discId must contain six characters")

    containers = _require(data["containers"], dict, f"{source}.containers")
    extensions = _require(containers.get("extensions"), list, f"{source}.containers.extensions")
    images = _require(containers.get("acceptedImages"), list, f"{source}.containers.acceptedImages")
    if not extensions or not images:
        raise ProfileError(f"{source}: at least one extension and accepted image are required")
    if "acceptVerifiedExtraction" in containers and not isinstance(containers["acceptVerifiedExtraction"], bool):
        raise ProfileError(f"{source}.containers.acceptVerifiedExtraction must be true or false")
    seen: set[str] = set()
    for index, image in enumerate(images):
        _require(image, dict, f"{source}.containers.acceptedImages[{index}]")
        digest = image.get("sha256", "")
        if not isinstance(digest, str) or len(digest) != 64:
            raise ProfileError(f"{source}: accepted image SHA-256 must have 64 hex characters")
        try:
            bytes.fromhex(digest)
        except ValueError as exc:
            raise ProfileError(f"{source}: invalid accepted image SHA-256") from exc
        if digest in seen:
            raise ProfileError(f"{source}: duplicate accepted image SHA-256 {digest}")
        seen.add(digest)
        if image.get("format", "").lower() not in extensions:
            raise ProfileError(f"{source}: accepted image format is not in extensions")

    extraction = _require(data["extraction"], dict, f"{source}.extraction")
    for key in ("extractor", "requiredFiles", "executables"):
        if key not in extraction:
            raise ProfileError(f"{source}.extraction: missing {key}")
    for name, executable in _require(
        extraction["executables"], dict, f"{source}.extraction.executables"
    ).items():
        if not isinstance(executable, dict) or len(executable.get("sha256", "")) != 64:
            raise ProfileError(f"{source}: invalid executable identity for {name}")

    translation = _require(data["translation"], dict, f"{source}.translation")
    for key in (
        "memoryBase",
        "memorySize",
        "sdaBase",
        "sda2Base",
        "entryPoints",
        "functionMap",
        "injectors",
        "expectedGeneratedFunctions",
        "expectedBaseFunctions",
        "expectedRetroFunctions",
    ):
        if key not in translation:
            raise ProfileError(f"{source}.translation: missing {key}")
    if "retroRewind" in data:
        from .retro_rewind import validate_config

        try:
            validate_config(data["retroRewind"], f"{source}.retroRewind")
        except Exception as exc:
            raise ProfileError(str(exc)) from exc


def load_profiles(directory: Path) -> list[Profile]:
    profiles: list[Profile] = []
    ids: set[str] = set()
    image_hashes: dict[str, str] = {}
    for path in sorted(directory.glob("*.json")):
        data = json.loads(path.read_text())
        validate_profile(data, str(path))
        profile = Profile(path=path, data=data)
        if profile.id in ids:
            raise ProfileError(f"duplicate profile id: {profile.id}")
        ids.add(profile.id)
        for image in profile.accepted_images:
            digest = image["sha256"]
            if digest in image_hashes:
                raise ProfileError(
                    f"image SHA-256 is claimed by both {image_hashes[digest]} and {profile.id}"
                )
            image_hashes[digest] = profile.id
        profiles.append(profile)
    if not profiles:
        raise ProfileError(f"no profiles found in {directory}")
    return profiles


def select_profile(profiles: Iterable[Profile], image_sha256: str, requested: str = "auto",
                   extension: str | None = None) -> Profile:
    candidates = list(profiles)
    if requested != "auto":
        candidates = [profile for profile in candidates if profile.id == requested]
        if not candidates:
            raise ProfileError(f"unknown profile: {requested}")
    matches = [profile for profile in candidates if profile.accepts(image_sha256)]
    if not matches and extension is not None:
        # A different dump or container of the same disc (ISO, RVZ, another WBFS)
        # is accepted provisionally; extraction must then reproduce the profile's
        # disc identity and exact main.dol/StaticR.rel hashes or the build stops.
        matches = [profile for profile in candidates if profile.accepts_verified_extraction
                   and extension in profile.data["containers"]["extensions"]]
    if len(matches) != 1:
        if requested == "auto":
            raise ProfileError(f"no supported profile matches image SHA-256 {image_sha256}")
        raise ProfileError(f"image SHA-256 does not match profile {requested}: {image_sha256}")
    return matches[0]
