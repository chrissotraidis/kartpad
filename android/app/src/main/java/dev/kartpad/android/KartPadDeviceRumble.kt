package dev.kartpad.android

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Vibrates the device for player one when the game rumbles a controller that has no motor of its
 * own, such as a handheld's built-in controls (Dolphin does the same). The runtime calls
 * [setActive] from the game thread on each start/stop change and returns at once; the vibrator
 * service is called on a separate thread, in order. KartPadActivity pauses it in the background.
 */
object KartPadDeviceRumble {
    // The Wii Remote motor is on/off and the game always sends Stop. This
    // bound matches SDL's controller pulses and limits a missed Stop.
    private const val MAX_PULSE_MS = 5_000L

    private val worker by lazy { Handler(HandlerThread("KartPadRumble").apply { start() }.looper) }
    private var vibrator: Vibrator? = null
    private var paused = true
    private var active = false
    private var enabled = true
    private var strengthPercent = 100

    @Synchronized
    fun attach(context: Context) {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            context.getSystemService(Vibrator::class.java)
        }?.takeIf { it.hasVibrator() }
    }

    @Synchronized
    fun setPaused(value: Boolean) {
        paused = value
        if (value) worker.post { update(false) }
    }

    fun configure(enabled: Boolean, strengthPercent: Int) {
        worker.post {
            synchronized(this) {
                this.enabled = enabled
                this.strengthPercent = strengthPercent.coerceIn(0, 200)
                if (active) update(true)
            }
        }
    }

    @JvmStatic
    fun setActive(value: Boolean) {
        worker.post { update(value) }
    }

    @Synchronized
    private fun update(value: Boolean) {
        if (!value || paused || !enabled || strengthPercent == 0) {
            stop()
            return
        }
        val target = vibrator ?: return
        // Adjustable motors use one consistent scale, with midpoint amplitude at
        // 100% and full amplitude at 200%. The device default is not always 128.
        val amplitude = if (!target.hasAmplitudeControl()) {
            VibrationEffect.DEFAULT_AMPLITUDE
        } else {
            (128 * strengthPercent / 100).coerceIn(1, 255)
        }
        val effect = VibrationEffect.createOneShot(MAX_PULSE_MS, amplitude)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            target.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_MEDIA))
        } else {
            target.vibrate(effect)
        }
        active = true
    }

    private fun stop() {
        if (!active) return
        active = false
        vibrator?.cancel()
    }
}
