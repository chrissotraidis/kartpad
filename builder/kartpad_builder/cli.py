from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import __version__
from .bootstrap import prepare_dependencies
from .pipeline import BuildError, build
from .profiles import ProfileError, load_profiles, select_profile, sha256_file


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        prog="kartpad-builder",
        description="Create a private unsigned KartPad IPA from a supported user-owned disc image.",
    )
    result.add_argument("--version", action="version", version=__version__)
    result.add_argument("--profiles-dir", type=Path, default=repo_root() / "builder/profiles")
    sub = result.add_subparsers(dest="command", required=True)
    sub.add_parser("profiles", help="List supported static-recompilation profiles")
    doctor = sub.add_parser("doctor", help="Verify tools and pinned Builder dependencies")
    doctor.add_argument("--profile", default="mkwii-rmcp01-rev0")
    bootstrap = sub.add_parser("bootstrap", help="Fetch and verify pinned Builder dependencies")
    bootstrap.add_argument("--profile", default="mkwii-rmcp01-rev0")
    inspect = sub.add_parser("inspect", help="Identify a disc image without extracting it")
    inspect.add_argument("image", type=Path)
    inspect.add_argument("--profile", default="auto")
    build_parser = sub.add_parser("build", help="Build a private unsigned IPA")
    build_parser.add_argument("image", type=Path)
    build_parser.add_argument("--profile", default="auto")
    build_parser.add_argument("--output", type=Path, default=repo_root() / "artifacts/KartPad-personal-unsigned.ipa")
    build_parser.add_argument("--work-root", type=Path, default=repo_root() / "private/builder")
    build_parser.add_argument("--jobs", type=int, choices=range(1, 9), default=2)
    build_parser.add_argument("--translation-root", type=Path, help=argparse.SUPPRESS)
    build_parser.add_argument("--app", type=Path, help=argparse.SUPPRESS)
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        profiles = load_profiles(args.profiles_dir)
        if args.command == "profiles":
            for profile in profiles:
                formats = ", ".join(profile.data["containers"]["extensions"])
                print(f"{profile.id}\t{profile.display_name}\t{formats}")
            return 0
        if args.command in ("doctor", "bootstrap"):
            profile = next((item for item in profiles if item.id == args.profile), None)
            if profile is None:
                raise ProfileError(f"unknown profile: {args.profile}")
            dependencies = prepare_dependencies(repo_root(), profile, install=args.command == "bootstrap")
            print(f"Builder dependencies verified for {profile.id}: {', '.join(dependencies)}")
            return 0
        if not args.image.is_file():
            raise ProfileError(f"disc image does not exist: {args.image}")
        suffix = args.image.suffix.lower().removeprefix(".")
        image_sha256 = sha256_file(args.image)
        profile = select_profile(profiles, image_sha256, args.profile, extension=suffix)
        if suffix not in profile.data["containers"]["extensions"]:
            raise ProfileError(f"unsupported disc-image extension for {profile.id}: .{suffix}")
        if args.command == "inspect":
            acceptance = "pinned image" if profile.accepts(image_sha256) else "verified after extraction"
            print(json.dumps({"imageSHA256": image_sha256, "profileId": profile.id,
                              "displayName": profile.display_name, "acceptance": acceptance}, indent=2))
            return 0
        prepare_dependencies(repo_root(), profile, install=False)
        result = build(
            repo=repo_root(),
            profile=profile,
            image=args.image.resolve(),
            image_sha256=image_sha256,
            output=args.output.resolve(),
            work_root=args.work_root.resolve(),
            jobs=args.jobs,
            translation_override=args.translation_root.resolve() if args.translation_root else None,
            app_override=args.app.resolve() if args.app else None,
        )
        print(f"Built private unsigned IPA: {result.ipa}")
        print(f"SHA-256: {result.ipa_sha256}")
        print("Game-code redistribution rights are not cleared; GPL-covered software remains redistributable under GPLv3.")
        return 0
    except (ProfileError, BuildError, OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
