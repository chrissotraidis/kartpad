package dev.kartpad.android

import android.content.Context
import android.graphics.PointF

internal object KartPadTouchSettings {
    const val DEFAULT_OPACITY = 0.82f
    const val DEFAULT_SIZE = 1.0f
    const val MIN_OPACITY = 0.25f
    const val MAX_OPACITY = 1.0f
    const val MIN_SIZE = 0.70f
    const val MAX_SIZE = 1.35f
    const val MIN_CONTROL_SIZE = 0.60f
    const val MAX_CONTROL_SIZE = 1.75f

    private const val PREFERENCES = "kartpad_touch_controls"
    private const val OPACITY = "control_opacity"
    private const val SIZE = "control_size"
    private const val HIDE_ON_CONTROLLER = "hide_on_controller"
    private const val MODERN_C_STICK = "modern_c_stick_horizontal"
    private const val SHOW_FPS = "show_fps"
    private const val ASPECT_MODE = "aspect_mode"
    private const val RESOLUTION_SCALE = "resolution_scale"
    private const val MOTION_ENABLED = "motion_steering_enabled"
    private const val MOTION_INVERTED = "motion_steering_inverted"
    private const val MOTION_SENSITIVITY = "motion_steering_sensitivity"
    private const val HIDDEN_CONTROLS = "hidden_controls"
    private const val ORIGIN_X_PREFIX = "origin_x_"
    private const val ORIGIN_Y_PREFIX = "origin_y_"
    private const val CONTROL_SIZE_PREFIX = "control_size_"

    fun opacity(context: Context): Float = preferences(context)
        .getFloat(OPACITY, DEFAULT_OPACITY)
        .coerceIn(MIN_OPACITY, MAX_OPACITY)

    fun setOpacity(context: Context, value: Float) {
        preferences(context).edit().putFloat(
            OPACITY, value.coerceIn(MIN_OPACITY, MAX_OPACITY),
        ).apply()
    }

    fun size(context: Context): Float = preferences(context)
        .getFloat(SIZE, DEFAULT_SIZE)
        .coerceIn(MIN_SIZE, MAX_SIZE)

    fun setSize(context: Context, value: Float) {
        preferences(context).edit().putFloat(
            SIZE, value.coerceIn(MIN_SIZE, MAX_SIZE),
        ).apply()
    }

    fun hideOnController(context: Context): Boolean = preferences(context)
        .getBoolean(HIDE_ON_CONTROLLER, true)

    fun setHideOnController(context: Context, value: Boolean) {
        preferences(context).edit().putBoolean(HIDE_ON_CONTROLLER, value).apply()
    }

    fun modernCStickHorizontal(context: Context): Boolean = preferences(context)
        .getBoolean(MODERN_C_STICK, false)

    fun setModernCStickHorizontal(context: Context, value: Boolean) {
        preferences(context).edit().putBoolean(MODERN_C_STICK, value).apply()
    }

    fun showFps(context: Context): Boolean = preferences(context)
        .getBoolean(SHOW_FPS, true)

    fun setShowFps(context: Context, value: Boolean) {
        preferences(context).edit().putBoolean(SHOW_FPS, value).apply()
    }

    fun aspectMode(context: Context): Int = preferences(context)
        .getInt(ASPECT_MODE, 0).coerceIn(0, 2)

    fun setAspectMode(context: Context, value: Int) {
        preferences(context).edit().putInt(ASPECT_MODE, value.coerceIn(0, 2)).apply()
    }

    fun resolutionScale(context: Context): Float = preferences(context)
        .getFloat(RESOLUTION_SCALE, 1f).coerceIn(1f, 4f)

    fun setResolutionScale(context: Context, value: Float) {
        preferences(context).edit().putFloat(
            RESOLUTION_SCALE, value.coerceIn(1f, 4f),
        ).apply()
    }

    fun motionEnabled(context: Context): Boolean = preferences(context)
        .getBoolean(MOTION_ENABLED, false)

    fun setMotionEnabled(context: Context, value: Boolean) {
        preferences(context).edit().putBoolean(MOTION_ENABLED, value).apply()
    }

    fun motionInverted(context: Context): Boolean = preferences(context)
        .getBoolean(MOTION_INVERTED, false)

    fun setMotionInverted(context: Context, value: Boolean) {
        preferences(context).edit().putBoolean(MOTION_INVERTED, value).apply()
    }

    fun motionSensitivity(context: Context): Float = preferences(context)
        .getFloat(MOTION_SENSITIVITY, 1f).coerceIn(0.5f, 2f)

    fun setMotionSensitivity(context: Context, value: Float) {
        preferences(context).edit().putFloat(
            MOTION_SENSITIVITY, value.coerceIn(0.5f, 2f),
        ).apply()
    }

    fun origin(context: Context, identifier: String): PointF? {
        val saved = preferences(context)
        val xKey = ORIGIN_X_PREFIX + identifier
        val yKey = ORIGIN_Y_PREFIX + identifier
        if (!saved.contains(xKey) || !saved.contains(yKey)) return null
        return PointF(
            saved.getFloat(xKey, 0.5f).coerceIn(0f, 1f),
            saved.getFloat(yKey, 0.5f).coerceIn(0f, 1f),
        )
    }

    fun setOrigin(context: Context, identifier: String, origin: PointF) {
        preferences(context).edit()
            .putFloat(ORIGIN_X_PREFIX + identifier, origin.x.coerceIn(0f, 1f))
            .putFloat(ORIGIN_Y_PREFIX + identifier, origin.y.coerceIn(0f, 1f))
            .apply()
    }

    fun controlSize(context: Context, identifier: String): Float = preferences(context)
        .getFloat(CONTROL_SIZE_PREFIX + identifier, 1f)
        .coerceIn(MIN_CONTROL_SIZE, MAX_CONTROL_SIZE)

    fun setControlSize(context: Context, identifier: String, value: Float) {
        preferences(context).edit().putFloat(
            CONTROL_SIZE_PREFIX + identifier,
            value.coerceIn(MIN_CONTROL_SIZE, MAX_CONTROL_SIZE),
        ).apply()
    }

    fun isHidden(context: Context, identifier: String): Boolean = preferences(context)
        .getStringSet(HIDDEN_CONTROLS, emptySet())
        ?.contains(identifier) == true

    fun setHidden(context: Context, identifier: String, hidden: Boolean) {
        val saved = preferences(context)
        val values = saved.getStringSet(HIDDEN_CONTROLS, emptySet())
            ?.toMutableSet() ?: mutableSetOf()
        if (hidden) values += identifier else values -= identifier
        saved.edit().putStringSet(HIDDEN_CONTROLS, values).apply()
    }

    fun resetTouchControls(context: Context) {
        val saved = preferences(context)
        saved.edit().apply {
            saved.all.keys.filter { key ->
                key == OPACITY || key == SIZE || key == HIDDEN_CONTROLS ||
                    key.startsWith(ORIGIN_X_PREFIX) || key.startsWith(ORIGIN_Y_PREFIX) ||
                    key.startsWith(CONTROL_SIZE_PREFIX)
            }.forEach(::remove)
        }.apply()
    }

    private fun preferences(context: Context) = context.getSharedPreferences(
        PREFERENCES, Context.MODE_PRIVATE,
    )
}
