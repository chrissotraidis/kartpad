from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidGameDataSaveContractTests(unittest.TestCase):
    def test_launcher_and_runtime_share_real_game_data_management(self) -> None:
        launcher = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadLaunchActivity.kt").read_text()
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        manager = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadGameDataActivity.kt").read_text()
        storage = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadGameDataStorage.kt").read_text()
        retro_worker = (REPO / "android/app/src/main/java/dev/kartpad/android/RetroRewindInstallWorker.kt").read_text()
        runtime_paths = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadRuntimePathConfig.kt").read_text()
        manifest = (REPO / "android/app/src/main/AndroidManifest.xml").read_text()

        self.assertIn("Intent(this, KartPadGameDataActivity::class.java)", launcher)
        self.assertIn("pendingProfile = profile", launcher)
        self.assertIn("GradientDrawable.Orientation.TL_BR", launcher)
        self.assertIn("Color.rgb(8, 125, 255)", launcher)
        self.assertIn("Color.rgb(245, 56, 99)", launcher)
        self.assertIn("cornerRadius = dp(18).toFloat()", launcher)
        self.assertIn("setModeText(this, \"Mario Kart Wii\", \"Original game\")", launcher)
        self.assertIn("minOf(760, maxOf(320, availableWidthDp))", launcher)
        for icon in (
            "ic_kartpad_steering_wheel",
            "ic_kartpad_checkered_flag",
            "ic_kartpad_gobackward",
        ):
            self.assertIn(f"R.drawable.{icon}", launcher)
            vector = (REPO / f"android/app/src/main/res/drawable/{icon}.xml").read_text()
            self.assertIn('android:viewportWidth="48"', vector)
            self.assertIn("android:pathData=", vector)
        self.assertIn("KartPadGameDataStorage.validationError(filesDir)", launcher)
        self.assertIn("KartPadGameDataStorage.ensureRuntimePath(filesDir)", launcher)
        self.assertIn("Validated game data could not be configured for the runtime.", launcher)
        self.assertIn("original.isEnabled = true", launcher)
        self.assertIn("pendingProfile?.takeIf { gameDataReady }", launcher)
        self.assertIn("EXTRA_DEBUG_GAME_DATA_VALID", launcher)
        self.assertIn("BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME", launcher)
        self.assertIn('"Import or Reimport Wii Disc Image…"', activity)
        self.assertIn('"Import from Extracted Folder…"', activity)
        self.assertIn('"Remove Stored Game Data…"', activity)
        self.assertIn("Intent.ACTION_OPEN_DOCUMENT", manager)
        self.assertIn("Intent.ACTION_OPEN_DOCUMENT_TREE", manager)
        self.assertIn("takePersistableUriPermission", manager)
        self.assertIn("KartPadGameDataStorage.importExtractedTree", manager)
        self.assertIn("KartPadGameDataStorage.importDiscImage", manager)
        self.assertIn("KartPadGameDataStorage.scheduleRemoval", manager)
        self.assertIn('android:name=".KartPadGameDataActivity"', manifest)
        self.assertIn('android:process=":launcher"', manifest)

        self.assertIn('"sys/boot.bin"', storage)
        self.assertIn('"files/rel/StaticR.rel"', storage)
        self.assertIn('"RMCP01"', storage)
        self.assertIn("MAIN_DOL_SHA256", storage)
        self.assertIn("GameData.import-", storage)
        self.assertIn("GameData.rollback-", storage)
        self.assertIn("ensureRelativeDvdRoot", storage)
        self.assertIn("fun ensureRuntimePath(filesDir: File)", storage)
        self.assertIn("if (installedDvdLine.containsMatchIn(config)) return", storage)
        self.assertIn("KartPadRuntimePathConfig.ensureRetroRewindRoot(applicationContext.filesDir)", retro_worker)
        self.assertIn('failure("runtime-path")', retro_worker)
        self.assertIn("KartPadRuntimePathConfig.ensureRetroRewindRoot(filesDir)", launcher)
        self.assertIn('retro_rewind_root = \\"RetroRewind/RetroRewind6\\"', runtime_paths)
        self.assertIn("AtomicFile(configFile)", runtime_paths)
        self.assertIn("RemoveGameDataOnNextLaunch", storage)

        importer = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadDiscImageImporter.kt").read_text()
        native = (REPO / "android/app/src/main/cpp/kartpad_discio_jni.cpp").read_text()
        gradle = (REPO / "android/app/build.gradle.kts").read_text()
        build = (REPO / "scripts/build-android-discio-probe.sh").read_text()
        self.assertIn('System.loadLibrary("kartpad_discio")', importer)
        self.assertIn('"/proc/self/fd/"', native)
        self.assertIn('volume->GetGameID(partition) != "RMCP01"', native)
        self.assertIn("DiscIO::ExportSystemData", native)
        self.assertIn("DiscIO::ExportDirectory", native)
        self.assertIn("kartpadDiscIoJniRoot", gradle)
        self.assertIn("4f8af23db516d8b6e9cd00e7b261a65b026514a8", build)

    def test_save_restore_is_validated_staged_and_backed_up_before_sdl(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        storage = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadSaveStorage.kt").read_text()

        self.assertIn('"Manage Saves…"', activity)
        self.assertIn('"Export Save Backup…"', activity)
        self.assertIn('"Restore Save Backup…"', activity)
        self.assertIn("Intent.ACTION_CREATE_DOCUMENT", activity)
        self.assertIn("Intent.ACTION_OPEN_DOCUMENT", activity)
        self.assertIn("KartPadSaveStorage.applyPending(filesDir)", activity)
        self.assertLess(
            activity.index("KartPadSaveStorage.applyPending(filesDir)"),
            activity.index("super.onCreate(savedInstanceState)"),
        )
        self.assertIn("SAVE_BYTES = 0x2bc000", storage)
        self.assertIn('"RKSD0006"', storage)
        self.assertIn("CRC32()", storage)
        self.assertIn("CORE_CRC_OFFSET", storage)
        self.assertIn("AtomicFile", storage)
        self.assertIn("SaveBackups", storage)


if __name__ == "__main__":
    unittest.main()
