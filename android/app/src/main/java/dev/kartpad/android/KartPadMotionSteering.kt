package dev.kartpad.android

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.util.Log
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.sign
import kotlin.math.sqrt

/** Gravity-based steering with the same calibration curve as KartPad on iOS. */
internal class KartPadMotionSteering(
    context: Context,
    private val onShakeTrick: () -> Unit,
    private val onSteeringChanged: (Float) -> Unit,
) : SensorEventListener {
    private val applicationContext = context.applicationContext
    private val sensorManager = context.getSystemService(SensorManager::class.java)
    private val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)
        ?: sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val shakeSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
    private val shakeDetector = KartPadShakeDetector()
    private var shakeRegistered = false
    private var registered = false
    private var calibrated = false
    private var lastAngle = Double.NaN
    private var centerAngle = 0.0
    private var lastLoggedBucket = Int.MIN_VALUE

    val sensorAvailable: Boolean get() = sensor != null
    val shakeSensorAvailable: Boolean get() = shakeSensor != null
    val shakeTricksEnabled: Boolean get() = KartPadTouchSettings.shakeTricksEnabled(applicationContext)

    fun setShakeTricksEnabled(value: Boolean) {
        KartPadTouchSettings.setShakeTricksEnabled(applicationContext, value)
        stop()
        start()
    }
    val enabled: Boolean get() = KartPadTouchSettings.motionEnabled(applicationContext)
    val inverted: Boolean get() = KartPadTouchSettings.motionInverted(applicationContext)
    val sensitivity: Float get() = KartPadTouchSettings.motionSensitivity(applicationContext)

    fun setEnabled(value: Boolean) {
        KartPadTouchSettings.setMotionEnabled(applicationContext, value)
        stop()
        start()
        Log.i(TAG, "enabled=$value sensor=$sensorAvailable")
    }

    fun setInverted(value: Boolean) {
        KartPadTouchSettings.setMotionInverted(applicationContext, value)
        publishCurrentAngle()
    }

    fun setSensitivity(value: Float) {
        KartPadTouchSettings.setMotionSensitivity(applicationContext, value)
        publishCurrentAngle()
    }

    fun start() {
        if (shakeTricksEnabled && !shakeRegistered && shakeSensor != null) {
            shakeDetector.reset()
            shakeRegistered = sensorManager.registerListener(
                this, shakeSensor, SensorManager.SENSOR_DELAY_GAME,
            )
        }
        if (!enabled || registered) return
        val availableSensor = sensor ?: return
        calibrated = false
        onSteeringChanged(0f)
        registered = sensorManager.registerListener(
            this, availableSensor, SensorManager.SENSOR_DELAY_GAME,
        )
        Log.i(TAG, "started registered=$registered type=${availableSensor.type}")
    }

    fun stop() {
        sensorManager.unregisterListener(this)
        registered = false
        shakeRegistered = false
        shakeDetector.reset()
        calibrated = false
        onSteeringChanged(0f)
        Log.i(TAG, "stopped")
    }

    fun recenter() {
        if (!lastAngle.isFinite()) return
        centerAngle = lastAngle
        calibrated = true
        onSteeringChanged(0f)
        Log.i(TAG, "recentered angle=$centerAngle")
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_LINEAR_ACCELERATION) {
            if (!shakeRegistered || !shakeTricksEnabled || event.values.size < 3) return
            val x = event.values[0].toDouble()
            val y = event.values[1].toDouble()
            val z = event.values[2].toDouble()
            val magnitude = sqrt(x * x + y * y + z * z) / SensorManager.GRAVITY_EARTH
            if (shakeDetector.sample(magnitude, event.timestamp / 1e9)) onShakeTrick()
            return
        }
        if (!registered || !enabled) return
        val x = event.values.getOrElse(0) { 0f }
        val y = event.values.getOrElse(1) { 0f }
        if (hypot(x.toDouble(), y.toDouble()) < 0.08) return
        lastAngle = atan2(y.toDouble(), x.toDouble())
        if (!calibrated) {
            centerAngle = lastAngle
            calibrated = true
        }
        publishCurrentAngle()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun publishCurrentAngle() {
        if (!enabled || !calibrated || !lastAngle.isFinite()) {
            onSteeringChanged(0f)
            return
        }
        val value = steeringValue(lastAngle, centerAngle, sensitivity, inverted)
        onSteeringChanged(value)
        val bucket = (value * 10f).toInt()
        if (BuildConfig.DEBUG && bucket != lastLoggedBucket) {
            lastLoggedBucket = bucket
            Log.d(TAG, "steering=$value")
        }
    }

    companion object {
        private const val TAG = "KartPadMotion"
        private const val DEAD_ZONE = 0.045

        internal fun steeringValue(
            angle: Double,
            center: Double,
            sensitivity: Float,
            inverted: Boolean,
        ): Float {
            if (!angle.isFinite() || !center.isFinite()) return 0f
            val boundedSensitivity = sensitivity.coerceIn(0.5f, 2f)
            var delta = angle - center
            while (delta > PI) delta -= 2.0 * PI
            while (delta < -PI) delta += 2.0 * PI
            val magnitude = abs(delta)
            if (magnitude <= DEAD_ZONE) return 0f
            val fullLock = 0.70 / boundedSensitivity
            var value = ((magnitude - DEAD_ZONE) / (fullLock - DEAD_ZONE))
                .coerceAtMost(1.0) * delta.sign
            if (inverted) value = -value
            return value.toFloat()
        }
    }
}
