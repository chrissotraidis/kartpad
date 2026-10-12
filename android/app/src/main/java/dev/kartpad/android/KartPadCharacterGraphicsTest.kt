package dev.kartpad.android

import android.content.Context
import android.system.Os
import android.util.AtomicFile
import java.io.File

/** Experimental character indexing comparison. Configure only before native startup. */
internal object KartPadCharacterGraphicsTest {
    enum class Mode(
        val stored: String,
        val label: String,
        val environment: String?,
        val repack: String = "0",
        val uniforms: String = "0",
        val rows: String = "",
    ) {
        // Empty repack/uniforms = let the renderer decide: every draw repacked on Adreno 8xx;
        // off elsewhere, as in 0.7.15 (0.8.0's Adreno 6xx/7xx default hid characters on phones
        // that drew them before).
        // rows = "1" reads bone matrices as three float rows, the way Dolphin does (#104, #301).
        NORMAL("normal", "Automatic (recommended)", null, repack = "", uniforms = ""),
        MATRIX_ROWS("matrix_rows", "Experimental: matrix rows like Dolphin (Snapdragon 8 Gen 3 and older)", null, repack = "1", uniforms = "1", rows = "1"),
        NATIVE_UNIFORMS("native_uniforms", "Experimental: native uniform buffers (Snapdragon 8 Gen 3 and older)", null, repack = "1", uniforms = "1"),
        CHARACTER_FIX("repack", "Experimental: fix broken characters (Snapdragon)", null, repack = "1"),
        FULL_FIX("repack_all", "Experimental: fix characters and track textures (Snapdragon, may be slower)", null, repack = "2"),
        INVISIBLE_FIX("repack_const", "Experimental: fix invisible characters (Snapdragon 8 Gen 3 / S24)", "2", repack = "1"),
        ORIGINAL("original", "Compare: original indexing", "0"),
        COMPATIBILITY("compatibility", "Compare: compatibility indexing", "1"),
    }

    @Volatile var active = Mode.NORMAL
        private set

    private var configured = false

    private fun setting(context: Context) = AtomicFile(File(context.filesDir, "KartPad/CharacterGraphicsTest"))

    fun mode(context: Context): Mode = runCatching {
        val text = setting(context).openRead().use { input ->
            val bytes = ByteArray(32)
            val length = input.read(bytes)
            if (length < 0 || input.read() != -1) return@use ""
            String(bytes, 0, length, Charsets.UTF_8)
        }
        Mode.entries.firstOrNull { it.stored == text } ?: Mode.NORMAL
    }.getOrDefault(Mode.NORMAL)

    fun setMode(context: Context, mode: Mode): Boolean = runCatching {
        val file = setting(context)
        file.baseFile.parentFile?.mkdirs()
        val output = file.startWrite()
        try {
            output.write(mode.stored.toByteArray(Charsets.UTF_8))
            output.fd.sync()
            file.finishWrite(output)
            // mode() deliberately falls back to Normal on read failure. Verify
            // exact persisted bytes here so that fallback cannot confirm a write.
            check(file.openRead().use { input ->
                mode.stored.toByteArray(Charsets.UTF_8).all { input.read() == (it.toInt() and 0xff) } &&
                    input.read() == -1
            }) { "Setting publication failed" }
        } catch (error: Exception) {
            file.failWrite(output)
            throw error
        }
    }.isSuccess

    @Synchronized
    fun configure(context: Context) {
        if (configured) return
        active = mode(context)
        val value = active.environment
        if (value == null) Os.unsetenv("KARTPAD_RENDERER_CONST_PNMTX")
        else Os.setenv("KARTPAD_RENDERER_CONST_PNMTX", value, true)
        // Automatic leaves the choice to the renderer; the other modes pin it explicitly.
        if (active.repack.isEmpty()) Os.unsetenv("KARTPAD_RENDERER_VERTEX_REPACK")
        else Os.setenv("KARTPAD_RENDERER_VERTEX_REPACK", active.repack, true)
        if (active.uniforms.isEmpty()) Os.unsetenv("KARTPAD_RENDERER_NATIVE_UNIFORMS")
        else Os.setenv("KARTPAD_RENDERER_NATIVE_UNIFORMS", active.uniforms, true)
        if (active.rows.isEmpty()) Os.unsetenv("KARTPAD_RENDERER_MATRIX_ROWS")
        else Os.setenv("KARTPAD_RENDERER_MATRIX_ROWS", active.rows, true)
        configured = true
    }
}
