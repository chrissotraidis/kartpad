from __future__ import annotations

import argparse
import json
from pathlib import Path

from .profiles import validate_profile


def _c_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=True)


def render_retro_rewind_header(profile_data: dict) -> str:
    validate_profile(profile_data, "release profile")
    config = profile_data["retroRewind"]
    archive = config["archive"]
    update = config.get("updateArchive", {})
    code = config["codePul"]
    xml = config["riivolutionXml"]
    values = {
        "KARTPAD_RR_VERSION": config["version"],
        "KARTPAD_RR_VERSION_MANIFEST_URL": config["versionManifestUrl"],
        "KARTPAD_RR_ROOT": config["root"],
        "KARTPAD_RR_ARCHIVE_URL": archive["url"],
        "KARTPAD_RR_UPDATE_URL": update.get("url", ""),
        "KARTPAD_RR_UPDATE_SHA256": update.get("sha256", ""),
        "KARTPAD_RR_ARCHIVE_SHA256": archive["sha256"],
        "KARTPAD_RR_CODE_PUL_PATH": code["path"],
        "KARTPAD_RR_CODE_PUL_SHA256": code["sha256"],
        "KARTPAD_RR_XML_PATH": xml["path"],
        "KARTPAD_RR_XML_SHA256": xml["sha256"],
    }
    numbers = {
        "KARTPAD_RR_ARCHIVE_BYTES": archive["bytes"],
        "KARTPAD_RR_UPDATE_BYTES": update.get("bytes", 0),
        "KARTPAD_RR_UPDATE_MAXIMUM_EXPANDED_BYTES": update.get("maximumExpandedBytes", 0),
        "KARTPAD_RR_MAXIMUM_EXPANDED_BYTES": archive["maximumExpandedBytes"],
        "KARTPAD_RR_CODE_PUL_BYTES": code["bytes"],
        "KARTPAD_RR_XML_BYTES": xml["bytes"],
    }
    lines = [
        "// Generated from builder/profiles/mkwii-rmcp01-rev0.json. Do not edit.",
        "#pragma once",
        "",
        "#include <stdint.h>",
        "",
    ]
    lines.extend(f"#define {name} {_c_string(value)}" for name, value in values.items())
    lines.extend(f"#define {name} UINT64_C({value})" for name, value in numbers.items())
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate the iOS Retro Rewind release contract header"
    )
    parser.add_argument("profile", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    profile_data = json.loads(args.profile.read_text())
    rendered = render_retro_rewind_header(profile_data)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
