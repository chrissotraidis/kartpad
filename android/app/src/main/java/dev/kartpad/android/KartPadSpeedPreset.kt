package dev.kartpad.android

/**
 * The Speed choice in Speed & Graphics (docs/SETTINGS.md), the same three presets as on iPhone and
 * iPad. A preset only sets 30 FPS Races and Simpler Computer Karts, so nothing new is stored: the
 * Speed row shows the preset those two switches match, or Custom. Best Quality is the default.
 */
internal enum class KartPadSpeedPreset(
    val label: String,
    val description: String,
    val thirtyFpsRaces: Boolean,
    val simplerComputerKarts: Boolean,
) {
    SMOOTHEST("Smoothest", "30 FPS races and simpler computer karts. For phones that slow down in races.", true, true),
    BALANCED("Balanced", "60 FPS races with simpler computer karts.", false, true),
    BEST_QUALITY("Best Quality", "60 FPS races with full-detail computer karts.", false, false);

    companion object {
        const val CUSTOM_LABEL = "Custom"

        fun matching(thirtyFpsRaces: Boolean, simplerComputerKarts: Boolean): KartPadSpeedPreset? =
            entries.firstOrNull { it.thirtyFpsRaces == thirtyFpsRaces && it.simplerComputerKarts == simplerComputerKarts }
    }
}
