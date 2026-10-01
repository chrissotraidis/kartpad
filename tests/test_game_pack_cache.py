"""Pack reuse still validates disc data and app state, without retranslating."""
import os
import sys
import tempfile
import unittest
import zipfile
from contextlib import ExitStack
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "builder"))
from kartpad_builder import game_pack
from kartpad_builder.errors import BuildError
from kartpad_builder.profiles import load_profiles

REPO = Path(__file__).resolve().parents[1]


class PackCacheTests(unittest.TestCase):
    def build_cached(self, platform, *, disc_error=False, state_error=False, new_interface=False):
        with tempfile.TemporaryDirectory() as temporary, ExitStack() as stack:
            root = Path(temporary)
            stack.enter_context(mock.patch.dict(os.environ, {"PADMINT_CACHE": str(root / "cache")}))
            fingerprint, image_hash = "a" * 64, "b" * 64
            cache = game_pack._pack_cache(platform, fingerprint, image_hash)
            cache.mkdir(parents=True)
            pack_bytes = b"previously checked pack fixture"
            (cache / game_pack.PACK_FILES[platform]).write_bytes(pack_bytes)
            (cache / game_pack.PACK_RECORD).write_text("{}")
            app = root / ("app.so" if platform == "android" else "app.ipa")
            if platform == "android":
                app.write_bytes(b"runtime fixture")
            else:
                with zipfile.ZipFile(app, "w") as archive:
                    archive.writestr("Payload/KartPad.app/KartPad", b"runtime fixture")
            output = root / ("result.so" if platform == "android" else "result.ipa")
            stack.enter_context(mock.patch.object(game_pack, "source_fingerprint", return_value="c" * 64))
            stack.enter_context(mock.patch.object(game_pack.runtime_stage, "stage",
                                                  side_effect=lambda repo, name, target: target.mkdir(parents=True)))
            stack.enter_context(mock.patch.object(game_pack.pack_fingerprint, "fingerprint",
                                                  return_value="d" * 64 if new_interface else fingerprint))
            preflight = stack.enter_context(mock.patch.object(game_pack, "prepare_inputs"))
            extraction = stack.enter_context(mock.patch.object(game_pack, "extract",
                side_effect=BuildError("disc identity mismatch") if disc_error else None))
            translation = stack.enter_context(mock.patch.object(game_pack, "translate"))
            def build_step(command):
                if state_error:
                    raise BuildError("pack state check failed")
                if command[:2] == ["cmake", "--build"]:
                    folder = Path(command[2])
                    folder.mkdir(parents=True, exist_ok=True)
                    (folder / game_pack.PACK_FILES[platform]).write_bytes(b"fresh pack fixture")
                if "--record" in command:
                    Path(command[-1]).write_text("{}")
                if "--strip-unneeded" in command:
                    Path(command[command.index("-o") + 1]).write_bytes(b"fresh pack fixture")

            run = stack.enter_context(mock.patch.object(game_pack, "run", side_effect=build_step))
            stack.enter_context(mock.patch.object(game_pack, "host_ndk", return_value=root / "ndk"))
            stack.enter_context(mock.patch.object(game_pack, "_ndk_tool", return_value=root / "llvm-nm"))
            stack.enter_context(mock.patch.object(game_pack, "_ios_llvm", return_value=None))
            stack.enter_context(mock.patch.object(game_pack, "_xcrun", return_value="nm"))
            builder = game_pack.build_android_pack if platform == "android" else game_pack.build_ios_pack
            arguments = dict(repo=REPO, profile=load_profiles(REPO / "builder/profiles")[0],
                             image=root / "disc.rvz", image_sha256=image_hash,
                             app=app, output=output, work_root=root / "work")
            if disc_error or state_error:
                with self.assertRaises(BuildError):
                    builder(**arguments)
                self.assertFalse(output.exists(), "failed validation must not publish a pack")
                self.assertEqual((cache / game_pack.PACK_FILES[platform]).read_bytes(), pack_bytes)
                return
            result = builder(**arguments)
            preflight.assert_called_once()
            extraction.assert_called_once()
            if new_interface:
                translation.assert_called_once()
                commands = [call.args[0] for call in run.call_args_list]
                self.assertTrue(any(command[:2] == ["cmake", "--build"] for command in commands))
                self.assertTrue(any("--record" in command for command in commands))
                if platform == "android":
                    self.assertEqual(result.pack.read_bytes(), b"fresh pack fixture")
                else:
                    with zipfile.ZipFile(result.pack) as archive:
                        self.assertEqual(archive.read("Payload/KartPad.app/Frameworks/libkartpad_game.dylib"),
                                         b"fresh pack fixture")
                self.assertEqual((cache / game_pack.PACK_FILES[platform]).read_bytes(), pack_bytes)
                return
            translation.assert_not_called()
            run.assert_called_once()
            command = run.call_args.args[0]
            self.assertIn(str(REPO / "scripts/check-game-pack-state.py"), command)
            self.assertIn(str(cache / game_pack.PACK_RECORD), command)
            self.assertNotIn("--record", command)
            if platform == "android":
                self.assertEqual(result.pack.read_bytes(), pack_bytes)
            else:
                with zipfile.ZipFile(result.pack) as archive:
                    self.assertEqual(archive.read("Payload/KartPad.app/Frameworks/libkartpad_game.dylib"), pack_bytes)
                    self.assertEqual(archive.read("Payload/KartPad.app/KartPad"), b"runtime fixture")

    def test_cached_pack_skips_translation_but_checks_disc_and_new_app(self):
        for platform in ("android", "ios"):
            with self.subTest(platform=platform):
                self.build_cached(platform)

    def test_bad_disc_is_rejected_even_with_a_cached_pack(self):
        for platform in ("android", "ios"):
            with self.subTest(platform=platform):
                self.build_cached(platform, disc_error=True)

    def test_changed_interface_translates_and_builds_a_new_pack(self):
        for platform in ("android", "ios"):
            with self.subTest(platform=platform):
                self.build_cached(platform, new_interface=True)

    def test_failed_app_state_check_preserves_cache_and_stops_packaging(self):
        for platform in ("android", "ios"):
            with self.subTest(platform=platform):
                self.build_cached(platform, state_error=True)

    def test_cache_requires_the_disc_and_interface_and_symbol_record(self):
        with tempfile.TemporaryDirectory() as temporary, mock.patch.dict(os.environ, {"PADMINT_CACHE": temporary}):
            fingerprint, image_hash = "a" * 64, "b" * 64
            for platform in ("android", "ios"):
                cache = game_pack._pack_cache(platform, fingerprint, image_hash)
                cache.mkdir(parents=True)
                (cache / game_pack.PACK_FILES[platform]).write_bytes(b"fixture")
                self.assertIsNone(game_pack.reusable_pack(platform, fingerprint, image_hash))
                (cache / game_pack.PACK_RECORD).write_text("{}")
                self.assertEqual(game_pack.reusable_pack(platform, fingerprint, image_hash), cache)
                self.assertIsNone(game_pack.reusable_pack(platform, "d" * 64, image_hash))
                self.assertIsNone(game_pack.reusable_pack(platform, fingerprint, "e" * 64))


if __name__ == "__main__":
    unittest.main()
