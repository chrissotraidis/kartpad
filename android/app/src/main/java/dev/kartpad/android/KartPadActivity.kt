package dev.kartpad.android

import android.os.Bundle
import android.content.Context
import android.system.Os
import android.util.Log
import android.view.ViewGroup
import java.io.File
import org.libsdl.app.SDLActivity
import org.libsdl.app.SDLSurface

class KartPadActivity : SDLActivity() {
    override fun createSDLSurface(context: Context): SDLSurface = KartPadSurface(context)

    override fun onCreate(savedInstanceState: Bundle?) {
        if (BuildConfig.GAME_RUNTIME) {
            KartPadRuntimeResources.install(this)
            Os.setenv("KARTPAD_ANDROID_FILES_DIR", filesDir.absolutePath, true)
            Os.setenv("KARTPAD_ANDROID_CACHE_DIR", cacheDir.absolutePath, true)
            configureDebugRkgInput()
        }
        super.onCreate(savedInstanceState)
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
            Os.setenv("KARTPAD_RKG_INPUT_V2", fixture.absolutePath, true)
            Os.setenv("KARTPAD_RKG_AUTOSTART_V2", "1", true)
            Os.setenv("KARTPAD_RKG_FORCE_METADATA_V2", "1", true)
            Os.setenv("KARTPAD_PRECISE_MENU_PULSE_V2", "1", true)
            Log.i(TAG, "Debug app-private RKG input enabled")
        } else {
            Os.unsetenv("KARTPAD_RKG_INPUT_V2")
            Os.unsetenv("KARTPAD_RKG_AUTOSTART_V2")
            Os.unsetenv("KARTPAD_RKG_FORCE_METADATA_V2")
            Os.unsetenv("KARTPAD_PRECISE_MENU_PULSE_V2")
        }
    }

    companion object {
        private const val TAG = "KartPadFixture"
        private const val DEBUG_RKG_RELATIVE_PATH = "KartPad/Diagnostics/TestInput.rkg"
        private const val MIN_RKG_BYTES = 0x90L
        private const val MAX_RKG_BYTES = 1024L * 1024L
        private val RKG_MAGIC = byteArrayOf('R'.code.toByte(), 'K'.code.toByte(), 'G'.code.toByte(), 'D'.code.toByte())
    }
}
