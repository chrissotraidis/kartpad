package dev.kartpad.android

/**
 * What KartPad suggests for this phone's GPU, from what players' logs have shown (docs/KNOWN-ISSUES.md,
 * #104, #301, #304). Plain Kotlin with no Android types, so the rules are tested on the host
 * (tests/test_android_phone_advice.py). The GPU name and driver version come from
 * KartPadPhoneAdviceDialog's probe.
 */
internal object KartPadPhoneAdvice {
    /** OpenGL ES renderer and version strings, e.g. "Adreno (TM) 650" and "OpenGL ES 3.2 V@0762.36 (GIT@…)". */
    data class Gpu(val renderer: String, val version: String)

    enum class Action { NONE, GET_DRIVER }

    data class Advice(val gpuLabel: String, val summary: String, val points: List<String>, val action: Action)

    private val speedTips = listOf(
        "If races slow down: turn on 30 FPS Races and Simpler Computer Karts, and keep Render Resolution at 1×. Lower resolutions rarely help, because the game waits on the processor, not the GPU.",
    )

    /** "Adreno (TM) 650" -> 650; null for any other GPU. */
    fun adrenoModel(renderer: String): Int? =
        Regex("""Adreno[^0-9]*(\d{3})""").find(renderer)?.groupValues?.get(1)?.toIntOrNull()

    /** Qualcomm's driver build from the GL version: "V@0762.36" -> 762 (Vulkan 512.762). Null otherwise. */
    fun qualcommBuild(version: String): Int? =
        Regex("""V@0*(\d+)\.\d+""").find(version)?.groupValues?.get(1)?.toIntOrNull()

    fun advise(gpu: Gpu?, customDriver: String?): Advice {
        if (gpu == null) {
            return Advice("Unknown GPU", "KartPad couldn't read this phone's GPU.", speedTips, Action.NONE)
        }
        val renderer = gpu.renderer
        val adreno = adrenoModel(renderer)
        val build = if (adreno != null) qualcommBuild(gpu.version) else null
        val label = when {
            adreno != null && build != null -> "Adreno $adreno · Qualcomm driver 512.$build"
            adreno != null -> "Adreno $adreno"
            else -> renderer.trim().ifBlank { "Unknown GPU" }
        }
        val custom = customDriver?.let {
            listOf("You're using $it. If the picture or speed got worse with it, choose Phone's Driver in GPU Driver.")
        }.orEmpty()
        return when {
            adreno != null && adreno >= 800 -> Advice(label,
                "Keep the phone's driver. Automatic already handles this GPU's known graphics fault.",
                custom + listOf(
                    "Custom drivers for Adreno 8xx are early betas, and none has been confirmed with KartPad yet.",
                    "If karts or item boxes go missing in Retro Rewind, choose Experimental: fix broken characters in Graphics Diagnostics.",
                ) + speedTips, Action.NONE)
            adreno != null && adreno >= 600 && build == 762 -> Advice(label,
                "Install Turnip. This Qualcomm driver (512.762) is the one that leaves characters missing, white or washed out, and Turnip fixed it on every phone that tried it.",
                custom + listOf(
                    "Get a Driver opens GPU Driver: tap Add Driver…, then Download a Driver…, and pick a recent Turnip release.",
                    "Not every Turnip build works on every phone. If one freezes or breaks the picture, KartPad goes back to the phone's driver at the next start; try another build.",
                    "Stay on the Classic graphics engine with a custom driver.",
                ) + speedTips, Action.GET_DRIVER)
            adreno != null && adreno >= 600 -> Advice(label,
                "The phone's driver should work. No graphics faults have been reported on this driver.",
                custom + listOf(
                    "Try Turnip only if characters are missing or white: GPU Driver → Add Driver… → Download a Driver…. It can be slower than the phone's driver.",
                ) + speedTips, Action.NONE)
            adreno != null -> Advice(label,
                "Use the phone's driver. Custom drivers don't exist for Adreno 5xx and older.",
                custom + speedTips, Action.NONE)
            renderer.contains("PowerVR", ignoreCase = true) -> Advice(label,
                "Use the phone's driver; Android only lets apps replace Snapdragon drivers.",
                listOf("On PowerVR GPUs the 3D scene can break up. The cause isn't found yet (#304 on GitHub).") + speedTips,
                Action.NONE)
            else -> Advice(label,
                "Use the phone's driver; Android only lets apps replace Snapdragon (Adreno) drivers.",
                speedTips, Action.NONE)
        }
    }
}
