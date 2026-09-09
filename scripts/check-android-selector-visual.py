#!/usr/bin/env python3
"""Validate a source-only KartPad selector UI tree and raw Android screencap."""

from __future__ import annotations

import argparse
import re
import struct
import xml.etree.ElementTree as ET
from pathlib import Path


def parse_bounds(raw: str) -> tuple[int, int, int, int]:
    values = tuple(int(value) for value in re.findall(r"\d+", raw))
    if len(values) != 4:
        raise ValueError(f"invalid bounds: {raw!r}")
    return values


def close(actual: tuple[int, int, int], expected: tuple[int, int, int], tolerance: int = 3) -> bool:
    return all(abs(left - right) <= tolerance for left, right in zip(actual, expected))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tree", required=True, type=Path)
    parser.add_argument("--frame", required=True, type=Path)
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    args = parser.parse_args()

    nodes = list(ET.parse(args.tree).getroot().iter("node"))
    by_text = {node.attrib.get("text", ""): node for node in nodes if node.attrib.get("text")}
    required_text = ("KartPad", "Help")
    missing = [label for label in required_text if label not in by_text]
    if missing:
        raise SystemExit(f"ERROR: selector labels missing: {missing}")
    by_id = {node.attrib.get("resource-id"): node for node in nodes}
    cards = []
    for mode, title in (("original", "Mario Kart Wii"), ("retro_rewind", "Retro Rewind")):
        node = by_id.get(f"dev.kartpad.android:id/kartpad_mode_{mode}")
        if node is None or node.attrib.get("enabled") != "true" or node.attrib.get("clickable") != "true":
            raise SystemExit(f"ERROR: {title} action is missing or disabled")
        description = node.attrib.get("content-desc", "")
        if title not in description or not any(action in description for action in
                ("Play Game", "Import Game", "Set Up Game", "Resume Game", "Use on Next Launch")):
            raise SystemExit(f"ERROR: {title} action lacks an explicit accessible name")
        bounds = parse_bounds(node.attrib["bounds"])
        left, top, right, bottom = bounds
        if not (0 <= left < right <= args.width and 0 <= top < bottom <= args.height):
            raise SystemExit(f"ERROR: {title} action extends outside the viewport: {bounds}")
        cards.append(bounds)
    original, retro = cards
    if abs(original[1] - retro[1]) > 4 or abs(original[3] - retro[3]) > 4:
        raise SystemExit(f"ERROR: compact game cards are not aligned: {cards}")
    if abs((original[2]-original[0]) - (retro[2]-retro[0])) > 2 or original[2] >= retro[0]:
        raise SystemExit(f"ERROR: compact game cards are not equal separated columns: {cards}")
    help_bounds = parse_bounds(by_text["Help"].attrib["bounds"])
    if help_bounds[3] > min(original[1], retro[1]):
        raise SystemExit("ERROR: Help is not accessible above both game choices")

    raw = args.frame.read_bytes()
    if len(raw) < 16:
        raise SystemExit("ERROR: raw screencap is truncated")
    width, height, pixel_format, _dataspace = struct.unpack_from("<4I", raw)
    if (width, height, pixel_format) != (args.width, args.height, 1):
        raise SystemExit(
            f"ERROR: raw frame header {(width, height, pixel_format)} != "
            f"{(args.width, args.height, 1)}"
        )
    pixels = memoryview(raw)[16:]
    if len(pixels) != width * height * 4:
        raise SystemExit("ERROR: raw RGBA frame length is invalid")

    def pixel(x: int, y: int) -> tuple[int, int, int]:
        offset = (y * width + x) * 4
        return tuple(pixels[offset : offset + 3])  # type: ignore[return-value]

    # Quiet bordered cards match the accepted iOS chooser. Sample below the
    # rounded top edge and away from status text; actions are checked above.
    for card in cards:
        color = pixel(card[0] + 12, (card[1] + card[3]) // 2)
        if not close(color, (19, 26, 38)):
            raise SystemExit(f"ERROR: game-card fill {color} differs from accepted chooser")
    print(f"Android chooser visual check passed: viewport={width}x{height} cards={cards}; Help and both actions visible")


if __name__ == "__main__":
    main()
