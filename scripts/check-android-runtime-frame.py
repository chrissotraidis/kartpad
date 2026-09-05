#!/usr/bin/env python3
"""Emit content-free diversity metrics for a private raw Android game frame."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


def analyze(raw: bytes) -> dict[str, int]:
    if len(raw) < 16:
        raise ValueError("raw screencap is truncated")
    width, height, pixel_format, _dataspace = struct.unpack_from("<4I", raw)
    if width <= height or pixel_format != 1:
        raise ValueError("runtime frame is not landscape RGBA")
    pixels = memoryview(raw)[16:]
    if len(pixels) != width * height * 4:
        raise ValueError("raw RGBA frame length is invalid")

    left, right = width // 5, width * 4 // 5
    top, bottom = height // 10, height * 9 // 10
    stride = max(1, min(width, height) // 180)
    quantized: set[tuple[int, int, int]] = set()
    minimum_luma = 255
    maximum_luma = 0
    samples = 0
    nonblack = 0
    for y_position in range(top, bottom, stride):
        for x_position in range(left, right, stride):
            offset = (y_position * width + x_position) * 4
            red, green, blue = pixels[offset : offset + 3]
            quantized.add((red // 16, green // 16, blue // 16))
            luma = (54 * red + 183 * green + 19 * blue) // 256
            minimum_luma = min(minimum_luma, luma)
            maximum_luma = max(maximum_luma, luma)
            samples += 1
            nonblack += int(red + green + blue >= 48)

    nonblack_percent = nonblack * 100 // samples
    result = {
        "width": width,
        "height": height,
        "samples": samples,
        "quantized_colors": len(quantized),
        "luma_span": maximum_luma - minimum_luma,
        "nonblack_percent": nonblack_percent,
    }
    if (
        result["quantized_colors"] < 32
        or result["luma_span"] < 60
        or result["nonblack_percent"] < 12
    ):
        raise ValueError(
            "runtime frame lacks sufficient rendered diversity "
            f"(quantized_colors={result['quantized_colors']} "
            f"luma_span={result['luma_span']} "
            f"nonblack_percent={result['nonblack_percent']})"
        )
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("frame", type=Path)
    args = parser.parse_args()
    try:
        result = analyze(args.frame.read_bytes())
    except (OSError, ValueError) as error:
        raise SystemExit(f"ERROR: {error}") from error
    print(
        "Android private runtime frame passed: "
        f"viewport={result['width']}x{result['height']} "
        f"samples={result['samples']} "
        f"quantized_colors={result['quantized_colors']} "
        f"luma_span={result['luma_span']} "
        f"nonblack_percent={result['nonblack_percent']}"
    )


if __name__ == "__main__":
    main()
