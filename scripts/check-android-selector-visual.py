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
    by_description = {
        node.attrib.get("content-desc", ""): node
        for node in nodes
        if node.attrib.get("content-desc")
    }
    required_text = (
        "KartPad",
        "Choose your way to race",
        "Your own RMCP01 disc image or extracted game data is required before play.",
    )
    missing = [label for label in required_text if label not in by_text]
    if missing:
        raise SystemExit(f"ERROR: selector labels missing: {missing}")
    original_label = "Mario Kart Wii\nOriginal game"
    retro_label = "Retro Rewind\nDownload 6.12.5 • Extra content + Retro WFC"
    missing_descriptions = [
        label for label in ("KartPad", original_label, retro_label)
        if label not in by_description
    ]
    if missing_descriptions:
        raise SystemExit(
            f"ERROR: selector accessibility labels missing: {missing_descriptions}"
        )

    original = parse_bounds(by_description[original_label].attrib["bounds"])
    retro = parse_bounds(by_description[retro_label].attrib["bounds"])
    mark = parse_bounds(by_description["KartPad"].attrib["bounds"])
    title = parse_bounds(by_text["KartPad"].attrib["bounds"])
    tagline = parse_bounds(by_text["Choose your way to race"].attrib["bounds"])
    message = parse_bounds(by_text[required_text[2]].attrib["bounds"])
    density = (mark[2] - mark[0]) / 48.0

    def expect_dp(actual: float, expected: float, label: str, tolerance: float = 2.1) -> None:
        target = expected * density
        if abs(actual - target) > tolerance:
            raise SystemExit(f"ERROR: {label} is {actual}px; expected {target}px")

    expect_dp(title[1] - mark[3], 12, "mark/title spacing")
    expect_dp(tagline[1] - title[3], 12, "title/tagline spacing")
    expect_dp(message[1] - tagline[3], 12, "tagline/message spacing")
    expect_dp(original[1] - message[3], 24, "message/card spacing")
    expect_dp(original[3] - original[1], 96, "mode-card height")

    for label, node, bounds in (
        ("Original", by_description[original_label], original),
        ("Retro Rewind", by_description[retro_label], retro),
    ):
        content_nodes = [
            child for child in node.iter()
            if child is not node and (
                child.attrib.get("class") == "android.widget.ImageView" or
                child.attrib.get("text")
            )
        ]
        content_bounds = [parse_bounds(child.attrib["bounds"]) for child in content_nodes]
        content_left = min(item[0] for item in content_bounds)
        content_right = max(item[2] for item in content_bounds)
        if abs((content_left + content_right) - (bounds[0] + bounds[2])) > 3:
            raise SystemExit(f"ERROR: {label} icon/label group is not centered")
    # The custom accessible button bounds can differ by a few density-rounded
    # pixels even though the equal-weight card Views share one row.
    if abs(original[1] - retro[1]) > 4 or abs(original[3] - retro[3]) > 4:
        raise SystemExit(f"ERROR: mode cards are not vertically aligned: {original} {retro}")
    original_width = original[2] - original[0]
    retro_width = retro[2] - retro[0]
    if abs(original_width - retro_width) > 1 or retro[0] <= original[2]:
        raise SystemExit(f"ERROR: mode cards are not equal separated columns: {original} {retro}")
    if abs(((original[0] + retro[2]) / 2) - args.width / 2) > 1:
        raise SystemExit("ERROR: mode-card group is not horizontally centered")
    if mark[2] - mark[0] != mark[3] - mark[1] or mark[2] - mark[0] < 72:
        raise SystemExit(f"ERROR: selector mark is not a full square target: {mark}")

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

    # Sample card fill away from the leading icon and centered text. The exact
    # Android colors mirror iOS's 0.03/0.49/1.0 and 0.96/0.22/0.39 values.
    card_y = original[1] + 24
    blue = pixel(original[2] - 40, card_y)
    pink = pixel(retro[2] - 40, card_y)
    if not close(blue, (8, 125, 255)):
        raise SystemExit(f"ERROR: Original card fill {blue} is not KartPad blue")
    if not close(pink, (245, 56, 99)):
        raise SystemExit(f"ERROR: Retro card fill {pink} is not KartPad pink")

    # The top-left and bottom-right app-content samples must retain the diagonal
    # navy-to-wine direction. Avoid system/status/navigation bars.
    navy = pixel(width // 5, height // 4)
    wine = pixel(width * 4 // 5, height * 3 // 4)
    if not (navy[2] > navy[0] and wine[0] > wine[2]):
        raise SystemExit(f"ERROR: selector gradient direction changed: {navy} -> {wine}")

    print(
        "Android selector visual contract passed: "
        f"viewport={width}x{height} cards={original_width}px "
        f"blue={blue} pink={pink} gradient={navy}->{wine}"
    )


if __name__ == "__main__":
    main()
