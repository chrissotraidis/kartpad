package dev.kartpad.android

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.HapticFeedbackConstants
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import android.view.WindowInsets
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityNodeProvider
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/** Canvas-owned gameplay controls using KartPad's accepted phone and tablet geometry. */
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
    private var motionSteeringX = 0f
    private var controllerConnected = false
    private var gasHoldGeneration = 0
    private var gasLocked = false
    private var debugVirtualKeyHapticCount = 0
    private var lastPublishedButtons = 0
    private var accessibilityButtons = 0
    private val accessibilityPulseGenerations = mutableMapOf<String, Int>()
    private var accessibilityFocusId = View.NO_ID
    private var accessibilityHoverId = View.NO_ID
    private val accessibilityManager =
        context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
    private val virtualNodeProvider = TouchAccessibilityNodeProvider()
    private var hiddenForController = false
    private var controlOpacity = KartPadTouchSettings.opacity(context)
    private var controlSizeScale = KartPadTouchSettings.size(context)
    private var modernCStickHorizontal = KartPadTouchSettings.modernCStickHorizontal(context)
    private val customOrigins = mutableMapOf<String, PointF>()
    private var editingLayout = false
    private var selectedControlId: String? = null
    private var editPointerId = MotionEvent.INVALID_POINTER_ID
    private var editLastX = 0f
    private var editLastY = 0f
    var onEditSelectionChanged: ((String?, Float, Boolean) -> Unit)? = null

    init {
        setWillNotDraw(false)
        isFocusable = true
        isHapticFeedbackEnabled = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
        buildControls()
        reloadCustomSettings()
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
            val identifier = editableIdentifier(control)
            val hidden = KartPadTouchSettings.isHidden(context, identifier)
            if (hidden && !editingLayout) return@forEach
            val alpha = when {
                editingLayout && hidden -> 0.35f
                editingLayout -> 1f
                else -> controlOpacity
            }
            val saved = canvas.saveLayerAlpha(
                control.frame,
                (alpha * 255f).roundToInt().coerceIn(0, 255),
            )
            when (control.kind) {
                Kind.BUTTON -> drawButton(canvas, control)
                Kind.LEFT_STICK -> drawStick(canvas, control, leftX, leftY)
                Kind.RIGHT_STICK -> drawStick(canvas, control, rightX, rightY)
            }
            if (editingLayout) drawEditOutline(canvas, control, identifier)
            canvas.restoreToCount(saved)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (editingLayout) return onEditTouchEvent(event)
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

    override fun getAccessibilityNodeProvider(): AccessibilityNodeProvider = virtualNodeProvider

    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        info.className = KartPadOverlayView::class.java.name
        info.contentDescription = null
        info.isFocusable = false
        info.isClickable = false
        visibleAccessibilityControls().forEach { (id, _) -> info.addChild(this, id) }
    }

    override fun dispatchHoverEvent(event: MotionEvent): Boolean {
        if (!accessibilityManager.isEnabled || !accessibilityManager.isTouchExplorationEnabled) {
            return super.dispatchHoverEvent(event)
        }
        when (event.actionMasked) {
            MotionEvent.ACTION_HOVER_ENTER,
            MotionEvent.ACTION_HOVER_MOVE -> updateAccessibilityHover(
                accessibilityControlAt(event.x, event.y)?.first ?: View.NO_ID,
            )
            MotionEvent.ACTION_HOVER_EXIT -> updateAccessibilityHover(View.NO_ID)
        }
        return true
    }

    fun clearTouchInput() {
        pointerOwners.clear()
        leftX = 0f
        leftY = 0f
        rightX = 0f
        rightY = 0f
        accessibilityButtons = 0
        accessibilityPulseGenerations.clear()
        gasLocked = false
        lastPublishedButtons = 0
        gasHoldGeneration += 1
        updateGasAccessibility()
        nativeClearTouchState()
        invalidate()
    }

    fun runDebugMultiPointerFixture(): String {
        check(isLaidOut && width > 0 && height > 0) { "touch overlay is not laid out" }
        val move = controls.first { it.id == "move" }
        val a = controls.first { it.id == "A" }.frame.let { PointF(it.centerX(), it.centerY()) }
        val r = controls.first { it.id == "R" }.frame.let { PointF(it.centerX(), it.centerY()) }
        val z = controls.first { it.id == "Z" }.frame.let { PointF(it.centerX(), it.centerY()) }
        val steer = PointF(
            move.frame.centerX() + move.frame.width() * 0.375f,
            move.frame.centerY(),
        )
        val downTime = SystemClock.uptimeMillis()

        fun dispatch(action: Int, pointers: List<Pair<Int, PointF>>, offset: Long) {
            val properties = Array(pointers.size) { index ->
                MotionEvent.PointerProperties().apply {
                    id = pointers[index].first
                    toolType = MotionEvent.TOOL_TYPE_FINGER
                }
            }
            val coordinates = Array(pointers.size) { index ->
                MotionEvent.PointerCoords().apply {
                    x = pointers[index].second.x
                    y = pointers[index].second.y
                    pressure = 1f
                    size = 1f
                }
            }
            val event = MotionEvent.obtain(
                downTime,
                downTime + offset,
                action,
                pointers.size,
                properties,
                coordinates,
                0,
                0,
                1f,
                1f,
                0,
                0,
                InputDevice.SOURCE_TOUCHSCREEN,
                0,
            )
            try {
                check(onTouchEvent(event)) { "touch overlay rejected debug pointer event" }
            } finally {
                event.recycle()
            }
        }

        clearTouchInput()
        motionSteeringX = 0f
        dispatch(MotionEvent.ACTION_DOWN, listOf(0 to steer), 0)
        check(abs(leftX - 0.75f) < 0.01f && abs(leftY) < 0.01f &&
            lastPublishedButtons == 0
        ) {
            "steering pointer produced axes=($leftX,$leftY) buttons=0x${lastPublishedButtons.toString(16)}"
        }
        dispatch(
            MotionEvent.ACTION_POINTER_DOWN or
                (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT),
            listOf(0 to steer, 1 to a),
            1,
        )
        dispatch(
            MotionEvent.ACTION_POINTER_DOWN or
                (2 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT),
            listOf(0 to steer, 1 to a, 2 to r),
            2,
        )
        dispatch(
            MotionEvent.ACTION_POINTER_DOWN or
                (3 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT),
            listOf(0 to steer, 1 to a, 2 to r, 3 to z),
            3,
        )
        val allButtons = lastPublishedButtons
        check(allButtons == (BUTTON_A or BUTTON_R or BUTTON_ZR) &&
            abs(leftX - 0.75f) < 0.01f
        ) {
            "four-pointer state buttons=0x${allButtons.toString(16)} axes=($leftX,$leftY)"
        }
        dispatch(
            MotionEvent.ACTION_POINTER_UP or
                (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT),
            listOf(0 to steer, 1 to a, 2 to r, 3 to z),
            4,
        )
        val afterA = lastPublishedButtons
        dispatch(
            MotionEvent.ACTION_POINTER_UP or
                (2 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT),
            listOf(0 to steer, 2 to r, 3 to z),
            5,
        )
        val afterZ = lastPublishedButtons
        dispatch(
            MotionEvent.ACTION_POINTER_UP or
                (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT),
            listOf(0 to steer, 2 to r),
            6,
        )
        val steerOnly = lastPublishedButtons
        check(abs(leftX - 0.75f) < 0.01f) { "steering cleared before its pointer lifted" }
        dispatch(MotionEvent.ACTION_UP, listOf(0 to steer), 7)
        val neutral = lastPublishedButtons
        val actual = listOf(allButtons, afterA, afterZ, steerOnly, neutral)
        val expected = listOf(
            BUTTON_A or BUTTON_R or BUTTON_ZR,
            BUTTON_R or BUTTON_ZR,
            BUTTON_R,
            0,
            0,
        )
        check(actual == expected && leftX == 0f && leftY == 0f && pointerOwners.isEmpty()) {
            "multi-pointer states $actual != $expected axes=($leftX,$leftY) " +
                "owners=${pointerOwners.size}"
        }
        clearTouchInput()
        return "steer=0.75 all=0x${allButtons.toString(16)} " +
            "afterA=0x${afterA.toString(16)} afterZ=0x${afterZ.toString(16)} " +
            "steerOnly=0x${steerOnly.toString(16)} neutral=0x${neutral.toString(16)}"
    }

    fun runDebugHitMapFixture(): String {
        check(isLaidOut && width > 0 && height > 0) { "touch overlay is not laid out" }
        clearTouchInput()
        layoutControls()
        controls.forEach { control ->
            val centerHit = hitTest(control.frame.centerX(), control.frame.centerY())
            check(centerHit?.id == control.id) {
                "${control.id} center mapped to ${centerHit?.id}"
            }
            val edgeX = if (control.kind == Kind.BUTTON &&
                control.frame.width() != control.frame.height()
            ) {
                control.frame.left + 1f
            } else {
                control.frame.centerX() + min(control.frame.width(), control.frame.height()) * 0.45f
            }
            val edgeHit = hitTest(edgeX, control.frame.centerY())
            check(edgeHit?.id == control.id) {
                "${control.id} edge mapped to ${edgeHit?.id} at $edgeX,${control.frame.centerY()}"
            }
        }

        val safe = safeFrame()
        val outside = PointF(safe.centerX(), safe.centerY())
        check(hitTest(outside.x, outside.y) == null) {
            "empty-space hit unexpectedly resolved at ${outside.x},${outside.y}"
        }
        val downTime = SystemClock.uptimeMillis()
        val outsideDown = MotionEvent.obtain(
            downTime, downTime, MotionEvent.ACTION_DOWN, outside.x, outside.y, 0,
        ).apply { source = InputDevice.SOURCE_TOUCHSCREEN }
        val consumed = try {
            onTouchEvent(outsideDown)
        } finally {
            outsideDown.recycle()
        }
        check(!consumed && pointerOwners.isEmpty() && lastPublishedButtons == 0) {
            "empty-space down consumed=$consumed owners=${pointerOwners.size} " +
                "buttons=0x${lastPublishedButtons.toString(16)}"
        }
        return "centers=${controls.size} edges=${controls.size} outside=passed"
    }

    fun runDebugAccessibilityActionsFixture(
        onSuccess: (String) -> Unit,
        onFailure: (Throwable) -> Unit,
    ) {
        runCatching {
            check(isLaidOut && width > 0 && height > 0) { "touch overlay is not laid out" }
            clearTouchInput()
            debugVirtualKeyHapticCount = 0
            layoutControls()
            val aId = controls.indexOfFirst { it.id == "A" }
            val bId = controls.indexOfFirst { it.id == "B" }
            val moveId = controls.indexOfFirst { it.id == "move" }
            check(aId >= 0 && bId >= 0 && moveId >= 0)

            val aNode = virtualNodeProvider.createAccessibilityNodeInfo(aId)
                ?: error("A accessibility node missing")
            val moveNode = virtualNodeProvider.createAccessibilityNodeInfo(moveId)
                ?: error("move accessibility node missing")
            check(aNode.contentDescription == "A button" && aNode.isClickable)
            check(aNode.actionList.any { it.id == ACTION_TOGGLE_GAS_LOCK })
            check(moveNode.contentDescription == "Move stick" && !moveNode.isClickable)
            check(moveNode.actionList.any { it.id == ACTION_STICK_RIGHT })
            check(virtualNodeProvider.performAction(
                aId, AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS, null,
            )) { "A accessibility focus was rejected" }
            check(virtualNodeProvider.findFocus(
                AccessibilityNodeInfo.FOCUS_ACCESSIBILITY,
            ) != null) { "A accessibility focus was not retained" }
            check(virtualNodeProvider.performAction(
                bId, AccessibilityNodeInfo.ACTION_CLICK, null,
            )) { "B accessibility click was rejected" }
            check(lastPublishedButtons == BUTTON_B && debugVirtualKeyHapticCount == 1) {
                "B pulse buttons=0x${lastPublishedButtons.toString(16)} " +
                    "haptics=$debugVirtualKeyHapticCount"
            }
            Triple(aId, bId, moveId)
        }.onSuccess { (aId, _, moveId) ->
            mainHandler.postDelayed({
                runCatching {
                    check(lastPublishedButtons == 0) { "B accessibility pulse did not clear" }
                    check(virtualNodeProvider.performAction(
                        moveId, ACTION_STICK_RIGHT, null,
                    )) { "move-right accessibility action was rejected" }
                    check(abs(leftX - 1f) < 0.001f && abs(leftY) < 0.001f &&
                        debugVirtualKeyHapticCount == 2
                    ) { "move-right axes=($leftX,$leftY) haptics=$debugVirtualKeyHapticCount" }
                }.onFailure {
                    clearTouchInput()
                    onFailure(it)
                    return@postDelayed
                }
                mainHandler.postDelayed({
                    runCatching {
                        check(leftX == 0f && leftY == 0f) {
                            "move-right accessibility pulse did not clear"
                        }
                        check(virtualNodeProvider.performAction(
                            aId, ACTION_TOGGLE_GAS_LOCK, null,
                        )) { "A lock accessibility action was rejected" }
                        val lockedNode = virtualNodeProvider.createAccessibilityNodeInfo(aId)
                            ?: error("locked A accessibility node missing")
                        check(gasLocked && lastPublishedButtons == BUTTON_A &&
                            (Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
                                lockedNode.stateDescription == "Acceleration locked") &&
                            debugVirtualKeyHapticCount == 3
                        ) { "A accessibility lock state was incomplete" }
                        check(virtualNodeProvider.performAction(
                            aId, AccessibilityNodeInfo.ACTION_CLICK, null,
                        )) { "locked A accessibility click was rejected" }
                        val unlockedNode = virtualNodeProvider.createAccessibilityNodeInfo(aId)
                            ?: error("unlocked A accessibility node missing")
                        check(!gasLocked && lastPublishedButtons == BUTTON_A &&
                            (Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
                                unlockedNode.stateDescription == "Unlocked") &&
                            debugVirtualKeyHapticCount == 4
                        ) { "A accessibility click did not unlock and pulse" }
                    }.onFailure {
                        clearTouchInput()
                        onFailure(it)
                        return@postDelayed
                    }
                    mainHandler.postDelayed({
                        runCatching {
                            check(lastPublishedButtons == 0 && !gasLocked) {
                                "A accessibility pulse did not return neutral"
                            }
                            check(virtualNodeProvider.performAction(
                                aId, AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS, null,
                            )) { "A accessibility focus clear was rejected" }
                            check(virtualNodeProvider.findFocus(
                                AccessibilityNodeInfo.FOCUS_ACCESSIBILITY,
                            ) == null) { "A accessibility focus remained after clear" }
                            "focus=A b=pulse move=right lock=on click=unlock haptics=4 neutral=true"
                        }.onSuccess(onSuccess).onFailure {
                            clearTouchInput()
                            onFailure(it)
                        }
                    }, ACCESSIBILITY_PULSE_MS + 60L)
                }, ACCESSIBILITY_STICK_PULSE_MS + 60L)
            }, ACCESSIBILITY_PULSE_MS + 60L)
        }.onFailure(onFailure)
    }

    fun runDebugHoldAForModalFixture(): String {
        check(isLaidOut && width > 0 && height > 0) { "touch overlay is not laid out" }
        val a = controls.first { it.id == "A" }.frame
        val downTime = SystemClock.uptimeMillis()
        val event = MotionEvent.obtain(
            downTime,
            downTime,
            MotionEvent.ACTION_DOWN,
            a.centerX(),
            a.centerY(),
            0,
        ).apply { source = InputDevice.SOURCE_TOUCHSCREEN }
        clearTouchInput()
        try {
            check(onTouchEvent(event)) { "touch overlay rejected modal-clear pointer event" }
        } finally {
            event.recycle()
        }
        check(lastPublishedButtons == BUTTON_A && pointerOwners.values.singleOrNull() == "A") {
            "modal-clear setup mask=0x${lastPublishedButtons.toString(16)} " +
                "owners=${pointerOwners.values}"
        }
        return "held=0x${lastPublishedButtons.toString(16)} owners=${pointerOwners.size}"
    }

    fun debugTouchStateIsNeutral(): Boolean =
        lastPublishedButtons == 0 && pointerOwners.isEmpty() && !gasLocked

    fun runDebugPersistenceFixture(): String {
        check(isLaidOut && width > 0 && height > 0) { "touch overlay is not laid out" }
        layoutControls()
        val savedOrigin = KartPadTouchSettings.origin(context, "A")
        val savedSize = KartPadTouchSettings.controlSize(context, "A")
        check(savedOrigin != null && abs(savedOrigin.x - 0.55f) < 0.001f &&
            abs(savedOrigin.y - 0.55f) < 0.001f
        ) { "persisted A origin is $savedOrigin" }
        check(abs(savedSize - 1.25f) < 0.001f) { "persisted A size is $savedSize" }
        check(KartPadTouchSettings.isHidden(context, "B")) { "persisted B visibility is shown" }

        val safe = safeFrame()
        val a = controls.first { it.id == "A" }.frame
        val expectedX = safe.left + safe.width() * 0.55f
        val expectedY = safe.top + safe.height() * 0.55f
        check(abs(a.centerX() - expectedX) <= 2f && abs(a.centerY() - expectedY) <= 2f) {
            "rendered A center=(${a.centerX()},${a.centerY()}) expected=($expectedX,$expectedY)"
        }
        val bVisible = visibleAccessibilityControls().any { it.second.id == "B" }
        check(!bVisible) { "hidden B remains in the accessibility tree" }
        return "a_center=${a.centerX().roundToInt()},${a.centerY().roundToInt()} " +
            "a_size=1.25 b=hidden"
    }

    fun runDebugSelectAForEditorFixture(): String {
        check(editingLayout && isLaidOut && width > 0 && height > 0) {
            "touch layout editor is not ready"
        }
        layoutControls()
        val a = controls.first { it.id == "A" }.frame
        val downTime = SystemClock.uptimeMillis()
        val down = MotionEvent.obtain(
            downTime, downTime, MotionEvent.ACTION_DOWN, a.centerX(), a.centerY(), 0,
        ).apply { source = InputDevice.SOURCE_TOUCHSCREEN }
        val up = MotionEvent.obtain(
            downTime, downTime + 1, MotionEvent.ACTION_UP, a.centerX(), a.centerY(), 0,
        ).apply { source = InputDevice.SOURCE_TOUCHSCREEN }
        try {
            check(onTouchEvent(down) && onTouchEvent(up)) {
                "touch layout editor rejected A selection"
            }
        } finally {
            down.recycle()
            up.recycle()
        }
        check(selectedControlId == "A") { "touch layout editor selected $selectedControlId" }
        return "selected=A"
    }

    fun runDebugDragSelectedAForEditorFixture(): String {
        check(editingLayout && selectedControlId == "A") {
            "A must be selected before the drag fixture"
        }
        layoutControls()
        val a = controls.first { it.id == "A" }
        val startX = a.frame.centerX()
        val startY = a.frame.centerY()
        val safe = safeFrame()
        val targetX = startX - safe.width() * 0.04f
        val targetY = startY - safe.height() * 0.05f
        val downTime = SystemClock.uptimeMillis()
        dispatchTouchAt(startX, startY, MotionEvent.ACTION_DOWN, downTime, downTime)
        dispatchTouchAt(
            targetX, targetY, MotionEvent.ACTION_MOVE, downTime,
            SystemClock.uptimeMillis(),
        )
        dispatchTouchAt(
            targetX, targetY, MotionEvent.ACTION_UP, downTime,
            SystemClock.uptimeMillis(),
        )
        layoutControls()
        val saved = KartPadTouchSettings.origin(context, "A")
            ?: error("A drag did not persist an origin")
        check(abs(a.frame.centerX() - targetX) <= 2f && abs(a.frame.centerY() - targetY) <= 2f) {
            "A drag rendered at ${a.frame.centerX()},${a.frame.centerY()} " +
                "instead of $targetX,$targetY"
        }
        val expectedX = (targetX - safe.left) / safe.width()
        val expectedY = (targetY - safe.top) / safe.height()
        check(abs(saved.x - expectedX) < 0.002f && abs(saved.y - expectedY) < 0.002f) {
            "A drag saved $saved instead of $expectedX,$expectedY"
        }
        return "dragged=A"
    }

    fun runDebugGasLockFixture(
        onSuccess: (String) -> Unit,
        onFailure: (Throwable) -> Unit,
    ) {
        runCatching {
            check(isLaidOut && width > 0 && height > 0) { "touch overlay is not laid out" }
            clearTouchInput()
            debugVirtualKeyHapticCount = 0
            layoutControls()
            val a = controls.first { it.id == "A" }
            val downTime = SystemClock.uptimeMillis()
            dispatchSingleTouch(a, MotionEvent.ACTION_DOWN, downTime, downTime)
            check(lastPublishedButtons == BUTTON_A && pointerOwners.values.singleOrNull() == "A") {
                "gas lock did not begin with a held A pointer"
            }
            downTime
        }.onSuccess { downTime ->
            mainHandler.postDelayed({
                runCatching {
                    check(!gasLocked && lastPublishedButtons == BUTTON_A &&
                        debugVirtualKeyHapticCount == 0
                    ) { "gas lock activated before one second" }
                }.onFailure {
                    clearTouchInput()
                    onFailure(it)
                    return@postDelayed
                }
                mainHandler.postDelayed({
                    runCatching {
                        val a = controls.first { it.id == "A" }
                        val elapsed = SystemClock.uptimeMillis() - downTime
                        check(gasLocked && lastPublishedButtons == BUTTON_A &&
                            pointerOwners.values.singleOrNull() == "A"
                        ) { "gas lock did not retain A after one second" }
                        check(buttonFillColor(a) == LOCKED_GAS_COLOR) {
                            "gas lock did not select the cyan fill"
                        }
                        check(Build.VERSION.SDK_INT < Build.VERSION_CODES.R ||
                            stateDescription == "Acceleration locked"
                        ) { "gas lock accessibility state was not updated" }
                        check(debugVirtualKeyHapticCount == 1) {
                            "gas lock haptic count=$debugVirtualKeyHapticCount"
                        }
                        dispatchSingleTouch(
                            a, MotionEvent.ACTION_UP, downTime,
                            SystemClock.uptimeMillis(),
                        )
                        check(gasLocked && lastPublishedButtons == BUTTON_A &&
                            pointerOwners.isEmpty()
                        ) { "releasing the long press cancelled locked acceleration" }
                        val unlockTime = SystemClock.uptimeMillis()
                        dispatchSingleTouch(a, MotionEvent.ACTION_DOWN, unlockTime, unlockTime)
                        dispatchSingleTouch(
                            a, MotionEvent.ACTION_UP, unlockTime,
                            SystemClock.uptimeMillis(),
                        )
                        check(!gasLocked && lastPublishedButtons == 0 && pointerOwners.isEmpty()) {
                            "tap did not unlock acceleration"
                        }
                        check(debugVirtualKeyHapticCount == 1) {
                            "unlock unexpectedly changed haptic count=$debugVirtualKeyHapticCount"
                        }
                        "delay=${elapsed}ms cyan=true haptics=1 release=locked tap=neutral"
                    }.onSuccess(onSuccess).onFailure {
                        clearTouchInput()
                        onFailure(it)
                    }
                }, 200L)
            }, 900L)
        }.onFailure(onFailure)
    }

    fun setMotionSteering(value: Float) {
        motionSteeringX = if (controllerConnected) 0f else value.coerceIn(-1f, 1f)
        publishState(connected = true)
    }

    fun setControllerConnected(connected: Boolean) {
        controllerConnected = connected
        if (connected) motionSteeringX = 0f
        publishState(connected = true)
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
        sendAccessibilityTreeChanged()
    }

    fun reloadPresentationSettings() {
        controlOpacity = KartPadTouchSettings.opacity(context)
        controlSizeScale = KartPadTouchSettings.size(context)
        modernCStickHorizontal = KartPadTouchSettings.modernCStickHorizontal(context)
        reloadCustomSettings()
        requestLayout()
        invalidate()
        sendAccessibilityTreeChanged()
    }

    fun beginLayoutEditing() {
        clearTouchInput()
        editingLayout = true
        selectedControlId = null
        visibility = VISIBLE
        onEditSelectionChanged?.invoke(null, 1f, false)
        invalidate()
        sendAccessibilityTreeChanged()
    }

    fun endLayoutEditing() {
        clearTouchInput()
        editingLayout = false
        selectedControlId = null
        editPointerId = MotionEvent.INVALID_POINTER_ID
        invalidate()
        sendAccessibilityTreeChanged()
    }

    fun setSelectedControlSize(value: Float) {
        val identifier = selectedControlId ?: return
        KartPadTouchSettings.setControlSize(context, identifier, value)
        notifyEditSelection()
        requestLayout()
        invalidate()
        sendAccessibilityTreeChanged()
    }

    fun toggleSelectedControlVisibility() {
        val identifier = selectedControlId ?: return
        KartPadTouchSettings.setHidden(
            context, identifier, !KartPadTouchSettings.isHidden(context, identifier),
        )
        notifyEditSelection()
        invalidate()
        sendAccessibilityTreeChanged()
    }

    fun resetLayoutSettings() {
        KartPadTouchSettings.resetTouchControls(context)
        customOrigins.clear()
        reloadPresentationSettings()
        notifyEditSelection()
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
            0.896f, 0.4258446f, Color.argb(235, 184, 184, 184), true)
        controls += button("Y", "Y", BUTTON_Y, 46f, 46f,
            0.84525f, 0.5268581f, Color.argb(235, 184, 184, 184), true)
        controls += button("L", "L", BUTTON_L, 94f, 46f,
            0.09058333f, 0.25399774f, dark)
        controls += button("R", "R", BUTTON_R, 94f, 46f,
            0.86875f, 0.27291667f, dark)
        controls += button("Z", "Z", BUTTON_ZR, 46f, 46f,
            0.969f, 0.410f, Color.argb(240, 97, 46, 148))
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
        val safe = safeFrame()
        val tabletDefaults = resources.configuration.smallestScreenWidthDp >= 600 &&
            safe.width() / resources.displayMetrics.density >= 1000f
        val baseScale = if (tabletDefaults) {
            1f
        } else {
            min(1f, min(safe.width() / dp(800f), safe.height() / dp(380f)))
        }
        controls.forEach { control ->
            val identifier = editableIdentifier(control)
            val individualScale = KartPadTouchSettings.controlSize(context, identifier)
            val combinedScale = baseScale * controlSizeScale * individualScale
            val tabletSize = if (tabletDefaults) tabletControlSize(control.id) else null
            val controlWidth = dp(tabletSize?.x ?: control.width) * combinedScale
            val controlHeight = dp(tabletSize?.y ?: control.height) * combinedScale
            val centerX: Float
            val centerY: Float
            val customOrigin = customOrigins[identifier]
            if (customOrigin != null) {
                centerX = safe.left + customOrigin.x * safe.width()
                centerY = safe.top + customOrigin.y * safe.height()
            } else if (tabletDefaults) {
                val center = tabletControlCenter(control.id)
                centerX = safe.left + center.x * safe.width()
                centerY = safe.top + center.y * safe.height()
            } else if (control.id == "A") {
                val margin = max(dp(8f), dp(18f) * baseScale)
                val cameraScale = KartPadTouchSettings.controlSize(context, "c")
                val camera = dp(86f) * baseScale * controlSizeScale * cameraScale
                centerX = safe.right - margin - controlWidth * 0.5f
                centerY = safe.bottom - margin - camera - controlHeight * 0.5f - dp(18f) * baseScale
            } else {
                centerX = safe.left + control.centerX * safe.width()
                centerY = safe.top + control.centerY * safe.height()
            }
            val boundedCenterX = centerX.coerceIn(
                safe.left + controlWidth * 0.5f,
                safe.right - controlWidth * 0.5f,
            )
            val boundedCenterY = centerY.coerceIn(
                safe.top + controlHeight * 0.5f,
                safe.bottom - controlHeight * 0.5f,
            )
            val dpadCell = dp(if (tabletDefaults) 48f else 36f) * combinedScale
            val adjustedCenterX = boundedCenterX + when (control.id) {
                "DpadLeft" -> -dpadCell
                "DpadRight" -> dpadCell
                else -> 0f
            }
            val adjustedCenterY = boundedCenterY + when (control.id) {
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

    private fun tabletControlSize(id: String): PointF = when (id) {
        "move" -> PointF(172f, 172f)
        "c" -> PointF(112f, 112f)
        "A" -> PointF(104f, 104f)
        "B" -> PointF(76f, 76f)
        "L" -> PointF(132f, 62f)
        "R" -> PointF(280f, 62f)
        "Start" -> PointF(116f, 62f)
        "DpadUp", "DpadDown", "DpadLeft", "DpadRight" -> PointF(48f, 48f)
        else -> PointF(62f, 62f)
    }

    private fun tabletControlCenter(id: String): PointF = when (id) {
        "move" -> PointF(0.13103953f, 0.79058945f)
        "c" -> PointF(0.9062958f, 0.8583247f)
        "A" -> PointF(0.8916545f, 0.7409514f)
        "B" -> PointF(0.83601755f, 0.80920374f)
        "X" -> PointF(0.95937043f, 0.71561533f)
        "Y" -> PointF(0.95424595f, 0.786970f)
        "L" -> PointF(0.12811127f, 0.66339195f)
        "R" -> PointF(0.8960469f, 0.647880f)
        "Z" -> PointF(0.8275988f, 0.721303f)
        "Start" -> PointF(0.89677894f, 0.57807654f)
        else -> PointF(0.26866764f, 0.79472595f)
    }

    private fun safeFrame() = RectF(
        insetLeft.toFloat(), insetTop.toFloat(),
        max(insetLeft.toFloat(), width - insetRight.toFloat()),
        max(insetTop.toFloat(), height - insetBottom.toFloat()),
    )

    private fun editableIdentifier(control: Control): String =
        if (control.id.startsWith("Dpad")) "Dpad" else control.id

    private fun reloadCustomSettings() {
        customOrigins.clear()
        controls.map(::editableIdentifier).distinct().forEach { identifier ->
            KartPadTouchSettings.origin(context, identifier)?.let {
                customOrigins[identifier] = it
            }
        }
    }

    private fun drawEditOutline(canvas: Canvas, control: Control, identifier: String) {
        val selected = identifier == selectedControlId
        val originalColor = strokePaint.color
        val originalWidth = strokePaint.strokeWidth
        strokePaint.color = if (selected) EDIT_SELECTED_COLOR else EDIT_AVAILABLE_COLOR
        strokePaint.strokeWidth = dp(if (selected) 4f else 3f)
        val radius = min(control.frame.width(), control.frame.height()) * 0.5f
        canvas.drawRoundRect(control.frame, radius, radius, strokePaint)
        strokePaint.color = originalColor
        strokePaint.strokeWidth = originalWidth
    }

    private fun drawButton(canvas: Canvas, control: Control) {
        fillPaint.style = Paint.Style.FILL
        fillPaint.color = buttonFillColor(control)
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

    private fun onEditTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                layoutControls()
                val control = hitTest(event.x, event.y) ?: return true
                selectedControlId = editableIdentifier(control)
                editPointerId = event.getPointerId(0)
                editLastX = event.x
                editLastY = event.y
                notifyEditSelection()
                invalidate()
            }
            MotionEvent.ACTION_MOVE -> {
                val index = event.findPointerIndex(editPointerId)
                if (index < 0 || selectedControlId == null) return true
                val x = event.getX(index)
                val y = event.getY(index)
                moveSelectedControl(x - editLastX, y - editLastY)
                editLastX = x
                editLastY = y
            }
            MotionEvent.ACTION_UP -> {
                selectedControlId?.let { identifier ->
                    customOrigins[identifier]?.let {
                        KartPadTouchSettings.setOrigin(context, identifier, it)
                    }
                }
                editPointerId = MotionEvent.INVALID_POINTER_ID
                performClick()
            }
            MotionEvent.ACTION_CANCEL -> editPointerId = MotionEvent.INVALID_POINTER_ID
        }
        return true
    }

    private fun moveSelectedControl(deltaX: Float, deltaY: Float) {
        val identifier = selectedControlId ?: return
        layoutControls()
        val selected = controls.filter { editableIdentifier(it) == identifier }
        if (selected.isEmpty()) return
        val bounds = RectF(selected.first().frame)
        selected.drop(1).forEach { bounds.union(it.frame) }
        val safe = safeFrame()
        val clampedX = deltaX.coerceIn(safe.left - bounds.left, safe.right - bounds.right)
        val clampedY = deltaY.coerceIn(safe.top - bounds.top, safe.bottom - bounds.bottom)
        val centerX = bounds.centerX() + clampedX
        val centerY = bounds.centerY() + clampedY
        if (safe.width() > 0f && safe.height() > 0f) {
            customOrigins[identifier] = PointF(
                ((centerX - safe.left) / safe.width()).coerceIn(0f, 1f),
                ((centerY - safe.top) / safe.height()).coerceIn(0f, 1f),
            )
        }
        requestLayout()
        invalidate()
    }

    private fun notifyEditSelection() {
        val identifier = selectedControlId
        onEditSelectionChanged?.invoke(
            identifier,
            identifier?.let { KartPadTouchSettings.controlSize(context, it) } ?: 1f,
            identifier?.let { KartPadTouchSettings.isHidden(context, it) } ?: false,
        )
    }

    private fun hitTest(x: Float, y: Float): Control? = controls.asReversed().firstOrNull {
        if (!editingLayout && KartPadTouchSettings.isHidden(context, editableIdentifier(it))) {
            return@firstOrNull false
        }
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

    private fun dispatchSingleTouch(
        control: Control,
        action: Int,
        downTime: Long,
        eventTime: Long,
    ) {
        dispatchTouchAt(
            control.frame.centerX(), control.frame.centerY(), action, downTime, eventTime,
        )
    }

    private fun dispatchTouchAt(
        x: Float,
        y: Float,
        action: Int,
        downTime: Long,
        eventTime: Long,
    ) {
        val event = MotionEvent.obtain(
            downTime, eventTime, action, x, y, 0,
        ).apply { source = InputDevice.SOURCE_TOUCHSCREEN }
        try {
            check(onTouchEvent(event)) { "touch overlay rejected action=$action at $x,$y" }
        } finally {
            event.recycle()
        }
    }

    private fun publishState(connected: Boolean) {
        var buttons = (if (gasLocked) BUTTON_A else 0) or accessibilityButtons
        pointerOwners.values.forEach { owner ->
            buttons = buttons or (controls.firstOrNull { it.id == owner }?.mask ?: 0)
        }
        val publishedRightX = if (modernCStickHorizontal) -rightX else rightX
        val publishedLeftX = if (abs(leftX) >= abs(motionSteeringX)) leftX else motionSteeringX
        lastPublishedButtons = buttons
        nativePublishTouchState(
            buttons, publishedLeftX, leftY, publishedRightX, rightY, connected,
        )
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
            performVirtualKeyHaptic()
            publishState(connected = true)
            invalidate()
        }, GAS_LOCK_DELAY_MS)
    }

    private fun updateGasAccessibility() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            stateDescription = if (gasLocked) "Acceleration locked" else null
        }
        sendVirtualAccessibilityEvent(
            controls.indexOfFirst { it.id == "A" },
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
        )
    }

    private fun visibleAccessibilityControls(): List<Pair<Int, Control>> {
        layoutControls()
        return controls.mapIndexedNotNull { index, control ->
            if (hiddenForController ||
                (!editingLayout && KartPadTouchSettings.isHidden(
                    context, editableIdentifier(control),
                ))
            ) null else index to control
        }
    }

    private fun accessibilityControlAt(x: Float, y: Float): Pair<Int, Control>? =
        visibleAccessibilityControls().asReversed().firstOrNull { (_, control) ->
            if (!control.frame.contains(x, y)) return@firstOrNull false
            if (control.kind == Kind.BUTTON && control.frame.width() != control.frame.height()) {
                return@firstOrNull true
            }
            val radius = min(control.frame.width(), control.frame.height()) * 0.5f
            hypot(
                (x - control.frame.centerX()).toDouble(),
                (y - control.frame.centerY()).toDouble(),
            ) <= radius
        }

    private fun accessibilityLabel(control: Control): String = when (control.id) {
        "move" -> "Move stick"
        "c" -> "Camera stick"
        "Start" -> "Start button"
        "DpadUp" -> "D-pad up"
        "DpadDown" -> "D-pad down"
        "DpadLeft" -> "D-pad left"
        "DpadRight" -> "D-pad right"
        else -> "${control.label} button"
    }

    private fun pulseAccessibilityButton(control: Control) {
        if (control.id == "A" && gasLocked) {
            gasLocked = false
            updateGasAccessibility()
        }
        val generation = (accessibilityPulseGenerations[control.id] ?: 0) + 1
        accessibilityPulseGenerations[control.id] = generation
        accessibilityButtons = accessibilityButtons or control.mask
        performVirtualKeyHaptic()
        publishState(connected = true)
        invalidate()
        mainHandler.postDelayed({
            if (accessibilityPulseGenerations[control.id] != generation) return@postDelayed
            accessibilityButtons = accessibilityButtons and control.mask.inv()
            publishState(connected = true)
            invalidate()
        }, ACCESSIBILITY_PULSE_MS)
    }

    private fun pulseAccessibilityStick(control: Control, action: Int) {
        val generation = (accessibilityPulseGenerations[control.id] ?: 0) + 1
        accessibilityPulseGenerations[control.id] = generation
        val x = when (action) {
            ACTION_STICK_LEFT -> -1f
            ACTION_STICK_RIGHT -> 1f
            else -> 0f
        }
        val y = when (action) {
            ACTION_STICK_UP -> 1f
            ACTION_STICK_DOWN -> -1f
            else -> 0f
        }
        if (control.kind == Kind.LEFT_STICK) {
            leftX = x
            leftY = y
        } else {
            rightX = x
            rightY = y
        }
        performVirtualKeyHaptic()
        publishState(connected = true)
        invalidate()
        mainHandler.postDelayed({
            if (accessibilityPulseGenerations[control.id] != generation) return@postDelayed
            if (control.kind == Kind.LEFT_STICK) {
                leftX = 0f
                leftY = 0f
            } else {
                rightX = 0f
                rightY = 0f
            }
            publishState(connected = true)
            invalidate()
        }, ACCESSIBILITY_STICK_PULSE_MS)
    }

    private fun toggleAccessibilityGasLock() {
        gasHoldGeneration += 1
        gasLocked = !gasLocked
        updateGasAccessibility()
        performVirtualKeyHaptic()
        publishState(connected = true)
        invalidate()
    }

    private fun updateAccessibilityHover(id: Int) {
        if (id == accessibilityHoverId) return
        if (accessibilityHoverId != View.NO_ID) {
            sendVirtualAccessibilityEvent(
                accessibilityHoverId, AccessibilityEvent.TYPE_VIEW_HOVER_EXIT,
            )
        }
        accessibilityHoverId = id
        if (id != View.NO_ID) {
            sendVirtualAccessibilityEvent(id, AccessibilityEvent.TYPE_VIEW_HOVER_ENTER)
        }
    }

    private fun sendAccessibilityTreeChanged() {
        sendAccessibilityEvent(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED)
    }

    private fun sendVirtualAccessibilityEvent(id: Int, eventType: Int) {
        val control = controls.getOrNull(id) ?: return
        if (!accessibilityManager.isEnabled || parent == null) return
        val event = AccessibilityEvent.obtain(eventType).apply {
            packageName = context.packageName
            className = if (control.kind == Kind.BUTTON) {
                android.widget.Button::class.java.name
            } else {
                android.widget.SeekBar::class.java.name
            }
            contentDescription = accessibilityLabel(control)
            setSource(this@KartPadOverlayView, id)
        }
        parent.requestSendAccessibilityEvent(this, event)
    }

    private inner class TouchAccessibilityNodeProvider : AccessibilityNodeProvider() {
        override fun createAccessibilityNodeInfo(virtualViewId: Int): AccessibilityNodeInfo? {
            if (virtualViewId == HOST_VIEW_ID) {
                return AccessibilityNodeInfo.obtain(this@KartPadOverlayView).also {
                    onInitializeAccessibilityNodeInfo(it)
                }
            }
            val control = visibleAccessibilityControls()
                .firstOrNull { it.first == virtualViewId }?.second ?: return null
            val bounds = Rect().also { control.frame.roundOut(it) }
            val screenBounds = Rect(bounds)
            val location = IntArray(2)
            getLocationOnScreen(location)
            screenBounds.offset(location[0], location[1])
            return AccessibilityNodeInfo.obtain().apply {
                setSource(this@KartPadOverlayView, virtualViewId)
                setParent(this@KartPadOverlayView)
                packageName = context.packageName
                className = if (control.kind == Kind.BUTTON) {
                    android.widget.Button::class.java.name
                } else {
                    android.widget.SeekBar::class.java.name
                }
                contentDescription = accessibilityLabel(control)
                isEnabled = isShown
                isVisibleToUser = isShown
                isFocusable = true
                isClickable = control.kind == Kind.BUTTON || editingLayout
                setBoundsInParent(bounds)
                setBoundsInScreen(screenBounds)
                if (control.kind == Kind.BUTTON || editingLayout) {
                    addAction(AccessibilityNodeInfo.ACTION_CLICK)
                }
                if (accessibilityFocusId == virtualViewId) {
                    isAccessibilityFocused = true
                    addAction(AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS)
                } else {
                    addAction(AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS)
                }
                if (control.kind != Kind.BUTTON) {
                    addAction(AccessibilityNodeInfo.AccessibilityAction(
                        ACTION_STICK_UP, "Move up",
                    ))
                    addAction(AccessibilityNodeInfo.AccessibilityAction(
                        ACTION_STICK_DOWN, "Move down",
                    ))
                    addAction(AccessibilityNodeInfo.AccessibilityAction(
                        ACTION_STICK_LEFT, "Move left",
                    ))
                    addAction(AccessibilityNodeInfo.AccessibilityAction(
                        ACTION_STICK_RIGHT, "Move right",
                    ))
                }
                if (control.id == "A") {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        stateDescription = if (gasLocked) "Acceleration locked" else "Unlocked"
                    }
                    addAction(AccessibilityNodeInfo.AccessibilityAction(
                        ACTION_TOGGLE_GAS_LOCK,
                        if (gasLocked) "Unlock acceleration" else "Lock acceleration",
                    ))
                }
            }
        }

        override fun performAction(
            virtualViewId: Int,
            action: Int,
            arguments: Bundle?,
        ): Boolean {
            if (virtualViewId == HOST_VIEW_ID) {
                return performAccessibilityAction(action, arguments)
            }
            val control = visibleAccessibilityControls()
                .firstOrNull { it.first == virtualViewId }?.second ?: return false
            return when (action) {
                AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS -> {
                    if (accessibilityFocusId == virtualViewId) false else {
                        accessibilityFocusId = virtualViewId
                        invalidate()
                        sendVirtualAccessibilityEvent(
                            virtualViewId, AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUSED,
                        )
                        true
                    }
                }
                AccessibilityNodeInfo.ACTION_CLEAR_ACCESSIBILITY_FOCUS -> {
                    if (accessibilityFocusId != virtualViewId) false else {
                        accessibilityFocusId = View.NO_ID
                        invalidate()
                        sendVirtualAccessibilityEvent(
                            virtualViewId,
                            AccessibilityEvent.TYPE_VIEW_ACCESSIBILITY_FOCUS_CLEARED,
                        )
                        true
                    }
                }
                AccessibilityNodeInfo.ACTION_CLICK -> {
                    if (editingLayout) {
                        selectedControlId = editableIdentifier(control)
                        notifyEditSelection()
                        invalidate()
                    } else if (control.kind == Kind.BUTTON) {
                        pulseAccessibilityButton(control)
                    } else {
                        return false
                    }
                    sendVirtualAccessibilityEvent(
                        virtualViewId, AccessibilityEvent.TYPE_VIEW_CLICKED,
                    )
                    true
                }
                ACTION_TOGGLE_GAS_LOCK -> if (control.id == "A") {
                    toggleAccessibilityGasLock()
                    true
                } else false
                ACTION_STICK_UP, ACTION_STICK_DOWN,
                ACTION_STICK_LEFT, ACTION_STICK_RIGHT -> if (control.kind != Kind.BUTTON) {
                    pulseAccessibilityStick(control, action)
                    true
                } else false
                else -> false
            }
        }

        override fun findFocus(focus: Int): AccessibilityNodeInfo? =
            if (focus == AccessibilityNodeInfo.FOCUS_ACCESSIBILITY &&
                accessibilityFocusId != View.NO_ID
            ) createAccessibilityNodeInfo(accessibilityFocusId) else null
    }

    private fun brighten(color: Int): Int = Color.argb(
        Color.alpha(color), min(255, Color.red(color) + 34),
        min(255, Color.green(color) + 34), min(255, Color.blue(color) + 34),
    )

    private fun buttonFillColor(control: Control): Int = when {
        control.id == "A" && gasLocked -> LOCKED_GAS_COLOR
        pointerOwners.containsValue(control.id) -> brighten(control.fill)
        else -> control.fill
    }

    private fun performVirtualKeyHaptic() {
        if (BuildConfig.DEBUG) debugVirtualKeyHapticCount += 1
        performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
    }

    private fun dp(value: Float): Float = value * resources.displayMetrics.density

    private external fun nativePublishTouchState(
        buttons: Int, leftX: Float, leftY: Float, rightX: Float, rightY: Float,
        connected: Boolean,
    )

    private external fun nativeClearTouchState()

    private companion object {
        const val GAS_LOCK_DELAY_MS = 1_000L
        const val ACCESSIBILITY_PULSE_MS = 140L
        const val ACCESSIBILITY_STICK_PULSE_MS = 240L
        const val ACTION_STICK_UP = 0x01020001
        const val ACTION_STICK_DOWN = 0x01020002
        const val ACTION_STICK_LEFT = 0x01020003
        const val ACTION_STICK_RIGHT = 0x01020004
        const val ACTION_TOGGLE_GAS_LOCK = 0x01020005
        val LOCKED_GAS_COLOR: Int = Color.argb(250, 15, 199, 235)
        val EDIT_SELECTED_COLOR: Int = Color.rgb(51, 199, 255)
        val EDIT_AVAILABLE_COLOR: Int = Color.rgb(255, 199, 51)
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
