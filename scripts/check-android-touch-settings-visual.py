#!/usr/bin/env python3
"""Validate the complete Android Touch Control Settings accessibility layout."""

from __future__ import annotations

import argparse
import re
import struct
import xml.etree.ElementTree as ET
from pathlib import Path


TEXT = (
    "Touch Control Settings",
    "Render",
    "1×",
    "2×",
    "3×",
    "4×",
    "Opacity: 82%",
    "All sizes: 100%",
    "Hide on controller",
    "Modern C-stick L/R",
    "MOVE CONTROLS",
    "RESET THIS DEVICE LAYOUT",
    "DONE",
)
DESCRIPTIONS = (
    "Render resolution",
    "Control opacity",
    "All control sizes",
    "Hide touch controls when controller connected",
    "Reverse C-stick horizontal direction",
    "Edit touch control layout",
    "Reset touch control layout",
)


def bounds(raw: str) -> tuple[int, int, int, int]:
    values = tuple(int(value) for value in re.findall(r"\d+", raw))
    if len(values) != 4:
        raise ValueError(f"invalid bounds: {raw!r}")
    return values


def center_x(rect: tuple[int, int, int, int]) -> float:
    return (rect[0] + rect[2]) / 2


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
    missing_text = [value for value in TEXT if value not in by_text]
    missing_descriptions = [value for value in DESCRIPTIONS if value not in by_description]
    if missing_text or missing_descriptions:
        raise SystemExit(
            f"ERROR: settings nodes missing text={missing_text} descriptions={missing_descriptions}"
        )

    all_nodes = [by_text[value] for value in TEXT] + [by_description[value] for value in DESCRIPTIONS]
    for node in all_nodes:
        rect = bounds(node.attrib["bounds"])
        if not (0 <= rect[0] < rect[2] <= args.width and 0 <= rect[1] < rect[3] <= args.height):
            raise SystemExit(f"ERROR: settings node is clipped: {rect}")
    if by_text["1×"].attrib.get("checked") != "true":
        raise SystemExit("ERROR: native 1x render choice is not selected by default")

    opacity = bounds(by_description["Control opacity"].attrib["bounds"])
    all_sizes = bounds(by_description["All control sizes"].attrib["bounds"])
    hide = bounds(by_description["Hide touch controls when controller connected"].attrib["bounds"])
    move = bounds(by_description["Edit touch control layout"].attrib["bounds"])
    if not (center_x(opacity) < args.width / 2 and center_x(all_sizes) < args.width / 2):
        raise SystemExit("ERROR: slider column is no longer on the left")
    if not (center_x(hide) > args.width / 2 and center_x(move) > args.width / 2):
        raise SystemExit("ERROR: action column is no longer on the right")

    raw = args.frame.read_bytes()
    if len(raw) < 16:
        raise SystemExit("ERROR: raw settings frame is truncated")
    width, height, pixel_format, _dataspace = struct.unpack_from("<4I", raw)
    if (width, height, pixel_format) != (args.width, args.height, 1):
        raise SystemExit(
            f"ERROR: raw frame header {(width, height, pixel_format)} != "
            f"{(args.width, args.height, 1)}"
        )

    print(
        "Android touch-settings visual contract passed: "
        f"viewport={width}x{height} text={len(TEXT)} actions={len(DESCRIPTIONS)} "
        "columns=left-sliders/right-actions render=1x"
    )


if __name__ == "__main__":
    main()
