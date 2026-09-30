"""The player's game data folder, from the disc the build already extracted.

KartPad reads the game's tracks, art and music on the device. Its "Import from
Extracted Folder" wants a folder with files/ and sys/ (what Dolphin's Extract
Entire Disc makes). The build has that extraction already, so new players need
neither Dolphin nor their Wii's common key.
"""
from __future__ import annotations

import os
import shutil
from pathlib import Path

from .errors import BuildError

# The same layout as Dolphin's Extract Entire Disc: the partition's folders and
# its metadata files. KartPad's own kartpad-disc-manifest.json stays behind.
PARTS = ("files", "sys")
EXTRAS = ("disc", "ticket.bin", "tmd.bin", "cert.bin", "h3.bin")


def extraction_root(work_root: Path, profile_id: str, image_sha256: str) -> Path:
    """Where the pack build extracts and validates the disc (see game_pack._translated)."""
    return work_root / profile_id / "inputs" / image_sha256[:16] / "disc"


def _link_or_copy(source: str, target: str) -> None:
    # Inside the build workspace a hard link costs no space; PadMint copies the
    # folder for the player, so their copy never shares files with this cache.
    try:
        os.link(source, target)
    except OSError:
        shutil.copy2(source, target)


def _copy_tree(source: Path, target: Path) -> None:
    """Link or copy every file below source. Unlike copytree it never reads
    links: in Ubuntu inside Termux (proot, on Android phones) hard links are
    listed as links but cannot be read as links ("Invalid argument")."""
    for folder, _folders, files in os.walk(source):
        destination = target / Path(folder).relative_to(source)
        destination.mkdir(parents=True, exist_ok=True)
        for name in files:
            _link_or_copy(os.path.join(folder, name), str(destination / name))


def export(extraction: Path, destination: Path) -> Path:
    """Write destination/files and destination/sys from a validated extraction."""
    missing = [part for part in PARTS if not (extraction / part).is_dir()]
    if missing:
        raise BuildError(f"the extracted disc has no {', '.join(missing)} folder: {extraction}")
    if destination.exists():
        raise BuildError(f"game data output already exists: {destination}")
    stage = destination.with_name(destination.name + ".partial")
    if stage.exists():
        shutil.rmtree(stage)
    try:
        for part in PARTS:
            _copy_tree(extraction / part, stage / part)
        for extra in EXTRAS:
            source = extraction / extra
            if source.is_dir():
                _copy_tree(source, stage / extra)
            elif source.is_file():
                _link_or_copy(str(source), str(stage / extra))
        stage.rename(destination)
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    return destination
