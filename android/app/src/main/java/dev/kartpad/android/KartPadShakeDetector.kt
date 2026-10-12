package dev.kartpad.android

/** Gravity-free acceleration in g, matching the iPhone/iPad shake gesture. */
internal class KartPadShakeDetector {
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
        if (!armed || magnitude < 1.35) return false
        armed = false
        if (seconds - lastTrigger < 0.45) return false
        lastTrigger = seconds
        return true
    }
}
