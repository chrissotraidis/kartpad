from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import __version__, game_data
from .game_pack import build_android_pack, build_ios_pack
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
    doctor.add_argument("--target", choices=("ios", "android-pack", "ios-pack"), default="ios")
    bootstrap = sub.add_parser("bootstrap", help="Fetch and verify pinned Builder dependencies")
    bootstrap.add_argument("--profile", default="mkwii-rmcp01-rev0")
    bootstrap.add_argument("--target", choices=("ios", "android-pack", "ios-pack"), default="ios")
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
    pack = sub.add_parser("build-pack", help="Build a private game pack for the published app")
    pack.add_argument("platform", choices=("android", "ios"))
    pack.add_argument("image", type=Path)
    pack.add_argument("--app", type=Path, required=True,
                      help="The published KartPad APK (or its libmain.so) or empty IPA")
    pack.add_argument("--profile", default="auto")
    pack.add_argument("--output", type=Path, default=repo_root() / "artifacts/KartPad-game-pack.so")
    pack.add_argument("--work-root", type=Path, default=repo_root() / "private/builder")
    pack.add_argument("--jobs", type=int, choices=range(1, 17), default=2)
    pack.add_argument("--game-data", type=Path,
                      help="Also write the game data folder (files/ and sys/) the app imports")
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
            dependencies = prepare_dependencies(repo_root(), profile, install=args.command == "bootstrap",
                                                target=args.target)
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
        if args.command == "build-pack":
            prepare_dependencies(repo_root(), profile, install=False, target=f"{args.platform}-pack")
            if not args.app.is_file():
                raise ProfileError(f"published app does not exist: {args.app}")
            builder = build_android_pack if args.platform == "android" else build_ios_pack
            pack_result = builder(
                repo=repo_root(), profile=profile, image=args.image.resolve(),
                image_sha256=image_sha256, app=args.app.resolve(), output=args.output.resolve(),
                work_root=args.work_root.resolve(), jobs=args.jobs)
            print(f"Built private game pack: {pack_result.pack}")
            print(f"SHA-256: {pack_result.pack_sha256}")
            if args.game_data:
                folder = game_data.export(
                    game_data.extraction_root(args.work_root.resolve(), profile.id, image_sha256),
                    args.game_data.resolve())
                print(f"Game data folder: {folder}")
            print("Keep it private: it contains game code translated from your own disc.")
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
