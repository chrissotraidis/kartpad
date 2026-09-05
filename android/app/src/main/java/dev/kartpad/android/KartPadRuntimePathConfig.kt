package dev.kartpad.android

import android.util.AtomicFile
import java.io.File

/** Owns durable relative paths from the Android shell to app-private runtime data. */
internal object KartPadRuntimePathConfig {
    fun ensureRetroRewindRoot(filesDirectory: File) {
        val configFile = filesDirectory.resolve("KartPad/Config.toml")
        configFile.parentFile?.mkdirs()
        var config = if (configFile.isFile) configFile.readText() else ""
        val rootLine = Regex("(?m)^\\s*#?\\s*retro_rewind_root\\s*=.*$")
        config = config.replace(rootLine, "")
        val paths = Regex("(?m)^\\s*\\[paths]\\s*$").find(config)
        config = if (paths != null) {
            config.substring(0, paths.range.last + 1) +
                "\nretro_rewind_root = \"RetroRewind/RetroRewind6\"" +
                config.substring(paths.range.last + 1)
        } else {
            config.trimEnd() +
                "\n\n[paths]\nretro_rewind_root = \"RetroRewind/RetroRewind6\"\n"
        }
        val atomic = AtomicFile(configFile)
        val output = atomic.startWrite()
        try {
            output.write(config.toByteArray(Charsets.UTF_8))
            atomic.finishWrite(output)
        } catch (error: Throwable) {
            atomic.failWrite(output)
            throw error
        }
    }
}
