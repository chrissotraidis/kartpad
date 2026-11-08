package dev.kartpad.android

/** Gravity-free acceleration in g, matching the iPhone/iPad shake gesture. */
internal class KartPadShakeDetector {
    /** The shake, in g, that counts as a trick; set from [LEVELS]. */
    var triggerAcceleration = LEVELS[DEFAULT_LEVEL]
    private var armed = false
    private var lastTrigger = Double.NEGATIVE_INFINITY

    fun reset() {
        armed = false
        lastTrigger = Double.NEGATIVE_INFINITY
    }

    fun sample(magnitude: Double, seconds: Double): Boolean {
        if (!magnitude.isFinite() || magnitude < 0 || !seconds.isFinite()) return false
        if (magnitude <= 0.35) {
            armed = true
            return false
        }
        if (!armed || magnitude < triggerAcceleration) return false
        armed = false
        if (seconds - lastTrigger < 0.45) return false
        lastTrigger = seconds
        return true
    }

    companion object {
        /** Shake Sensitivity: Low, Standard, High, Very High. Same values on iPhone and iPad. */
        val LEVELS = doubleArrayOf(1.6, 1.35, 1.0, 0.75)
        val NAMES = arrayOf("Low", "Standard", "High", "Very High")
        const val DEFAULT_LEVEL = 1
    }
}
