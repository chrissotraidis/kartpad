#!/usr/bin/env python3
"""Build a tvOS brandassets catalog from a Wii opening.bnr banner."""

from __future__ import annotations

import argparse
import json
import struct
import sys
import zlib
from pathlib import Path


U8_MAGIC = b"\x55\xaa\x38\x2d"
IMD5_MAGIC = b"IMD5"
LZ77_MAGIC = b"LZ77"
TPL_MAGIC = b"\x00\x20\xaf\x30"


class BannerError(ValueError):
    pass


def u16(data: bytes, offset: int) -> int:
    return struct.unpack_from(">H", data, offset)[0]


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from(">I", data, offset)[0]


def u8_files(data: bytes, label: str) -> list[tuple[str, bytes]]:
    if data[:4] != U8_MAGIC:
        raise BannerError(f"{label} is not a U8 archive")
    if len(data) < 0x20:
        raise BannerError(f"{label} is truncated")
    root_offset = u32(data, 4)
    node_count = u32(data, root_offset + 8)
    node_end = root_offset + node_count * 12
    if node_count < 1 or node_end > len(data):
        raise BannerError(f"{label} has an invalid U8 node table")
    names_offset = node_end
    files: list[tuple[str, bytes]] = []
    for index in range(1, node_count):
        node = root_offset + index * 12
        kind_and_name = u32(data, node)
        if kind_and_name >> 24:
            continue
        name_offset = kind_and_name & 0x00FFFFFF
        name_start = names_offset + name_offset
        name_end = data.find(b"\0", name_start)
        if name_start >= len(data) or name_end < 0:
            raise BannerError(f"{label} has an invalid U8 filename")
        file_offset = u32(data, node + 4)
        file_size = u32(data, node + 8)
        if file_offset + file_size > len(data):
            raise BannerError(f"{label} contains an out-of-range file")
        files.append((data[name_start:name_end].decode("ascii"), data[file_offset:file_offset + file_size]))
    return files


def unwrap(data: bytes, label: str) -> bytes:
    if data[:4] == IMD5_MAGIC:
        if len(data) < 0x20:
            raise BannerError(f"{label} has a truncated IMD5 header")
        payload_size = struct.unpack_from(">I", data, 4)[0]
        if payload_size > len(data) - 0x20:
            raise BannerError(f"{label} has an invalid IMD5 size")
        data = data[0x20:0x20 + payload_size]
    if data[:4] != LZ77_MAGIC:
        return data
    if len(data) < 8:
        raise BannerError(f"{label} has a truncated LZ77 header")
    header = struct.unpack_from("<I", data, 4)[0]
    output_size = header >> 8
    if (header >> 4) & 0xF != 1:
        raise BannerError(f"{label} uses an unsupported LZ77 method")
    output = bytearray()
    cursor = 8
    while len(output) < output_size:
        if cursor >= len(data):
            raise BannerError(f"{label} ends inside an LZ77 flag group")
        flags = data[cursor]
        cursor += 1
        for _ in range(8):
            if flags & 0x80:
                if cursor + 2 > len(data):
                    raise BannerError(f"{label} ends inside an LZ77 reference")
                reference = struct.unpack_from(">H", data, cursor)[0]
                cursor += 2
                length = 3 + (reference >> 12)
                distance = reference & 0x0FFF
                source = len(output) - distance - 1
                if source < 0:
                    raise BannerError(f"{label} contains an invalid LZ77 distance")
                for _ in range(length):
                    if source >= len(output):
                        raise BannerError(f"{label} contains an invalid LZ77 copy")
                    output.append(output[source])
                    source += 1
                    if len(output) == output_size:
                        break
            else:
                if cursor >= len(data):
                    raise BannerError(f"{label} ends inside an LZ77 literal")
                output.append(data[cursor])
                cursor += 1
            flags = (flags << 1) & 0xFF
            if len(output) == output_size:
                break
    return bytes(output)


def find_file(files: list[tuple[str, bytes]], filename: str, label: str) -> bytes:
    for name, data in files:
        if name == filename:
            return data
    raise BannerError(f"{label} is missing {filename}")


def decode_cmpr(tpl: bytes, label: str) -> tuple[int, int, list[tuple[int, int, int, int]]]:
    if tpl[:4] != TPL_MAGIC or len(tpl) < 0x20:
        raise BannerError(f"{label} is not a supported TPL")
    texture_count = u32(tpl, 4)
    table_offset = u32(tpl, 8)
    if texture_count < 1 or table_offset + 4 > len(tpl):
        raise BannerError(f"{label} has an invalid TPL table")
    descriptor = u32(tpl, table_offset)
    if descriptor + 12 > len(tpl):
        raise BannerError(f"{label} has an invalid TPL descriptor")
    height = u16(tpl, descriptor)
    width = u16(tpl, descriptor + 2)
    image_format = u32(tpl, descriptor + 4)
    image_offset = u32(tpl, descriptor + 8)
    if image_format != 14:
        raise BannerError(f"{label} is not CMPR")
    if width == 0 or height == 0:
        raise BannerError(f"{label} has empty dimensions")
    tile_width = (width + 7) // 8
    tile_height = (height + 7) // 8
    image_size = tile_width * tile_height * 32
    if image_offset + image_size > len(tpl):
        raise BannerError(f"{label} has truncated CMPR data")

    def rgb565(value: int) -> tuple[int, int, int]:
        return (
            ((value >> 11) & 0x1F) * 255 // 31,
            ((value >> 5) & 0x3F) * 255 // 63,
            (value & 0x1F) * 255 // 31,
        )

    pixels = [(0, 0, 0, 0)] * (width * height)
    cursor = image_offset
    for tile_y in range(0, height, 8):
        for tile_x in range(0, width, 8):
            for sub_y in (0, 4):
                for sub_x in (0, 4):
                    color0, color1, indices = struct.unpack_from(">HHI", tpl, cursor)
                    cursor += 8
                    colors = [rgb565(color0), rgb565(color1)]
                    if color0 > color1:
                        colors.extend(
                            tuple((2 * a + b) // 3 for a, b in zip(colors[0], colors[1]))
                            for _ in (0,)
                        )
                        colors.append(
                            tuple((a + 2 * b) // 3 for a, b in zip(colors[0], colors[1]))
                        )
                        alpha = [255, 255, 255, 255]
                    else:
                        colors.extend(
                            tuple((a + b) // 2 for a, b in zip(colors[0], colors[1]))
                            for _ in (0,)
                        )
                        colors.append((0, 0, 0))
                        alpha = [255, 255, 255, 0]
                    for local_y in range(4):
                        for local_x in range(4):
                            x = tile_x + sub_x + local_x
                            y = tile_y + sub_y + local_y
                            if x >= width or y >= height:
                                continue
                            color_index = (indices >> (30 - 2 * (local_y * 4 + local_x))) & 3
                            red, green, blue = colors[color_index]
                            pixels[y * width + x] = (red, green, blue, alpha[color_index])
    return width, height, pixels


def resize(
    width: int,
    height: int,
    pixels: list[tuple[int, int, int, int]],
    new_width: int,
    new_height: int,
) -> tuple[int, int, list[tuple[int, int, int, int]]]:
    output: list[tuple[int, int, int, int]] = []
    for y in range(new_height):
        source_y = (y + 0.5) * height / new_height - 0.5
        y0 = max(0, min(height - 1, int(source_y)))
        y1 = min(height - 1, y0 + 1)
        y_weight = max(0.0, min(1.0, source_y - y0))
        for x in range(new_width):
            source_x = (x + 0.5) * width / new_width - 0.5
            x0 = max(0, min(width - 1, int(source_x)))
            x1 = min(width - 1, x0 + 1)
            x_weight = max(0.0, min(1.0, source_x - x0))
            top = pixels[y0 * width + x0]
            top_right = pixels[y0 * width + x1]
            bottom = pixels[y1 * width + x0]
            bottom_right = pixels[y1 * width + x1]
            output.append(
                tuple(
                    round(
                        (top[channel] * (1 - x_weight) + top_right[channel] * x_weight) * (1 - y_weight)
                        + (bottom[channel] * (1 - x_weight) + bottom_right[channel] * x_weight) * y_weight
                    )
                    for channel in range(4)
                )
            )
    return new_width, new_height, output


def composite(
    destination: list[tuple[int, int, int, int]],
    destination_width: int,
    destination_height: int,
    source: tuple[int, int, list[tuple[int, int, int, int]]],
    x_offset: int,
    y_offset: int,
) -> None:
    source_width, source_height, source_pixels = source
    for y in range(source_height):
        y_target = y + y_offset
        if y_target < 0 or y_target >= destination_height:
            continue
        for x in range(source_width):
            x_target = x + x_offset
            if x_target < 0 or x_target >= destination_width:
                continue
            red, green, blue, alpha = source_pixels[y * source_width + x]
            if alpha == 0:
                continue
            index = y_target * destination_width + x_target
            old_red, old_green, old_blue, old_alpha = destination[index]
            source_alpha = alpha / 255.0
            inverse_alpha = 1.0 - source_alpha
            destination[index] = (
                round(red * source_alpha + old_red * inverse_alpha),
                round(green * source_alpha + old_green * inverse_alpha),
                round(blue * source_alpha + old_blue * inverse_alpha),
                round(alpha + old_alpha * inverse_alpha),
            )


def banner_image(
    width: int,
    height: int,
    logo: tuple[int, int, list[tuple[int, int, int, int]]],
    kart: tuple[int, int, list[tuple[int, int, int, int]]],
) -> list[tuple[int, int, int, int]]:
    design_width, design_height = 1280, 768
    background = (6, 22, 49, 255)
    design = [background] * (design_width * design_height)
    logo_scaled = resize(logo[0], logo[1], logo[2], 760, 278)
    kart_scaled = resize(kart[0], kart[1], kart[2], 520, 294)
    composite(design, design_width, design_height, kart_scaled, 70, 410)
    composite(design, design_width, design_height, logo_scaled, 440, 135)
    if (width, height) != (design_width, design_height):
        scale = min(width / design_width, height / design_height)
        scaled_width = max(1, round(design_width * scale))
        scaled_height = max(1, round(design_height * scale))
        resized = resize(design_width, design_height, design, scaled_width, scaled_height)[2]
        output = [background] * (width * height)
        composite(output, width, height, (scaled_width, scaled_height, resized),
                  (width - scaled_width) // 2, (height - scaled_height) // 2)
        return output
    return design


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    scanlines = bytearray()
    for y in range(height):
        scanlines.append(0)
        for red, green, blue, alpha in pixels[y * width:(y + 1) * width]:
            scanlines.extend((red, green, blue, alpha))
    png = b"\x89PNG\r\n\x1a\n"
    png += png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += png_chunk(b"IDAT", zlib.compress(bytes(scanlines), 9))
    png += png_chunk(b"IEND", b"")
    path.write_bytes(png)


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n")


def image_set(path: Path, filenames: list[str]) -> None:
    write_json(
        path / "Contents.json",
        {
            "images": [
                {"filename": filename, "idiom": "tv", "scale": scale}
                for filename, scale in filenames
            ],
            "info": {"author": "xcode", "version": 1},
        },
    )


def image_layer(path: Path, filenames: list[str]) -> None:
    path.mkdir(parents=True, exist_ok=True)
    imageset = path / "Content.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    image_set(imageset, filenames)
    write_json(path / "Contents.json", {"info": {"author": "xcode", "version": 1}})


def image_stack(path: Path, layer_filenames: list[str]) -> None:
    path.mkdir(parents=True, exist_ok=True)
    write_json(
        path / "Contents.json",
        {
            "info": {"author": "xcode", "version": 1},
            "layers": [{"filename": filename} for filename in layer_filenames],
        },
    )


def create_brandassets(
    opening_bnr: Path,
    output_catalog: Path,
) -> None:
    if output_catalog.exists():
        raise BannerError(f"output already exists: {output_catalog}")
    data = opening_bnr.read_bytes()
    archive_offset = data.find(U8_MAGIC, 0x40)
    if archive_offset < 0:
        raise BannerError("opening.bnr does not contain its U8 archive")
    outer_files = u8_files(data[archive_offset:], "opening.bnr")
    banner = unwrap(find_file(outer_files, "banner.bin", "opening.bnr"), "banner.bin")
    icon = unwrap(find_file(outer_files, "icon.bin", "opening.bnr"), "icon.bin")
    banner_files = u8_files(banner, "banner.bin")
    icon_files = u8_files(icon, "icon.bin")
    logo = decode_cmpr(
        find_file(banner_files, "tk_logoENG_00.tpl", "banner.bin"),
        "tk_logoENG_00.tpl",
    )
    kart = decode_cmpr(
        find_file(icon_files, "tk_kartBody_00.tpl", "icon.bin"),
        "tk_kartBody_00.tpl",
    )

    brandassets = output_catalog / "App Icon.brandassets"
    small_stack = brandassets / "App Icon - Small.imagestack"
    large_stack = brandassets / "App Icon - Large.imagestack"
    small_layer = small_stack / "Layer.imagestacklayer"
    large_layer = large_stack / "Layer.imagestacklayer"
    small_accent = small_stack / "Accent.imagestacklayer"
    large_accent = large_stack / "Accent.imagestacklayer"
    top_shelf = brandassets / "Top Shelf Image.imageset"
    for directory in (
        output_catalog,
        brandassets,
        small_layer,
        large_layer,
        small_accent,
        large_accent,
        small_layer / "Content.imageset",
        large_layer / "Content.imageset",
        small_accent / "Content.imageset",
        large_accent / "Content.imageset",
        top_shelf,
    ):
        directory.mkdir(parents=True, exist_ok=True)

    small_image = banner_image(400, 240, logo, kart)
    small_image_2x = banner_image(800, 480, logo, kart)
    large_image = banner_image(1280, 768, logo, kart)
    top_shelf_image = banner_image(1920, 720, logo, kart)
    write_png(small_layer / "Content.imageset/icon-small.png", 400, 240, small_image)
    write_png(small_layer / "Content.imageset/icon-small@2x.png", 800, 480, small_image_2x)
    write_png(large_layer / "Content.imageset/icon-large.png", 1280, 768, large_image)
    write_png(top_shelf / "top-shelf.png", 1920, 720, top_shelf_image)
    transparent_small = [(0, 0, 0, 0)] * (400 * 240)
    transparent_small_2x = [(0, 0, 0, 0)] * (800 * 480)
    transparent_large = [(0, 0, 0, 0)] * (1280 * 768)
    write_png(small_accent / "Content.imageset/accent-small.png", 400, 240, transparent_small)
    write_png(small_accent / "Content.imageset/accent-small@2x.png", 800, 480, transparent_small_2x)
    write_png(large_accent / "Content.imageset/accent-large.png", 1280, 768, transparent_large)

    image_layer(small_layer, [("icon-small.png", "1x"), ("icon-small@2x.png", "2x")])
    image_layer(large_layer, [("icon-large.png", "1x")])
    image_layer(small_accent, [("accent-small.png", "1x"), ("accent-small@2x.png", "2x")])
    image_layer(large_accent, [("accent-large.png", "1x")])
    image_stack(small_stack, ["Accent.imagestacklayer", "Layer.imagestacklayer"])
    image_stack(large_stack, ["Accent.imagestacklayer", "Layer.imagestacklayer"])
    image_set(top_shelf, [("top-shelf.png", "1x")])
    write_json(
        brandassets / "Contents.json",
        {
            "assets": [
                {
                    "idiom": "tv",
                    "role": "primary-app-icon",
                    "size": "400x240",
                    "filename": "App Icon - Small.imagestack",
                },
                {
                    "idiom": "tv",
                    "role": "primary-app-icon",
                    "size": "1280x768",
                    "filename": "App Icon - Large.imagestack",
                },
                {
                    "idiom": "tv",
                    "role": "top-shelf-image",
                    "size": "1920x720",
                    "filename": "Top Shelf Image.imageset",
                },
            ],
            "info": {"author": "xcode", "version": 1},
        },
    )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("opening_bnr", type=Path)
    parser.add_argument("output_catalog", type=Path)
    args = parser.parse_args(argv)
    try:
        if not args.opening_bnr.is_absolute() or not args.output_catalog.is_absolute():
            raise BannerError("both paths must be absolute")
        if not args.opening_bnr.is_file():
            raise BannerError(f"missing opening.bnr: {args.opening_bnr}")
        create_brandassets(args.opening_bnr, args.output_catalog)
    except (BannerError, OSError, struct.error) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"Generated tvOS Wii banner assets: {args.output_catalog}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
