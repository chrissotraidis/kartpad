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
    # Inside the build workspace a hard link costs no space; PadForge copies the
    # folder for the player, so their copy never shares files with this cache.
    try:
        os.link(source, target)
    except OSError:
        shutil.copy2(source, target)


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
            shutil.copytree(extraction / part, stage / part, copy_function=_link_or_copy)
        for extra in EXTRAS:
            source = extraction / extra
            if source.is_dir():
                shutil.copytree(source, stage / extra, copy_function=_link_or_copy)
            elif source.is_file():
                _link_or_copy(str(source), str(stage / extra))
        stage.rename(destination)
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    return destination
