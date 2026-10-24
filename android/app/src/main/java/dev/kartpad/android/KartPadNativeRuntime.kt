package dev.kartpad.android

import android.content.Context
import android.util.AtomicFile
import java.io.File
import java.io.IOException

/**
 * Chooses which game runtime this process loads. Both runtimes are the same KartPad code; they
 * differ only in the graphics layer (Aurora). Classic has every KartPad graphics fix, including
 * the Adreno workarounds. WiiCompiled uses the renderer from WiiCompiled 0.9.
 *
 * Both files keep the shared-object name libmain.so, so the game pack links to whichever one
 * is loaded. A process must load exactly one of them: every load goes through this object.
 * The choice is a file, read fresh, because the chooser and the game run in different processes.
 */
object KartPadNativeRuntime {
    const val CLASSIC = "classic"
    const val WIICOMPILED = "wiicompiled"
    val engines = arrayOf(CLASSIC, WIICOMPILED)
    val labels = arrayOf("Classic", "WiiCompiled 0.9 (Beta)")

    @Volatile
    private var loadedLibrary: String? = null

    fun isAvailable(): Boolean = BuildConfig.WIICOMPILED_RUNTIME

    private fun file(filesDir: File) = AtomicFile(File(filesDir, "KartPad/GraphicsEngine"))

    fun engine(filesDir: File): String {
        if (!isAvailable()) return CLASSIC
        return runCatching {
            file(filesDir).openRead().use { stream ->
                val bytes = ByteArray(32)
                val count = stream.read(bytes)
                if (count < 0) CLASSIC else String(bytes, 0, count, Charsets.UTF_8).takeIf { it in engines } ?: CLASSIC
            }
        }.getOrDefault(CLASSIC)
    }

    fun label(filesDir: File): String = labels[engines.indexOf(engine(filesDir))]

    /** Takes effect the next time the game runtime starts. */
    fun setEngine(filesDir: File, engine: String) {
        require(engine in engines)
        val destination = file(filesDir)
        destination.baseFile.parentFile?.mkdirs()
        val output = destination.startWrite()
        try {
            output.write(engine.toByteArray(Charsets.UTF_8))
            destination.finishWrite(output)
        } catch (error: Throwable) {
            destination.failWrite(output)
            throw error
        }
        // AtomicFile may log publication failures instead of throwing them.
        if (engine(filesDir) != engine) throw IOException("Graphics engine could not be saved")
    }

    /** The library SDL loads for this process, recorded so later loads reuse it. */
    fun libraryFor(context: Context): String {
        loadedLibrary?.let { return it }
        val library = if (engine(context.filesDir) == WIICOMPILED) "main_wiicompiled" else "main"
        loadedLibrary = library
        return library
    }

    /** For code that needs the runtime's JNI functions outside the game Activity. */
    @JvmStatic
    fun ensureLoaded() {
        val library = loadedLibrary ?: "main".also { loadedLibrary = it }
        System.loadLibrary(library)
    }
}
