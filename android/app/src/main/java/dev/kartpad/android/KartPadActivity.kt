package dev.kartpad.android

import android.os.Bundle
import android.content.Context
import android.system.Os
import android.util.Log
import android.view.ViewGroup
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.libsdl.app.SDLActivity
import org.libsdl.app.SDLSurface

class KartPadActivity : SDLActivity() {
    override fun createSDLSurface(context: Context): SDLSurface = KartPadSurface(context)

    override fun onCreate(savedInstanceState: Bundle?) {
        if (BuildConfig.GAME_RUNTIME) {
            RetroRewindInstallStorage.recover(filesDir)
            KartPadRuntimeResources.install(this)
            Os.setenv("KARTPAD_ANDROID_FILES_DIR", filesDir.absolutePath, true)
            Os.setenv("KARTPAD_ANDROID_CACHE_DIR", cacheDir.absolutePath, true)
            configureRuntimeProfile()
            configureDebugRkgInput()
            configureDebugStateTrace()
        }
        super.onCreate(savedInstanceState)
        runDebugRetroRewindExtractionFixture()
        runDebugRetroRewindWorkerFixture()
        val overlay = KartPadOverlayView(this)
        mLayout.addView(
            overlay,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        mLayout.bringChildToFront(overlay)
        Log.i(TAG, "A0 SDLActivity shell created")
    }

    private fun configureRuntimeProfile() {
        val debugRequested = if (BuildConfig.DEBUG) {
            intent.getStringExtra(DEBUG_EXTRA_RUNTIME_PROFILE)
        } else {
            null
        }
        val requested = debugRequested ?: intent.getStringExtra(EXTRA_RUNTIME_PROFILE) ?: "base"

        when (requested) {
            "base" -> {
                Os.setenv("KARTPAD_RUNTIME_PROFILE", requested, true)
                Log.i(TAG, "A3 runtime profile requested=base")
            }
            "retro_rewind" -> {
                val installed = RetroRewindInstallValidator.validate(
                    RetroRewindInstallStorage.installedRoot(filesDir)
                        .resolve(RetroRewindRelease.ROOT),
                    RetroRewindInstallValidator.productionContract(),
                )
                check(installed.isValid) {
                    "Retro Rewind launch requires a validated installed pack"
                }
                Os.setenv("KARTPAD_RUNTIME_PROFILE", requested, true)
                Log.i(TAG, "A3 runtime profile requested=retro_rewind installed=valid")
            }
            else -> error("Unsupported runtime profile")
        }
    }

    private fun configureDebugRkgInput() {
        if (!BuildConfig.DEBUG) return

        val fixture = File(filesDir, DEBUG_RKG_RELATIVE_PATH)
        val header = ByteArray(RKG_MAGIC.size)
        val valid = fixture.isFile &&
            fixture.length() in MIN_RKG_BYTES..MAX_RKG_BYTES &&
            runCatching {
                fixture.inputStream().use { input ->
                    input.read(header) == header.size && header.contentEquals(RKG_MAGIC)
                }
            }.getOrDefault(false)

        if (valid) {
            val keyboardSteer = File(filesDir, DEBUG_RKG_KEYBOARD_STEER_RELATIVE_PATH).isFile
            Os.setenv("KARTPAD_RKG_INPUT_V2", fixture.absolutePath, true)
            Os.setenv("KARTPAD_RKG_AUTOSTART_V2", "1", true)
            Os.setenv("KARTPAD_RKG_FORCE_METADATA_V2", "1", true)
            Os.setenv("KARTPAD_PRECISE_MENU_PULSE_V2", "1", true)
            if (keyboardSteer) {
                Os.setenv("KARTPAD_RKG_KEYBOARD_STEER_V2", "1", true)
                Os.setenv("KARTPAD_FULL_SYNTHETIC_STICK_V2", "1", true)
            } else {
                Os.unsetenv("KARTPAD_RKG_KEYBOARD_STEER_V2")
                Os.unsetenv("KARTPAD_FULL_SYNTHETIC_STICK_V2")
            }
            Log.i(TAG, "Debug app-private RKG input enabled; keyboard steer=$keyboardSteer")
        } else {
            Os.unsetenv("KARTPAD_RKG_INPUT_V2")
            Os.unsetenv("KARTPAD_RKG_AUTOSTART_V2")
            Os.unsetenv("KARTPAD_RKG_FORCE_METADATA_V2")
            Os.unsetenv("KARTPAD_PRECISE_MENU_PULSE_V2")
            Os.unsetenv("KARTPAD_RKG_KEYBOARD_STEER_V2")
            Os.unsetenv("KARTPAD_FULL_SYNTHETIC_STICK_V2")
        }
    }

    private fun configureDebugStateTrace() {
        if (!BuildConfig.DEBUG) return

        val marker = File(filesDir, DEBUG_STATE_TRACE_MARKER_RELATIVE_PATH)
        if (marker.isFile) {
            val output = File(filesDir, DEBUG_STATE_TRACE_RELATIVE_PATH)
            output.parentFile?.mkdirs()
            Os.setenv("KARTPAD_STATE_TRACE", output.absolutePath, true)
            Log.i(TAG, "Debug app-private state trace enabled")
        } else {
            Os.unsetenv("KARTPAD_STATE_TRACE")
        }
    }

    private fun runDebugRetroRewindExtractionFixture() {
        if (!BuildConfig.DEBUG || BuildConfig.GAME_RUNTIME ||
            !intent.getBooleanExtra(DEBUG_EXTRA_RETRO_REWIND_EXTRACTION, false)
        ) {
            return
        }
        val temporary = File(cacheDir, "RetroRewindExtractionFixture-${System.nanoTime()}")
        try {
            val staging = File(temporary, "stage")
            check(staging.mkdirs())
            val archive = File(temporary, "fixture.zip")
            ZipOutputStream(FileOutputStream(archive)).use { zip ->
                zip.putNextEntry(ZipEntry("${RetroRewindRelease.ROOT}/"))
                zip.closeEntry()
                zip.putNextEntry(ZipEntry("${RetroRewindRelease.ROOT}/version.txt"))
                zip.write("${RetroRewindRelease.VERSION}\n".toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }
            val result = RetroRewindArchiveExtractor.extract(
                archive.toPath(),
                staging.toPath(),
                { false },
                { _, _ -> },
            )
            val extracted = File(staging, "${RetroRewindRelease.ROOT}/version.txt")
                .readText(Charsets.UTF_8)
            check(result.isComplete() && result.selectedEntries == 2L &&
                result.selectedBytes == extracted.toByteArray(Charsets.UTF_8).size.toLong() &&
                result.extractedBytes == result.selectedBytes &&
                extracted == "${RetroRewindRelease.VERSION}\n")
            Log.i(TAG, "A3 JNI archive extraction passed entries=2 bytes=${result.extractedBytes}")
        } catch (error: Exception) {
            Log.e(TAG, "A3 JNI archive extraction failed", error)
        } finally {
            temporary.deleteRecursively()
        }
    }

    private fun runDebugRetroRewindWorkerFixture() {
        if (!BuildConfig.DEBUG || BuildConfig.GAME_RUNTIME) {
            return
        }
        when {
            intent.getBooleanExtra(DEBUG_EXTRA_RETRO_REWIND_WORKER, false) -> {
                runDebugRetroRewindResumeFixture()
                RetroRewindInstallWork.enqueueDebugFixture(this)
                RetroRewindInstallWork.enqueueDebugFixture(this)
                Log.i(TAG, "A3 durable worker fixture enqueued twice with KEEP")
            }
        }
    }

    private fun runDebugRetroRewindResumeFixture() {
        val content = "resume-fixture-content".toByteArray(Charsets.UTF_8)
        val resumeOffset = 7
        val partial = Files.createTempFile(cacheDir.toPath(), "resume-fixture-", ".part")
        try {
            Files.write(partial, content.copyOf(resumeOffset))
            val result = RetroRewindArchiveDownload.transferResuming(
                ByteArrayInputStream(content, resumeOffset, content.size - resumeOffset),
                partial,
                content.size.toLong(),
                DEBUG_RESUME_FIXTURE_SHA256,
                resumeOffset.toLong(),
                { false },
                { _, _ -> },
            )
            check(result == RetroRewindArchiveDownload.Error.NONE)
            check(Files.readAllBytes(partial).contentEquals(content))
            Log.i(
                TAG,
                "A3 resumable transfer passed prefix=$resumeOffset total=${content.size}",
            )
        } catch (error: Exception) {
            Log.e(TAG, "A3 resumable transfer failed", error)
        } finally {
            Files.deleteIfExists(partial)
        }
    }

    companion object {
        const val EXTRA_RUNTIME_PROFILE = "dev.kartpad.android.RUNTIME_PROFILE"
        private const val TAG = "KartPadFixture"
        private const val DEBUG_RKG_RELATIVE_PATH = "KartPad/Diagnostics/TestInput.rkg"
        private const val DEBUG_RKG_KEYBOARD_STEER_RELATIVE_PATH =
            "KartPad/Diagnostics/TestInput.keyboard-steer"
        private const val DEBUG_STATE_TRACE_MARKER_RELATIVE_PATH =
            "KartPad/Diagnostics/StateTrace.enable"
        private const val DEBUG_STATE_TRACE_RELATIVE_PATH =
            "KartPad/Diagnostics/StateTrace.csv"
        private const val DEBUG_EXTRA_RETRO_REWIND_EXTRACTION =
            "dev.kartpad.android.TEST_RETRO_REWIND_EXTRACTION"
        private const val DEBUG_EXTRA_RETRO_REWIND_WORKER =
            "dev.kartpad.android.TEST_RETRO_REWIND_WORKER"
        private const val DEBUG_EXTRA_RUNTIME_PROFILE =
            "dev.kartpad.android.TEST_RUNTIME_PROFILE"
        private const val DEBUG_RESUME_FIXTURE_SHA256 =
            "cb9d5fc3b83611af65032f73119285de4e97d4b2b9f7b2e9567443635358483a"
        private const val MIN_RKG_BYTES = 0x90L
        private const val MAX_RKG_BYTES = 1024L * 1024L
        private val RKG_MAGIC = byteArrayOf('R'.code.toByte(), 'K'.code.toByte(), 'G'.code.toByte(), 'D'.code.toByte())
    }
}
