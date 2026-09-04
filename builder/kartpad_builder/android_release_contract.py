from __future__ import annotations

import argparse
import json
from pathlib import Path

from .profiles import validate_profile


def _java_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=True)


def render_android_release_contract(profile_data: dict) -> str:
    validate_profile(profile_data, "release profile")
    config = profile_data["retroRewind"]
    archive = config["archive"]
    code = config["codePul"]
    xml = config["riivolutionXml"]
    payload = config["payload"]
    strings = {
        "VERSION": config["version"],
        "VERSION_MANIFEST_URL": config["versionManifestUrl"],
        "ROOT": config["root"],
        "ARCHIVE_URL": archive["url"],
        "ARCHIVE_SHA256": archive["sha256"],
        "CODE_PUL_PATH": code["path"],
        "CODE_PUL_SHA256": code["sha256"],
        "XML_PATH": xml["path"],
        "XML_SHA256": xml["sha256"],
        "PAYLOAD_URL": payload["url"],
        "PAYLOAD_SHA256": payload["sha256"],
    }
    numbers = {
        "ARCHIVE_BYTES": archive["bytes"],
        "MAXIMUM_EXPANDED_BYTES": archive["maximumExpandedBytes"],
        "CODE_PUL_BYTES": code["bytes"],
        "XML_BYTES": xml["bytes"],
        "PAYLOAD_BYTES": payload["bytes"],
    }
    lines = [
        "// Generated from builder/profiles/mkwii-rmcp01-rev0.json. Do not edit.",
        "package dev.kartpad.android;",
        "",
        "final class RetroRewindRelease {",
        "    private RetroRewindRelease() {}",
        "",
    ]
    lines.extend(
        f"    static final String {name} = {_java_string(value)};"
        for name, value in strings.items()
    )
    lines.extend(f"    static final long {name} = {value}L;" for name, value in numbers.items())
    lines.extend(["}", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate Android's pinned Retro Rewind release contract"
    )
    parser.add_argument("profile", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    profile_data = json.loads(args.profile.read_text())
    rendered = render_android_release_contract(profile_data)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
