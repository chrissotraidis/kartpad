#!/usr/bin/env python3
"""Validate KartPad's source-only touch overlay hierarchy and raw RGBA frame."""

from __future__ import annotations

import argparse
import re
import struct
import xml.etree.ElementTree as ET
from pathlib import Path


LABELS = (
    "Move stick",
    "Camera stick",
    "A button",
    "B button",
    "X button",
    "Y button",
    "L button",
    "R button",
    "Z button",
    "Start button",
    "D-pad up",
    "D-pad down",
    "D-pad left",
    "D-pad right",
)


def bounds(raw: str) -> tuple[int, int, int, int]:
    values = tuple(int(value) for value in re.findall(r"\d+", raw))
    if len(values) != 4:
        raise ValueError(f"invalid bounds: {raw!r}")
    return values


def center(rect: tuple[int, int, int, int]) -> tuple[float, float]:
    return ((rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2)


def close(actual: tuple[int, int, int], expected: tuple[int, int, int], tolerance: int = 3) -> bool:
    return all(abs(left - right) <= tolerance for left, right in zip(actual, expected))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tree", required=True, type=Path)
    parser.add_argument("--frame", required=True, type=Path)
    parser.add_argument("--lane", required=True, choices=("phone", "tablet"))
    args = parser.parse_args()

    expected_size = (2400, 1080) if args.lane == "phone" else (2560, 1600)
    nodes = {
        node.attrib.get("content-desc", ""): node
        for node in ET.parse(args.tree).getroot().iter("node")
        if node.attrib.get("content-desc")
    }
    missing = [label for label in LABELS if label not in nodes]
    if missing:
        raise SystemExit(f"ERROR: touch accessibility targets missing: {missing}")
    frames = {label: bounds(nodes[label].attrib["bounds"]) for label in LABELS}

    width, height = expected_size
    for label, rect in frames.items():
        if not (0 <= rect[0] < rect[2] <= width and 0 <= rect[1] < rect[3] <= height):
            raise SystemExit(f"ERROR: {label} is outside the viewport: {rect}")
    if center(frames["Move stick"])[0] >= width / 2:
        raise SystemExit("ERROR: move stick left/right placement changed")
    for label in ("Camera stick", "A button", "B button", "X button", "Y button", "Z button"):
        if center(frames[label])[0] <= width / 2:
            raise SystemExit(f"ERROR: {label} left/right placement changed")

    x = frames["X button"]
    z = frames["Z button"]
    x_z_gap = max(z[0] - x[2], x[0] - z[2])
    minimum_x_z_gap = 44 if args.lane == "phone" else 16
    if x_z_gap < minimum_x_z_gap:
        raise SystemExit(f"ERROR: X/Z spacing regressed: X={x} Z={z}")
    l_width = frames["L button"][2] - frames["L button"][0]
    r_width = frames["R button"][2] - frames["R button"][0]
    if args.lane == "phone" and abs(l_width - r_width) > 1:
        raise SystemExit(f"ERROR: phone L/R pill widths differ: {l_width}/{r_width}")
    if args.lane == "tablet" and r_width != 560:
        raise SystemExit(f"ERROR: tablet R width {r_width}px != 560px")

    up = center(frames["D-pad up"])
    down = center(frames["D-pad down"])
    left = center(frames["D-pad left"])
    right = center(frames["D-pad right"])
    if not (up[1] < left[1] < down[1] and left[0] < up[0] < right[0]):
        raise SystemExit("ERROR: grouped D-pad cross geometry changed")

    raw = args.frame.read_bytes()
    if len(raw) < 16:
        raise SystemExit("ERROR: raw screencap is truncated")
    raw_width, raw_height, pixel_format, _dataspace = struct.unpack_from("<4I", raw)
    if (raw_width, raw_height, pixel_format) != (width, height, 1):
        raise SystemExit(
            f"ERROR: raw frame header {(raw_width, raw_height, pixel_format)} != "
            f"{(width, height, 1)}"
        )
    pixels = memoryview(raw)[16:]
    if len(pixels) != width * height * 4:
        raise SystemExit("ERROR: raw RGBA frame length is invalid")

    def pixel(x_position: int, y_position: int) -> tuple[int, int, int]:
        offset = (y_position * width + x_position) * 4
        return tuple(pixels[offset : offset + 3])  # type: ignore[return-value]

    def fill(label: str) -> tuple[int, int, int]:
        rect = frames[label]
        return pixel(
            int(rect[0] + (rect[2] - rect[0]) * 0.25),
            int(rect[1] + (rect[3] - rect[1]) * 0.25),
        )

    expected_palette = {
        "A button": (18, 120, 71),
        "B button": (153, 32, 40),
        "X button": (142, 151, 154),
        "Z button": (78, 47, 128),
        "L button": (44, 54, 57),
        "Camera stick": (174, 138, 31),
    }
    actual_palette = {label: fill(label) for label in expected_palette}
    for label, expected in expected_palette.items():
        if not close(actual_palette[label], expected):
            raise SystemExit(
                f"ERROR: {label} fill {actual_palette[label]} != expected {expected}"
            )
    surface = pixel(width // 2, height // 2)
    if not close(surface, (13, 51, 61), 1):
        raise SystemExit(f"ERROR: source fixture surface changed: {surface}")

    print(
        "Android touch visual contract passed: "
        f"lane={args.lane} viewport={width}x{height} targets={len(LABELS)} "
        f"x_z_gap={x_z_gap}px l_r={l_width}/{r_width}px palette=passed"
    )


if __name__ == "__main__":
    main()
