package dev.kartpad.android

import android.content.Context
import android.system.Os
import android.util.AtomicFile
import java.io.File

/** Opt-in game-renderer checks. Configure before SDL creates the GPU device. */
internal object KartPadRendererDiagnostics {
    @Volatile var active = false
        private set

    private var configured = false

    private fun setting(context: Context) = AtomicFile(File(context.filesDir, "KartPad/RendererValidation"))

    // The chooser and game use different processes. Read the durable file on
    // each launch instead of relying on a process-local SharedPreferences cache.
    fun enabled(context: Context): Boolean = runCatching {
        setting(context).openRead().use { it.read() == '1'.code && it.read() == -1 }
    }.getOrDefault(false)

    fun setEnabled(context: Context, enabled: Boolean): Boolean = runCatching {
        val file = setting(context)
        file.baseFile.parentFile?.mkdirs()
        val output = file.startWrite()
        try {
            output.write(if (enabled) '1'.code else '0'.code)
            output.fd.sync()
            file.finishWrite(output)
            // Do not use enabled(): its read-error fallback is false, which
            // would incorrectly confirm a failed read when disabling checks.
            check(file.openRead().use {
                it.read() == (if (enabled) '1'.code else '0'.code) && it.read() == -1
            }) { "Setting publication failed" }
        } catch (error: Exception) {
            file.failWrite(output)
            throw error
        }
    }.isSuccess

    @Synchronized
    fun configure(context: Context) {
        // Native validation and draw sampling cache this setting for the life of
        // the game process. A recreated Activity must report that same value.
        if (configured) return
        active = enabled(context) || BuildConfig.VERSION_NAME.contains("diagnostics")
        Os.setenv("KARTPAD_RENDERER_VALIDATION", if (active) "1" else "0", true)
        configured = true
    }
}
