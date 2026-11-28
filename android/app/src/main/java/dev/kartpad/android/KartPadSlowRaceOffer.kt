package dev.kartpad.android

import android.content.Context

/**
 * Offers 30 FPS Races and Simpler Computer Karts once, after a race that ran mostly below 50 FPS
 * with 30 FPS Races off (slow-phone plan in docs/TODO.md). KartPadActivity feeds it the runtime's
 * race frame rate every two seconds: -1 outside a race, in Time Trials and in the title demo.
 */
internal class KartPadSlowRaceOffer {
    private var samples = 0
    private var slowSamples = 0
    private var fpsTotal = 0f

    /** The race's average FPS when the race that just ended was slow, otherwise null. */
    fun sample(fps: Float): Float? {
        if (fps >= 0f) {
            samples++
            fpsTotal += fps
            if (fps < SLOW_FPS) slowSamples++
            return null
        }
        val slowRace = samples >= MIN_SAMPLES && slowSamples * 2 > samples
        val average = if (samples > 0) fpsTotal / samples else 0f
        samples = 0
        slowSamples = 0
        fpsTotal = 0f
        return if (slowRace) average else null
    }

    companion object {
        const val POLL_MS = 2_000L
        private const val SLOW_FPS = 50f
        // A minute of racing, so a hitch while a course loads doesn't count as a slow race.
        private const val MIN_SAMPLES = 30

        private fun preferences(context: Context) =
            context.getSharedPreferences("kartpad_speed_offer", Context.MODE_PRIVATE)

        fun offered(context: Context): Boolean = preferences(context).getBoolean("offered", false)

        fun markOffered(context: Context) {
            preferences(context).edit().putBoolean("offered", true).apply()
        }
    }
}

