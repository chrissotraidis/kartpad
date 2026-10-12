package dev.kartpad.android

import android.content.Context
import android.util.AtomicFile
import java.io.File
import java.util.Locale

/**
 * Optional music and game-sound levels (#411). Off by default, which plays both at full volume,
 * exactly as before. When on, music and game sounds (effects, voices, menus) each have a level,
 * so a player can mute only the music or the whole game.
 */
internal object KartPadSoundSettings {
    private const val PREFERENCES = "kartpad_sound"
    private const val ENABLED = "custom_levels"
    private const val MUSIC = "music_percent"
    private const val SOUNDS = "sounds_percent"

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    fun enabled(context: Context): Boolean = preferences(context).getBoolean(ENABLED, false)

    fun musicPercent(context: Context): Int = preferences(context).getInt(MUSIC, 100).coerceIn(0, 100)

    fun soundsPercent(context: Context): Int = preferences(context).getInt(SOUNDS, 100).coerceIn(0, 100)

    fun set(context: Context, enabled: Boolean, musicPercent: Int, soundsPercent: Int) {
        preferences(context).edit()
            .putBoolean(ENABLED, enabled)
            .putInt(MUSIC, musicPercent.coerceIn(0, 100))
            .putInt(SOUNDS, soundsPercent.coerceIn(0, 100))
            .apply()
    }

    /** The levels the game should play at now, 0 to 1: full volume unless the toggle is on. */
    fun effective(context: Context): Pair<Float, Float> =
        if (enabled(context)) musicPercent(context) / 100f to soundsPercent(context) / 100f else 1f to 1f

    /**
     * Saves the levels in Config.toml's [audio] table, which the runtime applies at every start.
     * Game sounds cover the runtime's effects, voices and menu categories together.
     */
    fun persist(filesDirectory: File, music: Float, sounds: Float) {
        val configFile = filesDirectory.resolve("KartPad/Config.toml")
        configFile.parentFile?.mkdirs()
        val original = if (configFile.isFile) configFile.readText() else ""
        val updated = withAudioLevels(original, music, sounds)
        if (updated == original) return
        val atomic = AtomicFile(configFile)
        val output = atomic.startWrite()
        try {
            output.write(updated.toByteArray(Charsets.UTF_8))
            atomic.finishWrite(output)
        } catch (error: Throwable) {
            atomic.failWrite(output)
            throw error
        }
    }

    internal fun withAudioLevels(config: String, music: Float, sounds: Float): String {
        var result = config
        for ((key, value) in listOf(
            "music_volume" to music,
            "sound_effects_volume" to sounds,
            "voices_volume" to sounds,
            "ui_volume" to sounds,
        )) {
            result = withAudioKey(result, key, String.format(Locale.ROOT, "%.2f", value.coerceIn(0f, 1f)))
        }
        return result
    }

    private fun withAudioKey(config: String, key: String, value: String): String {
        val line = Regex("(?m)^[\\t ]*#?[\\t ]*${Regex.escape(key)}[\\t ]*=.*$")
        if (line.containsMatchIn(config)) return config.replace(line, "$key = $value")
        val audio = Regex("(?m)^[\\t ]*\\[audio][\\t ]*$").find(config)
        return if (audio != null) {
            config.substring(0, audio.range.last + 1) + "\n$key = $value" + config.substring(audio.range.last + 1)
        } else {
            config.trimEnd() + "\n\n[audio]\n$key = $value\n"
        }
    }
}
