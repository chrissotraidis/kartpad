package dev.kartpad.android

import android.app.AlertDialog
import android.os.Build
import android.os.Bundle
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.GradientDrawable
import android.hardware.input.InputManager
import android.net.Uri
import android.system.Os
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.InputDevice
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.RelativeLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import java.util.UUID
import kotlin.math.ceil
import kotlin.math.roundToInt
import org.libsdl.app.SDLActivity
import org.libsdl.app.SDLSurface

class KartPadActivity : SDLActivity() {
    private lateinit var kartPadOverlay: KartPadOverlayView
    private lateinit var menuButton: Button
    private lateinit var editorBar: LinearLayout
    private lateinit var editorLabel: TextView
    private lateinit var editorSize: SeekBar
    private lateinit var editorVisibility: Button
    private lateinit var editorBack: Button
    private lateinit var resetTouchLayoutButton: Button
    private var updatingEditorControls = false
    private var touchSettingsDialog: AlertDialog? = null
    private var resetTouchLayoutDialog: AlertDialog? = null
    private var kartPadMenu: PopupWindow? = null
    private var menuSafeInsetTop = 0
    private var menuSafeInsetEnd = 0
    private var menuSafeInsetBottom = 0
    private var runtimeProfile = "base"
    private lateinit var inputManager: InputManager
    private lateinit var motionSteering: KartPadMotionSteering
    private var inputListenerRegistered = false
    private var debugLifecycleClearArmed = false
    private var debugActivityRecreateRequested = false
    private val inputDeviceListener = object : InputManager.InputDeviceListener {
        override fun onInputDeviceAdded(deviceId: Int) = refreshControllerHandoff()
        override fun onInputDeviceRemoved(deviceId: Int) = refreshControllerHandoff()
        override fun onInputDeviceChanged(deviceId: Int) = refreshControllerHandoff()
    }

    override fun createSDLSurface(context: Context): SDLSurface = KartPadSurface(context)

    override fun onCreate(savedInstanceState: Bundle?) {
        Os.setenv("KARTPAD_ANDROID_FILES_DIR", filesDir.absolutePath, true)
        Os.setenv("KARTPAD_ANDROID_CACHE_DIR", cacheDir.absolutePath, true)
        if (BuildConfig.GAME_RUNTIME) {
            RetroRewindInstallStorage.recover(filesDir)
            KartPadSaveStorage.applyPending(filesDir)?.let { error ->
                Log.e(TAG, error)
            }
            KartPadMiiStorage.applyPending(filesDir)?.let { error ->
                Log.e(TAG, error)
            }
            KartPadRuntimeResources.install(this)
            configureRuntimeProfile()
            configureDebugLocalWfcRoute()
            configureDebugRkgInput()
            configureDebugStateTrace()
        }
        super.onCreate(savedInstanceState)
        nativeEnableActivityRecreation()
        inputManager = getSystemService(InputManager::class.java)
        runDebugRetroRewindExtractionFixture()
        runDebugRetroRewindWorkerFixture()
        kartPadOverlay = KartPadOverlayView(this)
        val debugMotionSensorMode = if (BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME) {
            intent.getStringExtra(DEBUG_EXTRA_MOTION_SENSOR)?.also {
                check(it == "standard" || it == "inverted") {
                    "unsupported motion sensor fixture mode $it"
                }
                KartPadTouchSettings.setMotionEnabled(this, true)
                KartPadTouchSettings.setMotionInverted(this, it == "inverted")
                KartPadTouchSettings.setMotionSensitivity(this, 1f)
            }
        } else {
            null
        }
        motionSteering = KartPadMotionSteering(this) { value ->
            kartPadOverlay.post {
                kartPadOverlay.setMotionSteering(value)
                if (debugMotionSensorMode != null) {
                    Log.i(
                        TAG,
                        "A4 motion sensor sample mode=$debugMotionSensorMode steering=$value",
                    )
                }
            }
        }
        val debugTouchOverlay = BuildConfig.DEBUG &&
            intent.getBooleanExtra(DEBUG_EXTRA_TOUCH_OVERLAY, false)
        val debugMultiPointer = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_MULTI_POINTER, false)
        val debugHitMap = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_HIT_MAP, false)
        val debugAccessibilityActions = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_ACCESSIBILITY_ACTIONS, false)
        val debugControllerSetup = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_CONTROLLER_SETUP, false)
        val debugMenu = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_MENU, false)
        val debugModalClear = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_MODAL_CLEAR, false)
        val debugLifecycleClear = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_LIFECYCLE_CLEAR, false)
        val debugActivityRecreate = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_ACTIVITY_RECREATE, false)
        val debugActivityRecreateRestored = debugActivityRecreate &&
            savedInstanceState?.getBoolean(DEBUG_STATE_ACTIVITY_RECREATE) == true
        val debugPersistence = if (BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME) {
            intent.getStringExtra(DEBUG_EXTRA_TOUCH_PERSISTENCE)
        } else {
            null
        }
        val debugTouchSettings = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_TOUCH_SETTINGS, false)
        val debugTouchSettingsFlow = if (BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME) {
            intent.getStringExtra(DEBUG_EXTRA_TOUCH_SETTINGS_FLOW)
        } else {
            null
        }
        val debugTouchEditor = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_TOUCH_EDITOR, false)
        val debugGasLock = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(DEBUG_EXTRA_GAS_LOCK, false)
        kartPadOverlay.visibility = if (
            BuildConfig.GAME_RUNTIME || debugTouchOverlay || debugModalClear ||
                debugLifecycleClear || debugActivityRecreate || debugPersistence != null || debugTouchSettings ||
                debugTouchEditor || debugGasLock || debugHitMap || debugAccessibilityActions ||
                debugMotionSensorMode != null || debugTouchSettingsFlow != null
        ) {
            android.view.View.VISIBLE
        } else {
            android.view.View.GONE
        }
        mLayout.addView(
            kartPadOverlay,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        if (BuildConfig.GAME_RUNTIME) {
            addMenuButton()
            addLayoutEditorBar()
            applyControllerMapping()
            applyDisplaySettings()
            kartPadOverlay.postDelayed({ applyDisplaySettings() }, 1_000L)
        } else if (debugControllerSetup) {
            addMenuButton()
            menuButton.postDelayed({ showControllerPlayers() }, 1_000L)
        } else if (debugMenu) {
            addMenuButton()
            menuButton.postDelayed({ showKartPadMenu() }, 1_000L)
        } else if (debugModalClear) {
            addMenuButton()
            kartPadOverlay.post {
                runCatching {
                    val held = kartPadOverlay.runDebugHoldAForModalFixture()
                    showKartPadMenu()
                    check(kartPadOverlay.debugTouchStateIsNeutral()) {
                        "touch state remained active after menu presentation"
                    }
                    Log.i(TAG, "A4 modal clear fixture passed $held neutral=0x0 owners=0")
                }.onFailure { Log.e(TAG, "A4 modal clear fixture failed", it) }
            }
        } else if (debugTouchSettings) {
            kartPadOverlay.postDelayed({ showTouchControlSettings() }, 1_000L)
        } else if (debugTouchSettingsFlow != null) {
            kartPadOverlay.postDelayed(
                { showTouchControlSettings(debugSettingsFlow = debugTouchSettingsFlow) },
                1_000L,
            )
        } else if (debugTouchEditor) {
            addMenuButton()
            addLayoutEditorBar()
            kartPadOverlay.postDelayed({ showTouchControlSettings(debugEditorFlow = true) }, 1_000L)
        } else if (debugGasLock) {
            kartPadOverlay.post {
                kartPadOverlay.runDebugGasLockFixture(
                    onSuccess = { Log.i(TAG, "A4 gas lock fixture passed $it") },
                    onFailure = { Log.e(TAG, "A4 gas lock fixture failed", it) },
                )
            }
        }
        if (debugTouchOverlay && debugMultiPointer) {
            kartPadOverlay.post {
                runCatching { kartPadOverlay.runDebugMultiPointerFixture() }
                    .onSuccess { Log.i(TAG, "A4 multi-pointer fixture passed $it") }
                    .onFailure { Log.e(TAG, "A4 multi-pointer fixture failed", it) }
            }
        }
        if (debugTouchOverlay && debugHitMap) {
            kartPadOverlay.post {
                runCatching { kartPadOverlay.runDebugHitMapFixture() }
                    .onSuccess { Log.i(TAG, "A4 hit-map fixture passed $it") }
                    .onFailure { Log.e(TAG, "A4 hit-map fixture failed", it) }
            }
        }
        if (debugTouchOverlay && debugAccessibilityActions) {
            kartPadOverlay.post {
                kartPadOverlay.runDebugAccessibilityActionsFixture(
                    onSuccess = { Log.i(TAG, "A4 accessibility actions passed $it") },
                    onFailure = { Log.e(TAG, "A4 accessibility actions failed", it) },
                )
            }
        }
        if (debugLifecycleClear) {
            kartPadOverlay.post {
                runCatching {
                    val held = kartPadOverlay.runDebugHoldAForModalFixture()
                    debugLifecycleClearArmed = true
                    Log.i(TAG, "A4 lifecycle clear fixture armed $held")
                }.onFailure { Log.e(TAG, "A4 lifecycle clear fixture failed", it) }
            }
        }
        if (debugActivityRecreate) {
            kartPadOverlay.post {
                if (debugActivityRecreateRestored) {
                    runCatching {
                        check(kartPadOverlay.debugTouchStateIsNeutral()) {
                            "recreated touch overlay did not start neutral"
                        }
                        val persisted = kartPadOverlay.runDebugPersistenceFixture()
                        "new=neutral $persisted"
                    }.onSuccess {
                        KartPadTouchSettings.resetTouchControls(this)
                        Log.i(TAG, "A4 activity recreation fixture passed $it")
                    }.onFailure {
                        KartPadTouchSettings.resetTouchControls(this)
                        Log.e(TAG, "A4 activity recreation fixture failed", it)
                    }
                } else {
                    runCatching {
                        KartPadTouchSettings.resetTouchControls(this)
                        KartPadTouchSettings.setOrigin(
                            this,
                            "A",
                            android.graphics.PointF(0.55f, 0.55f),
                        )
                        KartPadTouchSettings.setControlSize(this, "A", 1.25f)
                        KartPadTouchSettings.setHidden(this, "B", true)
                        val held = kartPadOverlay.runDebugHoldAForModalFixture()
                        debugActivityRecreateRequested = true
                        Log.i(TAG, "A4 activity recreation fixture armed $held")
                        recreate()
                    }.onFailure {
                        KartPadTouchSettings.resetTouchControls(this)
                        Log.e(TAG, "A4 activity recreation fixture failed", it)
                    }
                }
            }
        }
        when (debugPersistence) {
            "seed" -> {
                KartPadTouchSettings.resetTouchControls(this)
                KartPadTouchSettings.setOrigin(this, "A", android.graphics.PointF(0.55f, 0.55f))
                KartPadTouchSettings.setControlSize(this, "A", 1.25f)
                KartPadTouchSettings.setHidden(this, "B", true)
                Log.i(TAG, "A4 touch persistence fixture seeded a=0.55,0.55 size=1.25 b=hidden")
            }
            "verify" -> kartPadOverlay.post {
                runCatching { kartPadOverlay.runDebugPersistenceFixture() }
                    .onSuccess {
                        Log.i(TAG, "A4 touch persistence fixture passed $it")
                        KartPadTouchSettings.resetTouchControls(this)
                    }
                    .onFailure { Log.e(TAG, "A4 touch persistence fixture failed", it) }
            }
        }
        mLayout.bringChildToFront(kartPadOverlay)
        if (::menuButton.isInitialized) mLayout.bringChildToFront(menuButton)
        if (::editorBar.isInitialized) mLayout.bringChildToFront(editorBar)
        Log.i(TAG, "A0 SDLActivity shell created")
    }

    override fun onResume() {
        super.onResume()
        if (::inputManager.isInitialized && !inputListenerRegistered) {
            inputManager.registerInputDeviceListener(inputDeviceListener, null)
            inputListenerRegistered = true
        }
        refreshControllerHandoff()
        if (::motionSteering.isInitialized) motionSteering.start()
    }

    override fun onPause() {
        kartPadMenu?.dismiss()
        if (::editorBar.isInitialized && editorBar.visibility == View.VISIBLE) {
            finishLayoutEditing(returnToSettings = false)
        }
        if (::inputManager.isInitialized && inputListenerRegistered) {
            inputManager.unregisterInputDeviceListener(inputDeviceListener)
            inputListenerRegistered = false
        }
        if (::kartPadOverlay.isInitialized) {
            kartPadOverlay.clearTouchInput()
            verifyDebugLifecycleClear("pause")
            if (debugActivityRecreateRequested) {
                check(kartPadOverlay.debugTouchStateIsNeutral()) {
                    "touch state remained active while recreating activity"
                }
                Log.i(TAG, "A4 activity recreation fixture outgoing old=neutral")
            }
        }
        if (::motionSteering.isInitialized) motionSteering.stop()
        super.onPause()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        if (debugActivityRecreateRequested) {
            outState.putBoolean(DEBUG_STATE_ACTIVITY_RECREATE, true)
        }
        super.onSaveInstanceState(outState)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        if (!hasFocus && ::kartPadOverlay.isInitialized) {
            kartPadOverlay.clearTouchInput()
            verifyDebugLifecycleClear("focus-loss")
        }
        super.onWindowFocusChanged(hasFocus)
    }

    private fun verifyDebugLifecycleClear(reason: String) {
        if (!debugLifecycleClearArmed) return
        check(kartPadOverlay.debugTouchStateIsNeutral()) {
            "touch state remained active after $reason"
        }
        debugLifecycleClearArmed = false
        Log.i(TAG, "A4 lifecycle clear fixture passed reason=$reason neutral=0x0 owners=0")
    }

    private fun refreshControllerHandoff() {
        if (!BuildConfig.GAME_RUNTIME || !::kartPadOverlay.isInitialized ||
            !::inputManager.isInitialized
        ) return
        val controllerCount = inputManager.inputDeviceIds.count { deviceId ->
            inputManager.getInputDevice(deviceId)?.let(::isGameController) == true
        }
        if (controllerCount > 0) kartPadOverlay.clearTouchInput()
        kartPadOverlay.setControllerConnected(controllerCount > 0)
        kartPadOverlay.setHiddenForController(
            controllerCount > 0 && KartPadTouchSettings.hideOnController(this),
        )
        Log.i(TAG, "A4 controller handoff count=$controllerCount")
    }

    private fun addMenuButton() {
        menuButton = Button(this).apply {
            text = "⋯"
            textSize = 24f
            setTextColor(Color.WHITE)
            contentDescription = "Menu"
            gravity = Gravity.CENTER
            minWidth = 0
            minHeight = 0
            setPadding(0, 0, 0, dp(6))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.argb(190, 20, 20, 20))
                setStroke(dp(1), Color.argb(100, 255, 255, 255))
            }
            setOnClickListener { showKartPadMenu() }
        }
        val params = RelativeLayout.LayoutParams(dp(44), dp(44)).apply {
            addRule(RelativeLayout.ALIGN_PARENT_END)
            addRule(RelativeLayout.ALIGN_PARENT_TOP)
            setMargins(0, dp(8), dp(12), 0)
        }
        mLayout.addView(menuButton, params)
        menuButton.setOnApplyWindowInsetsListener { _, insets ->
            applyMenuSafeInsets(insets)
            insets
        }
        menuButton.requestApplyInsets()
    }

    @Suppress("DEPRECATION")
    private fun applyMenuSafeInsets(insets: WindowInsets) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val safe = insets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout(),
            )
            menuSafeInsetTop = safe.top
            menuSafeInsetEnd = safe.right
            menuSafeInsetBottom = safe.bottom
        } else {
            menuSafeInsetTop = maxOf(
                insets.stableInsetTop,
                insets.systemWindowInsetTop,
                insets.displayCutout?.safeInsetTop ?: 0,
            )
            menuSafeInsetEnd = maxOf(
                insets.stableInsetRight,
                insets.systemWindowInsetRight,
                insets.displayCutout?.safeInsetRight ?: 0,
            )
            menuSafeInsetBottom = maxOf(
                insets.stableInsetBottom,
                insets.systemWindowInsetBottom,
                insets.displayCutout?.safeInsetBottom ?: 0,
            )
        }
        (menuButton.layoutParams as? RelativeLayout.LayoutParams)?.let { params ->
            params.topMargin = menuSafeInsetTop + dp(8)
            params.marginEnd = menuSafeInsetEnd + dp(12)
            menuButton.layoutParams = params
        }
    }

    private fun showKartPadMenu() {
        kartPadOverlay.clearTouchInput()
        showKartPadMenuPage(
            "KartPad",
            listOf(
                MenuRow("Switch Game Version…", R.drawable.ic_kartpad_gobackward) {
                    closeKartPadMenu(::confirmSwitchGameVersion)
                },
                MenuRow("Multiplayer…", R.drawable.ic_kartpad_multiplayer) {
                    closeKartPadMenu(::showMultiplayer)
                },
                MenuRow(
                    "Show FPS Counter",
                    R.drawable.ic_kartpad_speedometer,
                    checked = KartPadTouchSettings.showFps(this),
                ) {
                    val show = !KartPadTouchSettings.showFps(this)
                    setShowFps(show)
                    showKartPadMenu()
                },
                MenuRow("Controls", R.drawable.ic_kartpad_gamecontroller, submenu = true) {
                    showControlsMenu()
                },
                MenuRow("Display", R.drawable.ic_kartpad_display, submenu = true) {
                    showDisplayMenu()
                },
                MenuRow("Game Data & Saves", R.drawable.ic_kartpad_folder, submenu = true) {
                    showGameDataMenu()
                },
                MenuRow("Report a Problem…", R.drawable.ic_kartpad_report) {
                    closeKartPadMenu(::showReportProblem)
                },
            ),
        )
    }

    private fun showControlsMenu() = showKartPadMenuPage(
        "Controls",
        listOf(
            MenuRow("Controller Player Setup…", R.drawable.ic_kartpad_gamecontroller) {
                closeKartPadMenu(::showControllerPlayers)
            },
            MenuRow("Controller Button Mapping…", R.drawable.ic_kartpad_gamecontroller) {
                closeKartPadMenu(::showControllerMapping)
            },
            MenuRow("Touch Control Settings…", R.drawable.ic_kartpad_hand) {
                closeKartPadMenu(::showTouchControlSettings)
            },
            MenuRow("Motion Steering…", R.drawable.ic_kartpad_gyroscope) {
                closeKartPadMenu(::showMotionSteering)
            },
            MenuRow("Experimental Wii Remote + Nunchuk…", R.drawable.ic_kartpad_antenna) {
                closeKartPadMenu {
                    showParityBoundary(
                        "Experimental Wii Remote + Nunchuk",
                        "Direct Wii Remote pairing is not available in this Android build. Android-supported Bluetooth and USB gamepads still work through the controller layer.",
                    )
                }
            },
        ),
        showBack = true,
    )

    private fun showDisplayMenu() = showKartPadMenuPage(
        "Display",
        listOf(
            MenuRow("Aspect Ratio…", R.drawable.ic_kartpad_display) {
                closeKartPadMenu(::showAspectRatioSettings)
            },
            MenuRow("Render Resolution…", R.drawable.ic_kartpad_display) {
                closeKartPadMenu(::showResolutionSettings)
            },
        ),
        showBack = true,
    )

    private fun showGameDataMenu() = showKartPadMenuPage(
        "Game Data & Saves",
        listOf(
            MenuRow("Import or Reimport Wii Disc Image…", R.drawable.ic_kartpad_refresh) {
                closeKartPadMenu {
                    openGameDataManager(KartPadGameDataActivity.ACTION_IMPORT)
                }
            },
            MenuRow("Import from Extracted Folder…", R.drawable.ic_kartpad_folder) {
                closeKartPadMenu {
                    openGameDataManager(KartPadGameDataActivity.ACTION_IMPORT_FOLDER)
                }
            },
            MenuRow("Remove Stored Game Data…", R.drawable.ic_kartpad_trash) {
                closeKartPadMenu {
                    openGameDataManager(KartPadGameDataActivity.ACTION_REMOVE)
                }
            },
            MenuRow("Manage Retro Rewind…", R.drawable.ic_kartpad_gobackward) {
                closeKartPadMenu {
                    startActivity(Intent(this, RetroRewindInstallActivity::class.java))
                }
            },
            MenuRow("Manage Saves…", R.drawable.ic_kartpad_folder) {
                closeKartPadMenu(::showSaveManager)
            },
            MenuRow("Manage Miis…", R.drawable.ic_kartpad_mii) {
                closeKartPadMenu(::showMiiManager)
            },
        ),
        showBack = true,
    )

    private fun showKartPadMenuPage(
        title: String,
        rows: List<MenuRow>,
        showBack: Boolean = false,
    ) {
        kartPadMenu?.dismiss()
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                cornerRadius = dp(20).toFloat()
                setColor(Color.argb(246, 238, 238, 240))
                setStroke(dp(1), Color.argb(80, 255, 255, 255))
            }
            clipToOutline = true
        }
        val heading = TextView(this).apply {
            text = if (showBack) "‹  $title" else title
            contentDescription = title
            textSize = 14f
            setTextColor(Color.rgb(92, 92, 98))
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(18), 0, dp(18), 0)
            isClickable = showBack
            isFocusable = showBack
            if (showBack) setOnClickListener { showKartPadMenu() }
        }
        card.addView(heading, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(38),
        ))
        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val rowHeights = rows.map(::kartPadMenuRowHeight)
        rows.forEachIndexed { index, row ->
            if (index > 0) list.addView(View(this).apply {
                setBackgroundColor(Color.argb(44, 60, 60, 67))
            }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 1).apply {
                marginStart = dp(52)
            })
            list.addView(kartPadMenuRow(row), LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                rowHeights[index],
            ))
        }
        card.addView(ScrollView(this).apply {
            isFillViewport = false
            addView(list)
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            0,
            1f,
        ))
        // Keep the whole iOS-sized menu card inside the short landscape viewport.
        // It intentionally covers its trigger while open, like an anchored system menu.
        val popupTop = menuSafeInsetTop + dp(8)
        val popupEnd = menuSafeInsetEnd + dp(12)
        val availableHeight = (
            resources.displayMetrics.heightPixels - popupTop - menuSafeInsetBottom - dp(16)
        ).coerceAtLeast(dp(88))
        val desiredHeight = dp(38) + rowHeights.sum() + (rows.size - 1).coerceAtLeast(0)
        kartPadMenu = PopupWindow(card, dp(320), minOf(availableHeight, desiredHeight), true).apply {
            isOutsideTouchable = true
            elevation = dp(12).toFloat()
            setBackgroundDrawable(GradientDrawable().apply { setColor(Color.TRANSPARENT) })
            setOnDismissListener { if (kartPadMenu === this) kartPadMenu = null }
            showAtLocation(mLayout, Gravity.TOP or Gravity.END, popupEnd, popupTop)
        }
    }

    private fun kartPadMenuRow(row: MenuRow): View = LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(dp(13), 0, dp(10), 0)
        contentDescription = row.title
        isClickable = true
        isFocusable = true
        background = android.graphics.drawable.StateListDrawable().apply {
            addState(
                intArrayOf(android.R.attr.state_pressed),
                GradientDrawable().apply { setColor(Color.argb(42, 60, 60, 67)) },
            )
            addState(intArrayOf(), GradientDrawable().apply { setColor(Color.TRANSPARENT) })
        }
        addView(ImageView(this@KartPadActivity).apply {
            setImageResource(row.icon)
            imageTintList = android.content.res.ColorStateList.valueOf(Color.rgb(38, 38, 40))
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(dp(22), dp(22)).apply { marginEnd = dp(12) })
        addView(TextView(this@KartPadActivity).apply {
            text = row.title
            textSize = 16f
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            setTextColor(Color.rgb(22, 22, 24))
            gravity = Gravity.CENTER_VERTICAL
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f))
        if (row.checked || row.submenu) addView(TextView(this@KartPadActivity).apply {
            text = if (row.checked) "✓" else "›"
            textSize = if (row.checked) 18f else 28f
            setTextColor(Color.rgb(55, 55, 58))
            gravity = Gravity.CENTER
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LinearLayout.LayoutParams(dp(24), ViewGroup.LayoutParams.MATCH_PARENT))
        setOnClickListener { row.action() }
    }

    private fun kartPadMenuRowHeight(row: MenuRow): Int {
        val trailingWidth = if (row.checked || row.submenu) 24 else 0
        val availableTextWidth = dp(320 - 13 - 10 - 22 - 12 - trailingWidth)
        val paint = Paint().apply {
            textSize = sp(16f)
        }
        val lineCount = ceil(paint.measureText(row.title) / availableTextWidth)
            .toInt()
            .coerceIn(1, 2)
        val scaledLineHeight = sp(21f)
        return maxOf(dp(44), dp(12) + (scaledLineHeight * lineCount).roundToInt())
    }

    private fun closeKartPadMenu(action: () -> Unit) {
        kartPadMenu?.dismiss()
        action()
    }

    private fun setShowFps(show: Boolean) {
        KartPadTouchSettings.setShowFps(this, show)
        applyDisplaySettings()
    }

    private fun confirmSwitchGameVersion() {
        AlertDialog.Builder(this)
            .setTitle("Switch Game Version")
            .setMessage(
                "KartPad must restart the game runtime before switching between Original Mario Kart Wii and Retro Rewind.",
            )
            .setPositiveButton("Restart to Selector") { _, _ -> restartToGameSelector() }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun restartToGameSelector() {
        kartPadOverlay.clearTouchInput()
        val chooser = Intent(this, KartPadLaunchActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        startActivity(chooser)
        menuButton.postDelayed({ kotlin.system.exitProcess(0) }, SELECTOR_RESTART_DELAY_MS)
    }

    private fun openGameDataManager(action: String) {
        startActivityForResult(
            Intent(this, KartPadGameDataActivity::class.java)
                .putExtra(KartPadGameDataActivity.EXTRA_ACTION, action),
            REQUEST_MANAGE_GAME_DATA,
        )
    }

    private fun applyDisplaySettings() {
        nativeApplyDisplaySettings(
            KartPadTouchSettings.showFps(this),
            KartPadTouchSettings.aspectMode(this),
            KartPadTouchSettings.resolutionScale(this),
        )
    }

    private fun showAspectRatioSettings() {
        val labels = arrayOf(
            "Original 4:3",
            "16:9 (Experimental)",
            "Fill Screen (Experimental)",
        )
        AlertDialog.Builder(this)
            .setTitle("Aspect Ratio")
            .setSingleChoiceItems(labels, KartPadTouchSettings.aspectMode(this)) { dialog, which ->
                KartPadTouchSettings.setAspectMode(this, which)
                applyDisplaySettings()
                dialog.dismiss()
            }
            .setNegativeButton("Back", null)
            .show()
    }

    private fun showResolutionSettings() {
        val labels = arrayOf("1× (Native)", "2×", "3×", "4×")
        val scales = floatArrayOf(1f, 2f, 3f, 4f)
        val selected = scales.indexOfFirst {
            kotlin.math.abs(it - KartPadTouchSettings.resolutionScale(this)) < 0.01f
        }.coerceAtLeast(0)
        AlertDialog.Builder(this)
            .setTitle("Render Resolution")
            .setSingleChoiceItems(labels, selected) { dialog, which ->
                KartPadTouchSettings.setResolutionScale(this, scales[which])
                applyDisplaySettings()
                dialog.dismiss()
            }
            .setNegativeButton("Back", null)
            .show()
    }

    private fun showMultiplayer() {
        val retro = runtimeProfile == "retro_rewind"
        val message = if (retro) {
            "Retro Rewind is active. Choose Nintendo WFC in the game for Retro WFC online play."
        } else {
            "Online multiplayer is available only through Retro Rewind. The original Mario Kart Wii online service is no longer available."
        }
        AlertDialog.Builder(this)
            .setTitle("Multiplayer")
            .setMessage(message)
            .apply {
                if (!retro) setPositiveButton("Set Up Retro Rewind") { _, _ ->
                    startActivity(Intent(this@KartPadActivity, RetroRewindInstallActivity::class.java))
                }
            }
            .setNegativeButton("Back", null)
            .show()
    }

    private fun nativeControllers(): List<NativeController> =
        nativeControllerDevices().mapNotNull { row ->
            val parts = row.split('\t', limit = 3)
            if (parts.size != 3) return@mapNotNull null
            val instance = parts[0].toLongOrNull() ?: return@mapNotNull null
            val player = parts[1].toIntOrNull() ?: return@mapNotNull null
            NativeController(instance, player, parts[2].ifBlank { "Controller" })
        }

    private fun showControllerPlayers() {
        kartPadOverlay.clearTouchInput()
        val controllers = nativeControllers()
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(4), dp(24), dp(8))
        }
        content.addView(settingsLabel(if (controllers.isEmpty()) {
            "No SDL game controller is connected. Connect an Android-supported Bluetooth or USB controller, then reopen this screen."
        } else {
            "Assign each connected controller to one player. Assignments follow the controller when it reconnects. Moving a controller clears its old player; choosing an occupied player safely replaces that assignment."
        }))
        lateinit var dialog: AlertDialog
        for (player in 0 until 4) {
            val assigned = controllers.firstOrNull { it.player == player }
            content.addView(Button(this).apply {
                text = "Player ${player + 1} — ${assigned?.name ?: playerEmptyLabel(player)}"
                contentDescription =
                    "Player ${player + 1}, ${assigned?.name ?: playerEmptyLabel(player)}"
                setOnClickListener {
                    dialog.dismiss()
                    showControllerPlayerChoices(player)
                }
            })
        }
        content.addView(Button(this).apply {
            text = "Done"
            contentDescription = "Close controller player setup"
            setOnClickListener { dialog.dismiss() }
        })
        dialog = AlertDialog.Builder(this)
            .setTitle("Controller Player Setup")
            .setView(ScrollView(this).apply { addView(content) })
            .create()
        dialog.show()
    }

    private fun showControllerPlayerChoices(player: Int) {
        val controllers = nativeControllers()
        val labels = ArrayList<String>().apply {
            add(playerEmptyLabel(player))
            controllers.forEach { controller ->
                add(if (controller.player in 0 until 4) {
                    "${controller.name} — currently Player ${controller.player + 1}"
                } else {
                    "${controller.name} — unassigned"
                })
            }
        }
        AlertDialog.Builder(this)
            .setTitle("Player ${player + 1}")
            .setSingleChoiceItems(
                labels.toTypedArray(),
                controllers.indexOfFirst { it.player == player } + 1,
            ) { dialog, which ->
                val success = if (which == 0) {
                    nativeClearControllerPlayer(player)
                } else {
                    nativeAssignControllerPlayer(controllers[which - 1].instance, player)
                }
                dialog.dismiss()
                if (!success) {
                    AlertDialog.Builder(this)
                        .setTitle("Controller Changed")
                        .setMessage(
                            "That controller disconnected before the assignment completed. Reconnect it and try again.",
                        )
                        .setPositiveButton("OK") { _, _ -> showControllerPlayers() }
                        .show()
                } else {
                    kartPadOverlay.clearTouchInput()
                    refreshControllerHandoff()
                    menuButton.post { showControllerPlayers() }
                }
            }
            .setNegativeButton("Back") { _, _ -> showControllerPlayers() }
            .show()
    }

    private fun playerEmptyLabel(player: Int): String = if (player == 0) {
        "Automatic when one controller is connected"
    } else {
        "No controller"
    }

    private fun showControllerMapping() {
        val controllers = inputManager.inputDeviceIds.toList().mapNotNull { id ->
            inputManager.getInputDevice(id)?.takeIf(::isGameController)?.name
        }
        val mapping = KartPadControllerMapping.load(this)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(4), dp(24), dp(8))
        }
        content.addView(settingsLabel(if (controllers.isEmpty()) {
            "No extended controller is connected. You can review or reset the saved mapping; connect a controller to test it."
        } else {
            "Connected: ${controllers.joinToString()}. Only A, B, X, Y, and Z are remapped. Analog triggers, sticks, D-pad, Start, and the right shoulder stay direct."
        }))
        lateinit var dialog: AlertDialog
        KartPadControllerMapping.gameButtonNames.forEachIndexed { game, gameName ->
            content.addView(Button(this).apply {
                val physical = KartPadControllerMapping.physicalButtonNames[mapping[game]]
                text = "$gameName — $physical"
                contentDescription = "Game $gameName mapped to physical $physical"
                setOnClickListener {
                    dialog.dismiss()
                    showControllerMappingChoices(game)
                }
            })
        }
        content.addView(Button(this).apply {
            text = "Reset to Default"
            contentDescription = "Reset controller mapping to default"
            setOnClickListener {
                KartPadControllerMapping.reset(this@KartPadActivity)
                applyControllerMapping()
                dialog.dismiss()
                menuButton.post { showControllerMapping() }
            }
        })
        content.addView(Button(this).apply {
            text = "Done"
            contentDescription = "Close controller button mapping"
            setOnClickListener { dialog.dismiss() }
        })
        dialog = AlertDialog.Builder(this)
            .setTitle("Controller Button Mapping")
            .setView(ScrollView(this).apply { addView(content) })
            .create()
        dialog.show()
    }

    private fun showControllerMappingChoices(game: Int) {
        val gameName = KartPadControllerMapping.gameButtonNames[game]
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(4), dp(24), dp(8))
        }
        content.addView(settingsLabel(
            "Choose the physical controller button. If it is already assigned, the two assignments swap.",
        ))
        lateinit var dialog: AlertDialog
        KartPadControllerMapping.physicalButtonNames.forEachIndexed { physical, name ->
            content.addView(Button(this).apply {
                text = name
                contentDescription = "Map game $gameName to physical $name"
                setOnClickListener {
                    KartPadControllerMapping.assign(this@KartPadActivity, game, physical)
                    applyControllerMapping()
                    dialog.dismiss()
                    menuButton.post { showControllerMapping() }
                }
            })
        }
        content.addView(Button(this).apply {
            text = "Cancel"
            setOnClickListener {
                dialog.dismiss()
                menuButton.post { showControllerMapping() }
            }
        })
        dialog = AlertDialog.Builder(this)
            .setTitle(gameName)
            .setView(ScrollView(this).apply { addView(content) })
            .create()
        dialog.show()
    }

    private fun applyControllerMapping() {
        nativeApplyControllerMapping(KartPadControllerMapping.load(this))
    }

    private fun showMotionSteering() {
        val available = motionSteering.sensorAvailable
        val state = when {
            !available -> "Unavailable on this device"
            motionSteering.enabled -> "On"
            else -> "Off"
        }
        val actions = if (!available) {
            arrayOf("Continue Playing")
        } else if (motionSteering.enabled) {
            arrayOf(
                "Turn Off",
                "Recenter Now",
                if (motionSteering.inverted) "Use Standard Direction" else "Invert Direction",
                "Cycle Sensitivity",
                "Continue Playing",
            )
        } else {
            arrayOf(
                "Turn On & Recenter",
                if (motionSteering.inverted) "Use Standard Direction" else "Invert Direction",
                "Cycle Sensitivity",
                "Continue Playing",
            )
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(4), dp(24), dp(8))
        }
        content.addView(settingsLabel(if (available) {
            "Tilt the device like a steering wheel. Current state: $state. " +
                "Sensitivity: ${motionSteering.sensitivity}x. Physical controllers take priority."
        } else {
            "Motion data is unavailable on this device or emulator. Touch and " +
                "physical-controller steering remain available."
        }))
        val dialog = AlertDialog.Builder(this)
            .setTitle("Motion Steering")
            .setView(ScrollView(this).apply { addView(content) })
            .create()
        actions.forEach { action ->
            content.addView(Button(this).apply {
                text = action
                contentDescription = action
                setOnClickListener {
                    dialog.dismiss()
                    when (action) {
                    "Turn Off" -> motionSteering.setEnabled(false)
                    "Recenter Now" -> motionSteering.recenter()
                    "Invert Direction" -> motionSteering.setInverted(true)
                    "Use Standard Direction" -> motionSteering.setInverted(false)
                    "Cycle Sensitivity" -> motionSteering.setSensitivity(
                        when (motionSteering.sensitivity) {
                            0.5f -> 1f
                            1f -> 2f
                            else -> 0.5f
                        },
                    )
                    "Turn On & Recenter" -> {
                        motionSteering.setEnabled(true)
                        motionSteering.recenter()
                    }
                    }
                    if (action != "Continue Playing") {
                        menuButton.post { showMotionSteering() }
                    }
                }
            })
        }
        dialog.show()
    }

    private fun showMiiManager() {
        kartPadOverlay.clearTouchInput()
        val database = runCatching { KartPadMiiStorage.readWorking(filesDir) }
            .getOrElse { error ->
                showParityBoundary(
                    "Manage Miis (Experimental)",
                    safeMiiError(error, "The Mii database could not be read."),
                )
                return
            }
        val records = runCatching { parseMiiRecords(nativeListMiis(database)) }
            .getOrElse { error ->
                showParityBoundary(
                    "Miis Could Not Be Read",
                    safeMiiError(error, "The Mii database failed validation."),
                )
                return
            }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(4), dp(24), dp(8))
        }
        lateinit var dialog: AlertDialog
        val pending = if (KartPadMiiStorage.hasPending(filesDir)) {
            " Changes are staged for the next game restart."
        } else {
            ""
        }
        content.addView(settingsLabel(
            "${records.size} Mii${if (records.size == 1) "" else "s"} available.$pending",
        ))
        content.addView(Button(this).apply {
            text = "Import Mii…"
            contentDescription = "Import a standard Mii file"
            setOnClickListener {
                startActivityForResult(
                    Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/octet-stream"
                    },
                    REQUEST_IMPORT_MII,
                )
            }
        })
        content.addView(Button(this).apply {
            text = "Remove a Mii…"
            contentDescription = "Remove a Mii"
            isEnabled = records.isNotEmpty()
            setOnClickListener { showMiiRemoval(records) }
        })
        content.addView(Button(this).apply {
            text = "Create a Mii…"
            contentDescription = "Learn how to create a Mii"
            setOnClickListener {
                AlertDialog.Builder(this@KartPadActivity)
                    .setTitle("Create a Mii")
                    .setMessage(
                        "KartPad does not include the Wii Menu or Mii Channel, so it cannot create a new Mii. Create or export a standard 74-byte .mii file with a compatible tool, then import it here.",
                    )
                    .setNegativeButton("Back", null)
                    .show()
            }
        })
        content.addView(Button(this).apply {
            text = "Done"
            contentDescription = "Close Mii manager"
            setOnClickListener { dialog.dismiss() }
        })
        dialog = AlertDialog.Builder(this)
            .setTitle("Manage Miis (Experimental)")
            .setView(ScrollView(this).apply { addView(content) })
            .create()
        dialog.show()
    }

    private fun showSaveManager() {
        kartPadOverlay.clearTouchInput()
        val validSave = runCatching { KartPadSaveStorage.readActive(filesDir) }.isSuccess
        val pending = KartPadSaveStorage.hasPending(filesDir)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(4), dp(24), dp(8))
        }
        lateinit var dialog: AlertDialog
        content.addView(settingsLabel(when {
            pending -> "A validated save restore is staged for the next game restart."
            validSave -> "A validated Mario Kart Wii save is available for backup."
            else -> "No initialized Mario Kart Wii save exists yet. Create a license in the game first."
        }))
        content.addView(Button(this).apply {
            text = "Export Save Backup…"
            contentDescription = "Export Mario Kart Wii save backup"
            isEnabled = validSave
            setOnClickListener {
                startActivityForResult(
                    Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, "KartPad-RMCP01-rksys.dat")
                    },
                    REQUEST_EXPORT_SAVE,
                )
            }
        })
        content.addView(Button(this).apply {
            text = "Restore Save Backup…"
            contentDescription = "Restore Mario Kart Wii save backup"
            setOnClickListener {
                startActivityForResult(
                    Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/octet-stream"
                    },
                    REQUEST_IMPORT_SAVE,
                )
            }
        })
        content.addView(Button(this).apply {
            text = "Done"
            setOnClickListener { dialog.dismiss() }
        })
        dialog = AlertDialog.Builder(this)
            .setTitle("Manage Saves")
            .setView(ScrollView(this).apply { addView(content) })
            .create()
        dialog.show()
    }

    private fun showMiiRemoval(records: List<MiiRecord>) {
        if (records.isEmpty()) return
        val labels = records.map { record ->
            if (record.creator == "Unknown") record.name
            else "${record.name} — creator ${record.creator}"
        }.toTypedArray()
        AlertDialog.Builder(this)
            .setTitle("Remove a Mii")
            .setItems(labels) { _, which -> confirmMiiRemoval(records[which]) }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun confirmMiiRemoval(record: MiiRecord) {
        AlertDialog.Builder(this)
            .setTitle("Remove ${record.name}?")
            .setMessage(
                "The removal will apply after restarting the game. KartPad retains a backup and always keeps at least one Mii.",
            )
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Remove") { _, _ ->
                runCatching {
                    val working = KartPadMiiStorage.readWorking(filesDir)
                    KartPadMiiStorage.writePending(
                        filesDir, nativeRemoveMii(working, record.slot),
                    )
                }.onSuccess {
                    showMiiChangeReady("${record.name} will be removed.")
                }.onFailure { error ->
                    showParityBoundary(
                        "Mii Could Not Be Removed",
                        safeMiiError(error, "The Mii removal could not be staged."),
                    )
                }
            }
            .show()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_MANAGE_GAME_DATA && resultCode == RESULT_OK) {
            AlertDialog.Builder(this)
                .setTitle("Game Data Changed")
                .setMessage("Restart KartPad to apply the game-data change and choose Original Mario Kart Wii or Retro Rewind.")
                .setPositiveButton("Restart to Selector") { _, _ -> restartToGameSelector() }
                .setNegativeButton("Later", null)
                .show()
            return
        }
        if (requestCode == REQUEST_EXPORT_SAVE && resultCode == RESULT_OK) {
            val uri = data?.data ?: return
            runCatching {
                val save = KartPadSaveStorage.readActive(filesDir)
                contentResolver.openOutputStream(uri, "wt")
                    ?.use { it.write(save) } ?: error("The selected destination could not be opened.")
            }.onSuccess {
                showParityBoundary("Save Backup Exported", "The validated RKSYS save backup was exported.")
            }.onFailure {
                showParityBoundary("Save Export Failed", "The save backup could not be exported.")
            }
            return
        }
        if (requestCode == REQUEST_IMPORT_SAVE && resultCode == RESULT_OK) {
            val uri = data?.data ?: return
            runCatching {
                val input = contentResolver.openInputStream(uri)
                    ?: error("The selected save could not be opened.")
                val save = input.use { stream ->
                    val buffer = ByteArray(KartPadSaveStorage.SAVE_BYTES + 1)
                    var count = 0
                    while (count < buffer.size) {
                        val read = stream.read(buffer, count, buffer.size - count)
                        if (read < 0) break
                        count += read
                    }
                    require(count == KartPadSaveStorage.SAVE_BYTES) {
                        "A Mario Kart Wii save must be exactly ${KartPadSaveStorage.SAVE_BYTES} bytes."
                    }
                    buffer.copyOf(count)
                }
                KartPadSaveStorage.writePending(filesDir, save)
            }.onSuccess {
                AlertDialog.Builder(this)
                    .setTitle("Save Restore Scheduled")
                    .setMessage("The validated save will replace the current save after restarting. KartPad will retain a backup of the current save automatically.")
                    .setPositiveButton("Restart Now") { _, _ -> restartToGameSelector() }
                    .setNegativeButton("Later", null)
                    .show()
            }.onFailure { error ->
                showParityBoundary(
                    "Save Restore Failed",
                    if (error is IllegalArgumentException && !error.message.isNullOrBlank()) {
                        error.message!!
                    } else {
                        "The selected save could not be validated."
                    },
                )
            }
            return
        }
        if (requestCode != REQUEST_IMPORT_MII || resultCode != RESULT_OK) return
        val uri = data?.data ?: return
        runCatching {
            val mii = readMiiDocument(uri)
            val working = KartPadMiiStorage.readWorking(filesDir)
            KartPadMiiStorage.writePending(
                filesDir, nativeImportMii(working, mii),
            )
        }.onSuccess {
            showMiiChangeReady("The selected Mii will be imported.")
        }.onFailure { error ->
            showParityBoundary(
                "Mii Import Failed",
                safeMiiError(error, "The selected Mii could not be imported."),
            )
        }
    }

    private fun readMiiDocument(uri: Uri): ByteArray {
        val input = contentResolver.openInputStream(uri)
            ?: error("The selected Mii file could not be opened.")
        input.use { stream ->
            val buffer = ByteArray(MII_FILE_BYTES + 1)
            var count = 0
            while (count < buffer.size) {
                val read = stream.read(buffer, count, buffer.size - count)
                if (read < 0) break
                count += read
            }
            require(count == MII_FILE_BYTES) {
                "A Mii file must contain exactly $MII_FILE_BYTES bytes."
            }
            return buffer.copyOf(MII_FILE_BYTES)
        }
    }

    private fun showMiiChangeReady(message: String) {
        AlertDialog.Builder(this)
            .setTitle("Mii Change Scheduled")
            .setMessage("$message The current database will be backed up automatically.")
            .setPositiveButton("Restart Now") { _, _ -> restartToGameSelector() }
            .setNegativeButton("Later", null)
            .show()
    }

    private fun parseMiiRecords(values: Array<String>): List<MiiRecord> {
        require(values.size % 3 == 0) { "The native Mii list is malformed." }
        return values.asList().chunked(3).map { valuesForRecord ->
            MiiRecord(
                slot = valuesForRecord[0].toInt(),
                name = valuesForRecord[1],
                creator = valuesForRecord[2],
            )
        }
    }

    private fun safeMiiError(error: Throwable, fallback: String): String =
        if (error is IllegalArgumentException && !error.message.isNullOrBlank()) {
            error.message!!
        } else {
            fallback
        }

    private fun showReportProblem() {
        val fields = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(4), dp(24), 0)
        }
        val problem = EditText(this).apply {
            hint = "What went wrong?"
            contentDescription = "What went wrong"
            isSingleLine = false
            minLines = 2
            maxLines = 4
        }
        val area = EditText(this).apply {
            hint = "Area and what you were doing (optional)"
            contentDescription = "Area and what you were doing"
            isSingleLine = true
        }
        val frequency = EditText(this).apply {
            hint = "Every time, sometimes, once, or not sure?"
            contentDescription = "How often the problem happens"
            isSingleLine = true
        }
        fields.addView(problem)
        fields.addView(area)
        fields.addView(frequency)

        fun reportId() = "KP-${UUID.randomUUID().toString().take(8).uppercase()}"
        fun diagnosticReport(id: String) = buildString {
            appendLine("KartPad Android diagnostic report")
            appendLine("Report ID: $id")
            appendLine("Version: ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
            appendLine("Android: ${android.os.Build.VERSION.RELEASE} (API ${android.os.Build.VERSION.SDK_INT})")
            appendLine("Device: ${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}")
            appendLine("Runtime profile: $runtimeProfile")
            appendLine("Retro Rewind release: ${RetroRewindRelease.VERSION}")
            appendLine()
            appendLine("What went wrong:")
            appendLine(problem.text.toString().trim().ifBlank { "Not provided" })
            appendLine()
            appendLine("Area and what you were doing:")
            appendLine(area.text.toString().trim().ifBlank { "Not provided" })
            appendLine()
            appendLine("Frequency:")
            appendLine(frequency.text.toString().trim().ifBlank { "Not provided" })
        }
        AlertDialog.Builder(this)
            .setTitle("Report a Problem")
            .setMessage("Answer briefly and KartPad will add a bounded technical summary. It excludes game data, saves, credentials, controller inputs, and local file paths. GitHub reports are public.")
            .setView(fields)
            .setPositiveButton("Share Report…") { _, _ ->
                val id = reportId()
                startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_SUBJECT, "KartPad Android problem $id")
                    putExtra(Intent.EXTRA_TEXT, diagnosticReport(id))
                }, "Share KartPad report"))
            }
            .setNeutralButton("Report on GitHub") { _, _ ->
                val id = reportId()
                val summary = problem.text.toString().trim().ifBlank { "KartPad problem" }
                val url = Uri.parse("https://github.com/chrissotraidis/kartpad/issues/new")
                    .buildUpon()
                    .appendQueryParameter("template", "bug_report.yml")
                    .appendQueryParameter("title", "[Bug]: ${summary.take(100)}")
                    .appendQueryParameter("report-id", id)
                    .appendQueryParameter(
                        "revision", "${BuildConfig.VERSION_NAME} (build ${BuildConfig.VERSION_CODE})",
                    )
                    .appendQueryParameter("platform", "Android ${android.os.Build.VERSION.RELEASE}")
                    .appendQueryParameter("performance-profile", runtimeProfile)
                    .appendQueryParameter("summary", problem.text.toString().trim())
                    .appendQueryParameter("context", area.text.toString().trim())
                    .appendQueryParameter("frequency", frequency.text.toString().trim())
                    .build()
                startActivity(Intent(Intent.ACTION_VIEW, url))
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showParityBoundary(title: String, message: String) {
        AlertDialog.Builder(this)
            .setTitle(title)
            .setMessage(message)
            .setNegativeButton("Back", null)
            .show()
    }

    @Suppress("SetTextI18n")
    private fun showTouchControlSettings(
        debugEditorFlow: Boolean = false,
        debugSettingsFlow: String? = null,
    ) {
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(dp(18), dp(4), dp(18), dp(4))
        }
        val opacityLabel = settingsLabel("")
        val renderLabel = settingsLabel("Render")
        val renderScales = floatArrayOf(1f, 2f, 3f, 4f)
        val render = RadioGroup(this).apply {
            orientation = RadioGroup.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            contentDescription = "Render resolution"
        }
        val currentRenderScale = KartPadTouchSettings.resolutionScale(this)
        renderScales.forEach { scale ->
            render.addView(RadioButton(this).apply {
                id = View.generateViewId()
                text = if (scale == 1f) "1×" else "${scale.toInt()}×"
                setTextColor(Color.WHITE)
                tag = scale
                isChecked = kotlin.math.abs(scale - currentRenderScale) < 0.01f
            })
        }
        render.setOnCheckedChangeListener { group, checkedId ->
            val scale = group.findViewById<RadioButton>(checkedId)?.tag as? Float
                ?: return@setOnCheckedChangeListener
            KartPadTouchSettings.setResolutionScale(this, scale)
            applyDisplaySettings()
        }
        val opacity = SeekBar(this).apply {
            max = 75
            progress = (KartPadTouchSettings.opacity(this@KartPadActivity) * 100f)
                .roundToInt() - 25
            contentDescription = "Control opacity"
        }
        fun refreshOpacityLabel() {
            opacityLabel.text = "Opacity: ${opacity.progress + 25}%"
        }
        refreshOpacityLabel()
        opacity.setOnSeekBarChangeListener(simpleSeekListener {
            KartPadTouchSettings.setOpacity(this, (opacity.progress + 25) / 100f)
            kartPadOverlay.reloadPresentationSettings()
            refreshOpacityLabel()
        })

        val sizeLabel = settingsLabel("")
        val size = SeekBar(this).apply {
            max = 65
            progress = (KartPadTouchSettings.size(this@KartPadActivity) * 100f)
                .roundToInt() - 70
            contentDescription = "All control sizes"
        }
        fun refreshSizeLabel() {
            sizeLabel.text = "All sizes: ${size.progress + 70}%"
        }
        refreshSizeLabel()
        size.setOnSeekBarChangeListener(simpleSeekListener {
            KartPadTouchSettings.setSize(this, (size.progress + 70) / 100f)
            kartPadOverlay.reloadPresentationSettings()
            refreshSizeLabel()
        })

        val hide = Switch(this).apply {
            text = "Hide on controller"
            setTextColor(Color.WHITE)
            isChecked = KartPadTouchSettings.hideOnController(this@KartPadActivity)
            contentDescription = "Hide touch controls when controller connected"
            setOnCheckedChangeListener { _, checked ->
                KartPadTouchSettings.setHideOnController(this@KartPadActivity, checked)
                refreshControllerHandoff()
            }
        }
        val modernCStick = Switch(this).apply {
            text = "Modern C-stick L/R"
            setTextColor(Color.WHITE)
            isChecked = KartPadTouchSettings.modernCStickHorizontal(this@KartPadActivity)
            contentDescription = "Reverse C-stick horizontal direction"
            setOnCheckedChangeListener { _, checked ->
                KartPadTouchSettings.setModernCStickHorizontal(
                    this@KartPadActivity, checked,
                )
                kartPadOverlay.reloadPresentationSettings()
            }
        }
        val moveControls = Button(this).apply {
            text = "Move controls"
            contentDescription = "Edit touch control layout"
        }
        resetTouchLayoutButton = Button(this).apply {
            text = "Reset This Device Layout"
            contentDescription = "Reset touch control layout"
            setOnClickListener {
                val confirm = AlertDialog.Builder(this@KartPadActivity)
                    .setTitle("Reset Touch Control Layout?")
                    .setMessage(
                        "All control positions and sizes return to their defaults.",
                    )
                    .setNegativeButton("Cancel", null)
                    .setPositiveButton("Reset") { _, _ ->
                        opacity.progress = 57
                        size.progress = 30
                        kartPadOverlay.resetLayoutSettings()
                        refreshControllerHandoff()
                    }
                    .create()
                confirm.setOnDismissListener { resetTouchLayoutDialog = null }
                confirm.show()
                resetTouchLayoutDialog = confirm
            }
        }
        val leftColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 0, dp(12), 0)
            addView(renderLabel)
            addView(render)
            addView(opacityLabel)
            addView(opacity)
            addView(sizeLabel)
            addView(size)
        }
        val rightColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(8), 0, 0)
            addView(hide)
            addView(modernCStick)
            addView(moveControls)
            addView(resetTouchLayoutButton)
        }
        content.addView(leftColumn, LinearLayout.LayoutParams(
            0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f,
        ))
        content.addView(rightColumn, LinearLayout.LayoutParams(
            0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f,
        ))
        val scroll = ScrollView(this).apply { addView(content) }
        val dialog = AlertDialog.Builder(this)
            .setTitle("Touch Control Settings")
            .setView(scroll)
            .setNegativeButton("Done", null)
            .setOnDismissListener {
                touchSettingsDialog = null
                kartPadOverlay.clearTouchInput()
            }
            .create()
        moveControls.setOnClickListener {
            dialog.dismiss()
            beginLayoutEditing()
        }
        dialog.show()
        touchSettingsDialog = dialog
        if (debugSettingsFlow != null) {
            render.post {
                runCatching {
                    val render3 = (0 until render.childCount)
                        .map { render.getChildAt(it) as RadioButton }
                        .first { it.tag == 3f }
                    when (debugSettingsFlow) {
                        "seed" -> {
                            render3.performClick()
                            check(render3.isChecked) { "3x render did not become checked" }
                            fun setProgress(control: SeekBar, value: Float) {
                                val arguments = Bundle().apply {
                                    putFloat(
                                        AccessibilityNodeInfo.ACTION_ARGUMENT_PROGRESS_VALUE,
                                        value,
                                    )
                                }
                                check(control.performAccessibilityAction(
                                    AccessibilityNodeInfo.AccessibilityAction.ACTION_SET_PROGRESS.id,
                                    arguments,
                                )) { "${control.contentDescription} rejected accessibility progress" }
                            }
                            setProgress(opacity, 39f)
                            setProgress(size, 50f)
                            hide.performClick()
                            modernCStick.performClick()
                            check(!hide.isChecked && modernCStick.isChecked) {
                                "touch settings switches did not toggle"
                            }
                            val savedRender = KartPadTouchSettings.resolutionScale(this)
                            val savedOpacity = KartPadTouchSettings.opacity(this)
                            val savedSize = KartPadTouchSettings.size(this)
                            val savedHide = KartPadTouchSettings.hideOnController(this)
                            val savedModern = KartPadTouchSettings.modernCStickHorizontal(this)
                            check(savedRender == 3f && kotlin.math.abs(savedOpacity - 0.64f) < 0.001f &&
                                kotlin.math.abs(savedSize - 1.20f) < 0.001f && !savedHide && savedModern
                            ) {
                                "touch settings seeded render=$savedRender opacity=$savedOpacity " +
                                    "size=$savedSize hide=$savedHide modern=$savedModern"
                            }
                            check(nativeDebugDisplaySettings() ==
                                "fps=true aspect=0 scale=3.0"
                            ) { "3x render did not cross the source-fixture JNI bridge" }
                            Log.i(
                                TAG,
                                "A4 touch settings flow seeded render=3x opacity=64 size=120 " +
                                    "hide=false modern=true",
                            )
                        }
                        "verify" -> {
                            check(render3.isChecked && opacity.progress == 39 && size.progress == 50 &&
                                opacityLabel.text == "Opacity: 64%" &&
                                sizeLabel.text == "All sizes: 120%" &&
                                !hide.isChecked && modernCStick.isChecked
                            ) { "touch settings widgets did not reload persisted values" }
                            KartPadTouchSettings.resetTouchControls(this)
                            KartPadTouchSettings.setResolutionScale(this, 1f)
                            KartPadTouchSettings.setHideOnController(this, true)
                            KartPadTouchSettings.setModernCStickHorizontal(this, false)
                            Log.i(
                                TAG,
                                "A4 touch settings flow passed render=3x opacity=64 size=120 " +
                                    "hide=false modern=true",
                            )
                        }
                        else -> error("unknown touch settings flow $debugSettingsFlow")
                    }
                }.onFailure { Log.e(TAG, "A4 touch settings flow failed", it) }
            }
        } else if (debugEditorFlow) {
            moveControls.post {
                runCatching {
                    check(moveControls.performClick()) { "Move Controls did not accept click" }
                    val selected = kartPadOverlay.runDebugSelectAForEditorFixture()
                    check(editorLabel.text == "A size" && editorSize.isEnabled &&
                        editorVisibility.isEnabled && editorVisibility.text == "Hide"
                    ) { "editor did not expose selected A controls" }
                    check(editorVisibility.performClick()) { "Hide did not accept click" }
                    check(KartPadTouchSettings.isHidden(this, "A") &&
                        editorVisibility.text == "Show"
                    ) { "selected A did not enter hidden state" }
                    check(editorVisibility.performClick()) { "Show did not accept click" }
                    check(!KartPadTouchSettings.isHidden(this, "A") &&
                        editorVisibility.text == "Hide"
                    ) { "selected A did not return to shown state" }
                    val dragged = kartPadOverlay.runDebugDragSelectedAForEditorFixture()
                    kartPadOverlay.setSelectedControlSize(1.25f)
                    check(editorSize.progress == 65) { "selected A size did not refresh" }
                    check(editorBack.performClick()) { "Back did not accept click" }
                    check(editorBar.visibility == View.GONE && menuButton.visibility == View.VISIBLE &&
                        touchSettingsDialog?.isShowing == true
                    ) { "Back did not return to Touch Control Settings" }
                    check(resetTouchLayoutButton.performClick()) {
                        "Reset This Device Layout did not accept click"
                    }
                    val resetDialog = checkNotNull(resetTouchLayoutDialog) {
                        "reset confirmation did not open"
                    }
                    check(resetDialog.isShowing) { "reset confirmation is not showing" }
                    check(resetDialog.getButton(AlertDialog.BUTTON_POSITIVE).performClick()) {
                        "reset confirmation did not accept click"
                    }
                    resetTouchLayoutButton.post {
                        runCatching {
                            val resetOrigin = KartPadTouchSettings.origin(this, "A")
                            val resetSize = KartPadTouchSettings.controlSize(this, "A")
                            val resetHidden = KartPadTouchSettings.isHidden(this, "A")
                            check(resetOrigin == null &&
                                kotlin.math.abs(resetSize - 1f) < 0.001f && !resetHidden
                            ) {
                                "confirmed reset left origin=$resetOrigin size=$resetSize " +
                                    "hidden=$resetHidden"
                            }
                            Log.i(
                                TAG,
                                "A4 touch editor fixture passed $selected $dragged hide=shown " +
                                    "size=1.25 back=settings reset=defaults",
                            )
                        }.onFailure { Log.e(TAG, "A4 touch editor fixture failed", it) }
                    }
                }.onFailure { Log.e(TAG, "A4 touch editor fixture failed", it) }
            }
        }
    }

    private fun addLayoutEditorBar() {
        editorLabel = settingsLabel("Tap or drag a control")
        editorSize = SeekBar(this).apply {
            max = 115
            progress = 40
            isEnabled = false
            contentDescription = "Selected control size"
            setOnSeekBarChangeListener(simpleSeekListener {
                if (!updatingEditorControls) {
                    kartPadOverlay.setSelectedControlSize((progress + 60) / 100f)
                }
            })
        }
        editorVisibility = Button(this).apply {
            text = "Hide"
            isEnabled = false
            contentDescription = "Hide selected control"
            setOnClickListener { kartPadOverlay.toggleSelectedControlVisibility() }
        }
        editorBack = Button(this).apply {
            text = "Back"
            contentDescription = "Back to Touch Control Settings"
            setOnClickListener { finishLayoutEditing(returnToSettings = true) }
        }
        editorBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(10), dp(6), dp(10), dp(6))
            background = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(Color.argb(245, 14, 14, 14))
                setStroke(dp(2), Color.rgb(255, 199, 51))
            }
            visibility = View.GONE
            addView(editorBack, LinearLayout.LayoutParams(dp(100), dp(52)))
            addView(editorLabel, LinearLayout.LayoutParams(dp(250), dp(52)))
            addView(editorSize, LinearLayout.LayoutParams(dp(340), dp(52)))
            addView(editorVisibility, LinearLayout.LayoutParams(dp(110), dp(52)))
        }
        val params = RelativeLayout.LayoutParams(
            RelativeLayout.LayoutParams.WRAP_CONTENT,
            RelativeLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            addRule(RelativeLayout.ALIGN_PARENT_BOTTOM)
            addRule(RelativeLayout.CENTER_HORIZONTAL)
            setMargins(0, 0, 0, dp(12))
        }
        mLayout.addView(editorBar, params)
        kartPadOverlay.onEditSelectionChanged = { identifier, scale, hidden ->
            updatingEditorControls = true
            val selected = identifier != null
            editorLabel.text = identifier?.let { "$it size" } ?: "Tap or drag a control"
            editorSize.isEnabled = selected
            editorSize.progress = (scale * 100f).roundToInt() - 60
            editorVisibility.isEnabled = selected
            editorVisibility.text = if (hidden) "Show" else "Hide"
            editorVisibility.contentDescription = if (hidden) {
                "Show selected control"
            } else {
                "Hide selected control"
            }
            updatingEditorControls = false
        }
    }

    private fun beginLayoutEditing() {
        menuButton.visibility = View.GONE
        editorBar.visibility = View.VISIBLE
        mLayout.bringChildToFront(kartPadOverlay)
        mLayout.bringChildToFront(editorBar)
        kartPadOverlay.beginLayoutEditing()
    }

    private fun finishLayoutEditing(returnToSettings: Boolean) {
        kartPadOverlay.endLayoutEditing()
        editorBar.visibility = View.GONE
        menuButton.visibility = View.VISIBLE
        mLayout.bringChildToFront(menuButton)
        refreshControllerHandoff()
        if (returnToSettings) showTouchControlSettings()
    }

    private fun settingsLabel(value: String) = TextView(this).apply {
        text = value
        textSize = 16f
        setTextColor(Color.WHITE)
        setPadding(0, dp(10), 0, 0)
    }

    private fun simpleSeekListener(onChanged: () -> Unit) =
        object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                if (fromUser) onChanged()
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
            override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
        }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).roundToInt()

    private fun sp(value: Float): Float = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_SP,
        value,
        resources.displayMetrics,
    )

    private fun isGameController(device: InputDevice): Boolean {
        val sources = device.sources
        return sources and InputDevice.SOURCE_GAMEPAD == InputDevice.SOURCE_GAMEPAD ||
            sources and InputDevice.SOURCE_JOYSTICK == InputDevice.SOURCE_JOYSTICK
    }

    private fun configureRuntimeProfile() {
        val debugRequested = if (BuildConfig.DEBUG) {
            intent.getStringExtra(DEBUG_EXTRA_RUNTIME_PROFILE)
        } else {
            null
        }
        val requested = debugRequested ?: intent.getStringExtra(EXTRA_RUNTIME_PROFILE) ?: "base"
        runtimeProfile = requested

        when (requested) {
            "base" -> {
                Os.setenv("KARTPAD_RUNTIME_PROFILE", requested, true)
                Log.i(TAG, "A3 runtime profile requested=base")
            }
            "retro_rewind" -> {
                val installed = RetroRewindInstallValidator.validate(
                    RetroRewindInstallStorage.installedRoot(filesDir)
                        .resolve(RetroRewindRelease.ROOT),
                    RetroRewindInstallValidator.productionContract(),
                )
                check(installed.isValid) {
                    "Retro Rewind launch requires a validated installed pack"
                }
                Os.setenv("KARTPAD_RUNTIME_PROFILE", requested, true)
                Log.i(TAG, "A3 runtime profile requested=retro_rewind installed=valid")
            }
            else -> error("Unsupported runtime profile")
        }
    }

    private fun configureDebugLocalWfcRoute() {
        Os.unsetenv("KARTPAD_WFC_TEST_HOST")
        Os.unsetenv("KARTPAD_WFC_TEST_HTTP_PORT")
        if (!BuildConfig.DEBUG ||
            !intent.getBooleanExtra(DEBUG_EXTRA_LOCAL_WFC_ROUTE, false)
        ) {
            return
        }

        check(runtimeProfile == "retro_rewind") {
            "Local WFC routing requires the Retro Rewind profile"
        }
        check(Build.HARDWARE == "ranchu" || Build.HARDWARE == "goldfish") {
            "Local WFC routing is restricted to an Android emulator"
        }
        Os.setenv("KARTPAD_WFC_TEST_HOST", "10.0.2.2", true)
        Os.setenv("KARTPAD_WFC_TEST_HTTP_PORT", "29980", true)
        Log.i(
            TAG,
            "A5 local WFC route host=10.0.2.2 http_port=29980 profile=retro_rewind",
        )
    }

    private fun configureDebugRkgInput() {
        if (!BuildConfig.DEBUG) return

        val fixture = File(filesDir, DEBUG_RKG_RELATIVE_PATH)
        val header = ByteArray(RKG_MAGIC.size)
        val valid = fixture.isFile &&
            fixture.length() in MIN_RKG_BYTES..MAX_RKG_BYTES &&
            runCatching {
                fixture.inputStream().use { input ->
                    input.read(header) == header.size && header.contentEquals(RKG_MAGIC)
                }
            }.getOrDefault(false)

        if (valid) {
            val keyboardSteer = File(filesDir, DEBUG_RKG_KEYBOARD_STEER_RELATIVE_PATH).isFile
            Os.setenv("KARTPAD_RKG_INPUT_V2", fixture.absolutePath, true)
            Os.setenv("KARTPAD_RKG_AUTOSTART_V2", "1", true)
            Os.setenv("KARTPAD_RKG_FORCE_METADATA_V2", "1", true)
            Os.setenv("KARTPAD_PRECISE_MENU_PULSE_V2", "1", true)
            if (keyboardSteer) {
                Os.setenv("KARTPAD_RKG_KEYBOARD_STEER_V2", "1", true)
                Os.setenv("KARTPAD_FULL_SYNTHETIC_STICK_V2", "1", true)
            } else {
                Os.unsetenv("KARTPAD_RKG_KEYBOARD_STEER_V2")
                Os.unsetenv("KARTPAD_FULL_SYNTHETIC_STICK_V2")
            }
            Log.i(TAG, "Debug app-private RKG input enabled; keyboard steer=$keyboardSteer")
        } else {
            Os.unsetenv("KARTPAD_RKG_INPUT_V2")
            Os.unsetenv("KARTPAD_RKG_AUTOSTART_V2")
            Os.unsetenv("KARTPAD_RKG_FORCE_METADATA_V2")
            Os.unsetenv("KARTPAD_PRECISE_MENU_PULSE_V2")
            Os.unsetenv("KARTPAD_RKG_KEYBOARD_STEER_V2")
            Os.unsetenv("KARTPAD_FULL_SYNTHETIC_STICK_V2")
        }
    }

    private fun configureDebugStateTrace() {
        if (!BuildConfig.DEBUG) return

        val marker = File(filesDir, DEBUG_STATE_TRACE_MARKER_RELATIVE_PATH)
        if (marker.isFile) {
            val output = File(filesDir, DEBUG_STATE_TRACE_RELATIVE_PATH)
            output.parentFile?.mkdirs()
            Os.setenv("KARTPAD_STATE_TRACE", output.absolutePath, true)
            Log.i(TAG, "Debug app-private state trace enabled")
        } else {
            Os.unsetenv("KARTPAD_STATE_TRACE")
        }
    }

    private fun runDebugRetroRewindExtractionFixture() {
        if (!BuildConfig.DEBUG || BuildConfig.GAME_RUNTIME ||
            !intent.getBooleanExtra(DEBUG_EXTRA_RETRO_REWIND_EXTRACTION, false)
        ) {
            return
        }
        val temporary = File(cacheDir, "RetroRewindExtractionFixture-${System.nanoTime()}")
        try {
            val staging = File(temporary, "stage")
            check(staging.mkdirs())
            val archive = File(temporary, "fixture.zip")
            ZipOutputStream(FileOutputStream(archive)).use { zip ->
                zip.putNextEntry(ZipEntry("${RetroRewindRelease.ROOT}/"))
                zip.closeEntry()
                zip.putNextEntry(ZipEntry("${RetroRewindRelease.ROOT}/version.txt"))
                zip.write("${RetroRewindRelease.VERSION}\n".toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }
            val result = RetroRewindArchiveExtractor.extract(
                archive.toPath(),
                staging.toPath(),
                { false },
                { _, _ -> },
            )
            val extracted = File(staging, "${RetroRewindRelease.ROOT}/version.txt")
                .readText(Charsets.UTF_8)
            check(result.isComplete() && result.selectedEntries == 2L &&
                result.selectedBytes == extracted.toByteArray(Charsets.UTF_8).size.toLong() &&
                result.extractedBytes == result.selectedBytes &&
                extracted == "${RetroRewindRelease.VERSION}\n")
            Log.i(TAG, "A3 JNI archive extraction passed entries=2 bytes=${result.extractedBytes}")
        } catch (error: Exception) {
            Log.e(TAG, "A3 JNI archive extraction failed", error)
        } finally {
            temporary.deleteRecursively()
        }
    }

    private fun runDebugRetroRewindWorkerFixture() {
        if (!BuildConfig.DEBUG || BuildConfig.GAME_RUNTIME) {
            return
        }
        when {
            intent.getBooleanExtra(DEBUG_EXTRA_RETRO_REWIND_WORKER, false) -> {
                runDebugRetroRewindResumeFixture()
                RetroRewindInstallWork.enqueueDebugFixture(this)
                RetroRewindInstallWork.enqueueDebugFixture(this)
                Log.i(TAG, "A3 durable worker fixture enqueued twice with KEEP")
            }
        }
    }

    private fun runDebugRetroRewindResumeFixture() {
        val content = "resume-fixture-content".toByteArray(Charsets.UTF_8)
        val resumeOffset = 7
        val partial = Files.createTempFile(cacheDir.toPath(), "resume-fixture-", ".part")
        try {
            Files.write(partial, content.copyOf(resumeOffset))
            val result = RetroRewindArchiveDownload.transferResuming(
                ByteArrayInputStream(content, resumeOffset, content.size - resumeOffset),
                partial,
                content.size.toLong(),
                DEBUG_RESUME_FIXTURE_SHA256,
                resumeOffset.toLong(),
                { false },
                { _, _ -> },
            )
            check(result == RetroRewindArchiveDownload.Error.NONE)
            check(Files.readAllBytes(partial).contentEquals(content))
            Log.i(
                TAG,
                "A3 resumable transfer passed prefix=$resumeOffset total=${content.size}",
            )
        } catch (error: Exception) {
            Log.e(TAG, "A3 resumable transfer failed", error)
        } finally {
            Files.deleteIfExists(partial)
        }
    }

    private external fun nativeApplyDisplaySettings(
        showFps: Boolean, aspectMode: Int, resolutionScale: Float,
    )

    private external fun nativeEnableActivityRecreation()

    private external fun nativeDebugDisplaySettings(): String

    private external fun nativeApplyControllerMapping(mapping: IntArray)
    private external fun nativeControllerDevices(): Array<String>
    private external fun nativeAssignControllerPlayer(instance: Long, player: Int): Boolean
    private external fun nativeClearControllerPlayer(player: Int): Boolean

    private external fun nativeListMiis(database: ByteArray): Array<String>
    private external fun nativeImportMii(database: ByteArray, mii: ByteArray): ByteArray
    private external fun nativeRemoveMii(database: ByteArray, slot: Int): ByteArray

    companion object {
        private const val SELECTOR_RESTART_DELAY_MS = 250L
        private const val REQUEST_IMPORT_MII = 4_301
        private const val REQUEST_MANAGE_GAME_DATA = 4_302
        private const val REQUEST_EXPORT_SAVE = 4_303
        private const val REQUEST_IMPORT_SAVE = 4_304
        private const val MII_FILE_BYTES = 74
        const val EXTRA_RUNTIME_PROFILE = "dev.kartpad.android.RUNTIME_PROFILE"
        private const val TAG = "KartPadFixture"
        private const val DEBUG_RKG_RELATIVE_PATH = "KartPad/Diagnostics/TestInput.rkg"
        private const val DEBUG_RKG_KEYBOARD_STEER_RELATIVE_PATH =
            "KartPad/Diagnostics/TestInput.keyboard-steer"
        private const val DEBUG_STATE_TRACE_MARKER_RELATIVE_PATH =
            "KartPad/Diagnostics/StateTrace.enable"
        private const val DEBUG_STATE_TRACE_RELATIVE_PATH =
            "KartPad/Diagnostics/StateTrace.csv"
        private const val DEBUG_EXTRA_RETRO_REWIND_EXTRACTION =
            "dev.kartpad.android.TEST_RETRO_REWIND_EXTRACTION"
        private const val DEBUG_EXTRA_RETRO_REWIND_WORKER =
            "dev.kartpad.android.TEST_RETRO_REWIND_WORKER"
        private const val DEBUG_EXTRA_RUNTIME_PROFILE =
            "dev.kartpad.android.TEST_RUNTIME_PROFILE"
        private const val DEBUG_EXTRA_LOCAL_WFC_ROUTE =
            "dev.kartpad.android.TEST_LOCAL_WFC_ROUTE"
        private const val DEBUG_EXTRA_TOUCH_OVERLAY =
            "dev.kartpad.android.TEST_TOUCH_OVERLAY"
        private const val DEBUG_EXTRA_MULTI_POINTER =
            "dev.kartpad.android.TEST_TOUCH_MULTI_POINTER"
        private const val DEBUG_EXTRA_HIT_MAP =
            "dev.kartpad.android.TEST_TOUCH_HIT_MAP"
        private const val DEBUG_EXTRA_ACCESSIBILITY_ACTIONS =
            "dev.kartpad.android.TEST_TOUCH_ACCESSIBILITY_ACTIONS"
        private const val DEBUG_EXTRA_MOTION_SENSOR =
            "dev.kartpad.android.TEST_MOTION_SENSOR"
        private const val DEBUG_EXTRA_CONTROLLER_SETUP =
            "dev.kartpad.android.TEST_CONTROLLER_SETUP"
        private const val DEBUG_EXTRA_MENU = "dev.kartpad.android.TEST_MENU"
        private const val DEBUG_EXTRA_MODAL_CLEAR =
            "dev.kartpad.android.TEST_TOUCH_MODAL_CLEAR"
        private const val DEBUG_EXTRA_LIFECYCLE_CLEAR =
            "dev.kartpad.android.TEST_TOUCH_LIFECYCLE_CLEAR"
        private const val DEBUG_EXTRA_ACTIVITY_RECREATE =
            "dev.kartpad.android.TEST_TOUCH_ACTIVITY_RECREATE"
        private const val DEBUG_STATE_ACTIVITY_RECREATE =
            "dev.kartpad.android.STATE_TOUCH_ACTIVITY_RECREATE"
        private const val DEBUG_EXTRA_TOUCH_PERSISTENCE =
            "dev.kartpad.android.TEST_TOUCH_PERSISTENCE"
        private const val DEBUG_EXTRA_TOUCH_SETTINGS =
            "dev.kartpad.android.TEST_TOUCH_SETTINGS"
        private const val DEBUG_EXTRA_TOUCH_SETTINGS_FLOW =
            "dev.kartpad.android.TEST_TOUCH_SETTINGS_FLOW"
        private const val DEBUG_EXTRA_TOUCH_EDITOR =
            "dev.kartpad.android.TEST_TOUCH_EDITOR_FLOW"
        private const val DEBUG_EXTRA_GAS_LOCK =
            "dev.kartpad.android.TEST_TOUCH_GAS_LOCK"
        private const val DEBUG_RESUME_FIXTURE_SHA256 =
            "cb9d5fc3b83611af65032f73119285de4e97d4b2b9f7b2e9567443635358483a"
        private const val MIN_RKG_BYTES = 0x90L
        private const val MAX_RKG_BYTES = 1024L * 1024L
        private val RKG_MAGIC = byteArrayOf('R'.code.toByte(), 'K'.code.toByte(), 'G'.code.toByte(), 'D'.code.toByte())
    }

    private data class MiiRecord(val slot: Int, val name: String, val creator: String)
    private data class NativeController(val instance: Long, val player: Int, val name: String)
    private data class MenuRow(
        val title: String,
        val icon: Int,
        val checked: Boolean = false,
        val submenu: Boolean = false,
        val action: () -> Unit,
    )
}
