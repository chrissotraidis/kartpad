package dev.kartpad.android

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/** Canvas-owned gameplay controls using KartPad's accepted phone geometry. */
class KartPadOverlayView(context: Context) : View(context) {
    private enum class Kind { BUTTON, LEFT_STICK, RIGHT_STICK }

    private data class Control(
        val id: String,
        val label: String,
        val kind: Kind,
        val mask: Int = 0,
        val centerX: Float = 0f,
        val centerY: Float = 0f,
        val width: Float,
        val height: Float,
        val fill: Int,
        val darkText: Boolean = false,
        val frame: RectF = RectF(),
    )

    private val controls = mutableListOf<Control>()
    private val pointerOwners = mutableMapOf<Int, String>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(2f)
        color = Color.argb(120, 255, 255, 255)
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        typeface = android.graphics.Typeface.DEFAULT_BOLD
    }
    private var insetLeft = 0
    private var insetTop = 0
    private var insetRight = 0
    private var insetBottom = 0
    private var leftX = 0f
    private var leftY = 0f
    private var rightX = 0f
    private var rightY = 0f
    private var gasHoldGeneration = 0
    private var gasLocked = false
    private var hiddenForController = false

    init {
        setWillNotDraw(false)
        isFocusable = true
        isHapticFeedbackEnabled = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
        contentDescription = "KartPad touch controls"
        buildControls()
    }

    @Suppress("DEPRECATION")
    override fun onApplyWindowInsets(insets: WindowInsets): WindowInsets {
        insetLeft = insets.systemWindowInsetLeft
        insetTop = insets.systemWindowInsetTop
        insetRight = insets.systemWindowInsetRight
        insetBottom = insets.systemWindowInsetBottom
        requestLayout()
        invalidate()
        return super.onApplyWindowInsets(insets)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        publishState(connected = true)
    }

    override fun onDetachedFromWindow() {
        clearTouchInput()
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        layoutControls()
        controls.forEach { control ->
            when (control.kind) {
                Kind.BUTTON -> drawButton(canvas, control)
                Kind.LEFT_STICK -> drawStick(canvas, control, leftX, leftY)
                Kind.RIGHT_STICK -> drawStick(canvas, control, rightX, rightY)
            }
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val actionIndex = event.actionIndex
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN,
            MotionEvent.ACTION_POINTER_DOWN -> {
                val pointerId = event.getPointerId(actionIndex)
                val control = hitTest(event.getX(actionIndex), event.getY(actionIndex))
                if (control == null) {
                    return event.actionMasked != MotionEvent.ACTION_DOWN && pointerOwners.isNotEmpty()
                }
                pointerOwners[pointerId] = control.id
                if (control.id == "A") beginGasPress()
                updateOwnedControl(control, event.getX(actionIndex), event.getY(actionIndex))
            }
            MotionEvent.ACTION_MOVE -> {
                for (index in 0 until event.pointerCount) {
                    val owner = pointerOwners[event.getPointerId(index)] ?: continue
                    controls.firstOrNull { it.id == owner }?.let {
                        updateOwnedControl(it, event.getX(index), event.getY(index))
                    }
                }
            }
            MotionEvent.ACTION_UP,
            MotionEvent.ACTION_POINTER_UP -> {
                releasePointer(event.getPointerId(actionIndex))
                if (event.actionMasked == MotionEvent.ACTION_UP) performClick()
            }
            MotionEvent.ACTION_CANCEL -> clearTouchInput()
            else -> return pointerOwners.isNotEmpty()
        }
        publishState(connected = true)
        invalidate()
        return true
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    fun clearTouchInput() {
        pointerOwners.clear()
        leftX = 0f
        leftY = 0f
        rightX = 0f
        rightY = 0f
        gasLocked = false
        gasHoldGeneration += 1
        updateGasAccessibility()
        nativeClearTouchState()
        invalidate()
    }

    fun setHiddenForController(hidden: Boolean) {
        if (hiddenForController == hidden) return
        hiddenForController = hidden
        if (hidden) {
            clearTouchInput()
            visibility = INVISIBLE
        } else {
            visibility = VISIBLE
            publishState(connected = true)
            invalidate()
        }
    }

    private fun buildControls() {
        val dark = Color.argb(225, 56, 56, 56)
        controls += Control("move", "", Kind.LEFT_STICK, width = 126f, height = 126f,
            centerX = 0.12347222f, centerY = 0.7803491f, fill = Color.argb(220, 33, 33, 33))
        controls += Control("c", "", Kind.RIGHT_STICK, width = 86f, height = 86f,
            centerX = 0.9233056f, centerY = 0.81300676f,
            fill = Color.argb(230, 232, 168, 20))
        controls += button("A", "A", BUTTON_A, 78f, 78f, 0f, 0f,
            Color.argb(235, 20, 143, 74))
        controls += button("B", "B", BUTTON_B, 67.19f, 67.19f,
            0.8398611f, 0.6898649f, Color.argb(235, 199, 26, 33))
        controls += button("X", "X", BUTTON_X, 46f, 46f,
            0.9034167f, 0.4258446f, Color.argb(235, 184, 184, 184), true)
        controls += button("Y", "Y", BUTTON_Y, 46f, 46f,
            0.84525f, 0.5268581f, Color.argb(235, 184, 184, 184), true)
        controls += button("L", "L", BUTTON_L, 94f, 46f,
            0.09058333f, 0.25399774f, dark)
        controls += button("R", "R", BUTTON_R, 94f, 46f,
            0.86875f, 0.27291667f, dark)
        controls += button("Z", "Z", BUTTON_ZR, 46f, 46f,
            0.97125f, 0.43507883f, Color.argb(240, 97, 46, 148))
        controls += button("Start", "START", BUTTON_PLUS, 92f, 46f,
            0.09022222f, 0.11289414f, Color.argb(235, 71, 71, 71))

        val dpadX = 0.08127778f
        val dpadY = 0.46773648f
        controls += button("DpadUp", "▲", BUTTON_UP, 36f, 36f,
            dpadX, dpadY, dark)
        controls += button("DpadDown", "▼", BUTTON_DOWN, 36f, 36f,
            dpadX, dpadY, dark)
        controls += button("DpadLeft", "◀", BUTTON_LEFT, 36f, 36f,
            dpadX, dpadY, dark)
        controls += button("DpadRight", "▶", BUTTON_RIGHT, 36f, 36f,
            dpadX, dpadY, dark)
    }

    private fun button(
        id: String, label: String, mask: Int, width: Float, height: Float,
        centerX: Float, centerY: Float, fill: Int, darkText: Boolean = false,
    ) = Control(id, label, Kind.BUTTON, mask, centerX, centerY, width, height, fill, darkText)

    private fun layoutControls() {
        val safe = RectF(
            insetLeft.toFloat(), insetTop.toFloat(),
            max(insetLeft.toFloat(), width - insetRight.toFloat()),
            max(insetTop.toFloat(), height - insetBottom.toFloat()),
        )
        val baseScale = min(1f, min(safe.width() / dp(800f), safe.height() / dp(380f)))
        controls.forEach { control ->
            val controlWidth = dp(control.width) * baseScale
            val controlHeight = dp(control.height) * baseScale
            val centerX: Float
            val centerY: Float
            if (control.id == "A") {
                val margin = max(dp(8f), dp(18f) * baseScale)
                val camera = dp(86f) * baseScale
                centerX = safe.right - margin - controlWidth * 0.5f
                centerY = safe.bottom - margin - camera - controlHeight * 0.5f - dp(18f) * baseScale
            } else {
                centerX = safe.left + control.centerX * safe.width()
                centerY = safe.top + control.centerY * safe.height()
            }
            val dpadCell = dp(36f) * baseScale
            val adjustedCenterX = centerX + when (control.id) {
                "DpadLeft" -> -dpadCell
                "DpadRight" -> dpadCell
                else -> 0f
            }
            val adjustedCenterY = centerY + when (control.id) {
                "DpadUp" -> -dpadCell
                "DpadDown" -> dpadCell
                else -> 0f
            }
            control.frame.set(
                adjustedCenterX - controlWidth * 0.5f,
                adjustedCenterY - controlHeight * 0.5f,
                adjustedCenterX + controlWidth * 0.5f,
                adjustedCenterY + controlHeight * 0.5f,
            )
        }
    }

    private fun drawButton(canvas: Canvas, control: Control) {
        val active = pointerOwners.containsValue(control.id)
        fillPaint.style = Paint.Style.FILL
        fillPaint.color = when {
            control.id == "A" && gasLocked -> LOCKED_GAS_COLOR
            active -> brighten(control.fill)
            else -> control.fill
        }
        val radius = min(control.frame.width(), control.frame.height()) * 0.5f
        canvas.drawRoundRect(control.frame, radius, radius, fillPaint)
        canvas.drawRoundRect(control.frame, radius, radius, strokePaint)
        textPaint.color = if (control.darkText) Color.rgb(31, 31, 31) else Color.WHITE
        textPaint.textSize = min(control.frame.height() * 0.39f, dp(18f))
        val metrics = textPaint.fontMetrics
        val baseline = control.frame.centerY() - (metrics.ascent + metrics.descent) * 0.5f
        canvas.drawText(control.label, control.frame.centerX(), baseline, textPaint)
    }

    private fun drawStick(canvas: Canvas, control: Control, axisX: Float, axisY: Float) {
        val radius = min(control.frame.width(), control.frame.height()) * 0.5f
        fillPaint.style = Paint.Style.FILL
        fillPaint.color = control.fill
        canvas.drawCircle(control.frame.centerX(), control.frame.centerY(), radius, fillPaint)
        canvas.drawCircle(control.frame.centerX(), control.frame.centerY(), radius, strokePaint)
        val thumbRadius = radius * 0.42f
        val travel = max(0f, radius - thumbRadius - dp(4f))
        fillPaint.color = if (control.kind == Kind.LEFT_STICK) {
            Color.argb(240, 148, 148, 148)
        } else {
            Color.argb(250, 255, 214, 64)
        }
        canvas.drawCircle(
            control.frame.centerX() + axisX * travel,
            control.frame.centerY() - axisY * travel,
            thumbRadius, fillPaint,
        )
    }

    private fun hitTest(x: Float, y: Float): Control? = controls.asReversed().firstOrNull {
        if (!it.frame.contains(x, y)) return@firstOrNull false
        if (it.kind == Kind.BUTTON && it.frame.width() != it.frame.height()) return@firstOrNull true
        val radius = min(it.frame.width(), it.frame.height()) * 0.5f
        hypot((x - it.frame.centerX()).toDouble(), (y - it.frame.centerY()).toDouble()) <= radius
    }

    private fun updateOwnedControl(control: Control, x: Float, y: Float) {
        if (control.kind == Kind.BUTTON) return
        val radius = max(1f, min(control.frame.width(), control.frame.height()) * 0.5f)
        var axisX = (x - control.frame.centerX()) / radius
        var axisY = -(y - control.frame.centerY()) / radius
        val length = hypot(axisX.toDouble(), axisY.toDouble()).toFloat()
        if (length > 1f) {
            axisX /= length
            axisY /= length
        }
        if (control.kind == Kind.LEFT_STICK) {
            leftX = axisX
            leftY = axisY
        } else {
            rightX = axisX
            rightY = axisY
        }
    }

    private fun releasePointer(pointerId: Int) {
        val owner = pointerOwners.remove(pointerId) ?: return
        if (owner == "A") gasHoldGeneration += 1
        when (controls.firstOrNull { it.id == owner }?.kind) {
            Kind.LEFT_STICK -> { leftX = 0f; leftY = 0f }
            Kind.RIGHT_STICK -> { rightX = 0f; rightY = 0f }
            else -> Unit
        }
    }

    private fun publishState(connected: Boolean) {
        var buttons = if (gasLocked) BUTTON_A else 0
        pointerOwners.values.forEach { owner ->
            buttons = buttons or (controls.firstOrNull { it.id == owner }?.mask ?: 0)
        }
        nativePublishTouchState(buttons, leftX, leftY, rightX, rightY, connected)
    }

    private fun beginGasPress() {
        gasHoldGeneration += 1
        if (gasLocked) {
            gasLocked = false
            updateGasAccessibility()
            return
        }
        val generation = gasHoldGeneration
        mainHandler.postDelayed({
            if (generation != gasHoldGeneration ||
                !pointerOwners.containsValue("A")) return@postDelayed
            gasLocked = true
            updateGasAccessibility()
            performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
            publishState(connected = true)
            invalidate()
        }, GAS_LOCK_DELAY_MS)
    }

    private fun updateGasAccessibility() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            stateDescription = if (gasLocked) "Acceleration locked" else null
        }
    }

    private fun brighten(color: Int): Int = Color.argb(
        Color.alpha(color), min(255, Color.red(color) + 34),
        min(255, Color.green(color) + 34), min(255, Color.blue(color) + 34),
    )

    private fun dp(value: Float): Float = value * resources.displayMetrics.density

    private external fun nativePublishTouchState(
        buttons: Int, leftX: Float, leftY: Float, rightX: Float, rightY: Float,
        connected: Boolean,
    )

    private external fun nativeClearTouchState()

    private companion object {
        const val GAS_LOCK_DELAY_MS = 1_000L
        val LOCKED_GAS_COLOR: Int = Color.argb(250, 15, 199, 235)
        const val BUTTON_UP = 0x00000001
        const val BUTTON_LEFT = 0x00000002
        const val BUTTON_ZR = 0x00000004
        const val BUTTON_X = 0x00000008
        const val BUTTON_A = 0x00000010
        const val BUTTON_Y = 0x00000020
        const val BUTTON_B = 0x00000040
        const val BUTTON_R = 0x00000200
        const val BUTTON_PLUS = 0x00000400
        const val BUTTON_L = 0x00002000
        const val BUTTON_DOWN = 0x00004000
        const val BUTTON_RIGHT = 0x00008000
    }
}
