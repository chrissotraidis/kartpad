from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


class AndroidTouchOverlayContractTests(unittest.TestCase):
    def test_overlay_exposes_complete_classic_control_set(self) -> None:
        source = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        for control in (
            '"move"', '"c"', '"A"', '"B"', '"X"', '"Y"', '"Z"',
            '"Start"', '"L"', '"R"', '"DpadUp"', '"DpadDown"',
            '"DpadLeft"', '"DpadRight"',
        ):
            self.assertIn(control, source)
        self.assertIn("pointerOwners", source)
        self.assertIn("nativePublishTouchState", source)

    def test_lifecycle_clears_touch_state(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        self.assertIn("override fun onPause()", activity)
        self.assertIn("override fun onWindowFocusChanged(hasFocus: Boolean)", activity)
        self.assertGreaterEqual(activity.count("kartPadOverlay.clearTouchInput()"), 2)

    def test_one_second_gas_lock_has_visual_haptic_and_accessibility_state(self) -> None:
        source = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        self.assertIn("GAS_LOCK_DELAY_MS = 1_000L", source)
        self.assertIn("gasLocked = true", source)
        self.assertIn("LOCKED_GAS_COLOR", source)
        self.assertIn("HapticFeedbackConstants.VIRTUAL_KEY", source)
        self.assertIn("isHapticFeedbackEnabled = true", source)
        self.assertIn('"Acceleration locked"', source)
        self.assertIn("if (gasLocked) BUTTON_A else 0", source)
        self.assertIn("gasLocked = false", source)

    def test_gas_lock_runtime_fixture_covers_timing_haptic_release_and_unlock(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        overlay = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        runner = (REPO / "scripts/test-android-touch-gas-lock.sh").read_text()
        self.assertIn("TEST_TOUCH_GAS_LOCK", activity)
        self.assertIn("runDebugGasLockFixture", activity)
        self.assertIn("900L", overlay)
        self.assertIn("200L", overlay)
        self.assertIn("buttonFillColor(a) == LOCKED_GAS_COLOR", overlay)
        self.assertIn('stateDescription == "Acceleration locked"', overlay)
        self.assertIn("debugVirtualKeyHapticCount == 1", overlay)
        self.assertIn("release=locked tap=neutral", overlay)
        self.assertIn("A4 gas lock fixture passed", runner)

    def test_canvas_controls_are_accessible_and_operable_as_virtual_nodes(self) -> None:
        source = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        self.assertIn("TouchAccessibilityNodeProvider", source)
        self.assertIn("override fun getAccessibilityNodeProvider()", source)
        self.assertIn("visibleAccessibilityControls()", source)
        self.assertIn("info.addChild(this, id)", source)
        self.assertIn('"Move stick"', source)
        self.assertIn('"Camera stick"', source)
        self.assertIn('"D-pad up"', source)
        self.assertIn("pulseAccessibilityButton(control)", source)
        self.assertIn("pulseAccessibilityStick(control, action)", source)
        self.assertIn('"Lock acceleration"', source)
        self.assertIn('"Unlock acceleration"', source)
        self.assertIn("ACTION_TOGGLE_GAS_LOCK", source)
        self.assertIn("TYPE_VIEW_ACCESSIBILITY_FOCUSED", source)

    def test_accessibility_actions_have_repeatable_emulator_coverage(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        overlay = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        runner = (REPO / "scripts/test-android-touch-accessibility-actions.sh").read_text()
        self.assertIn("DEBUG_EXTRA_ACCESSIBILITY_ACTIONS", activity)
        self.assertIn("runDebugAccessibilityActionsFixture", activity)
        self.assertIn("virtualNodeProvider.performAction", overlay)
        self.assertIn("ACTION_STICK_RIGHT", overlay)
        self.assertIn('lockedNode.stateDescription == "Acceleration locked"', overlay)
        self.assertIn('unlockedNode.stateDescription == "Unlocked"', overlay)
        self.assertIn("TEST_TOUCH_ACCESSIBILITY_ACTIONS", runner)
        self.assertIn("focus=A b=pulse move=right lock=on click=unlock", runner)

    def test_r_is_the_same_compact_digital_pill_as_l(self) -> None:
        source = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        self.assertIn('button("L", "L", BUTTON_L, 94f, 46f', source)
        self.assertIn('button("R", "R", BUTTON_R, 94f, 46f', source)
        self.assertIn("const val BUTTON_R = 0x00000200", source)

    def test_controller_handoff_clears_hides_and_restores_touch(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        overlay = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        self.assertIn("InputManager.InputDeviceListener", activity)
        self.assertIn("InputDevice.SOURCE_GAMEPAD", activity)
        self.assertIn("InputDevice.SOURCE_JOYSTICK", activity)
        self.assertIn("registerInputDeviceListener", activity)
        self.assertIn("unregisterInputDeviceListener", activity)
        self.assertIn("kartPadOverlay.setHiddenForController(", activity)
        self.assertIn("controllerCount > 0 && KartPadTouchSettings.hideOnController(this)", activity)
        self.assertIn("fun setHiddenForController(hidden: Boolean)", overlay)
        self.assertIn("clearTouchInput()", overlay)
        self.assertIn("visibility = INVISIBLE", overlay)
        self.assertIn("visibility = VISIBLE", overlay)

    def test_source_fixture_replays_four_independent_touch_pointers(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        overlay = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        self.assertIn("DEBUG_EXTRA_MULTI_POINTER", activity)
        self.assertIn("runDebugMultiPointerFixture()", activity)
        self.assertIn("MotionEvent.ACTION_POINTER_DOWN", overlay)
        self.assertIn("MotionEvent.ACTION_POINTER_UP", overlay)
        self.assertIn("listOf(0 to steer, 1 to a, 2 to r, 3 to z)", overlay)
        self.assertIn("BUTTON_A or BUTTON_R or BUTTON_ZR", overlay)
        self.assertIn("abs(leftX - 0.75f) < 0.01f", overlay)
        self.assertIn("afterA=0x", overlay)
        self.assertIn("afterZ=0x", overlay)
        self.assertIn("actual == expected && leftX == 0f && leftY == 0f && pointerOwners.isEmpty()", overlay)

    def test_source_fixture_verifies_control_hit_map_and_pass_through(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        overlay = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        runner = (REPO / "scripts/test-android-touch-hit-map.sh").read_text()
        self.assertIn("DEBUG_EXTRA_HIT_MAP", activity)
        self.assertIn("runDebugHitMapFixture()", activity)
        self.assertIn("hitTest(control.frame.centerX(), control.frame.centerY())", overlay)
        self.assertIn("control.frame.left + 1f", overlay)
        self.assertIn("check(!consumed && pointerOwners.isEmpty()", overlay)
        self.assertIn("TEST_TOUCH_HIT_MAP", runner)
        self.assertIn("centers=14 edges=14 outside=passed", runner)

    def test_source_fixture_clears_a_real_held_touch_when_menu_opens(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        overlay = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        runner = (REPO / "scripts/test-android-touch-modal-clear.sh").read_text()
        self.assertIn("DEBUG_EXTRA_MODAL_CLEAR", activity)
        self.assertIn("runDebugHoldAForModalFixture()", activity)
        self.assertIn("showKartPadMenu()", activity)
        self.assertIn("debugTouchStateIsNeutral()", activity)
        self.assertIn("MotionEvent.ACTION_DOWN", overlay)
        self.assertIn("lastPublishedButtons == BUTTON_A", overlay)
        self.assertIn("pointerOwners.values.singleOrNull() == \"A\"", overlay)
        self.assertIn("TEST_TOUCH_MODAL_CLEAR", runner)
        self.assertIn("held=0x10 owners=1 neutral=0x0 owners=0", runner)

    def test_source_fixture_clears_a_real_held_touch_on_lifecycle_loss(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        runner = (REPO / "scripts/test-android-touch-lifecycle-clear.sh").read_text()
        self.assertIn("DEBUG_EXTRA_LIFECYCLE_CLEAR", activity)
        self.assertIn("debugLifecycleClearArmed = true", activity)
        self.assertIn('verifyDebugLifecycleClear("pause")', activity)
        self.assertIn('verifyDebugLifecycleClear("focus-loss")', activity)
        self.assertIn("debugTouchStateIsNeutral()", activity)
        self.assertIn("TEST_TOUCH_LIFECYCLE_CLEAR", runner)
        self.assertIn("input keyevent KEYCODE_HOME", runner)
        self.assertIn("neutral=0x0 owners=0", runner)

    def test_source_fixture_persists_position_size_and_visibility_across_processes(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        overlay = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        runner = (REPO / "scripts/test-android-touch-persistence.sh").read_text()
        self.assertIn("DEBUG_EXTRA_TOUCH_PERSISTENCE", activity)
        self.assertIn('KartPadTouchSettings.setOrigin(this, "A"', activity)
        self.assertIn('KartPadTouchSettings.setControlSize(this, "A", 1.25f)', activity)
        self.assertIn('KartPadTouchSettings.setHidden(this, "B", true)', activity)
        self.assertIn("runDebugPersistenceFixture()", activity)
        self.assertIn("visibleAccessibilityControls().any", overlay)
        self.assertIn('KartPadTouchSettings.isHidden(context, "B")', overlay)
        self.assertIn("am force-stop dev.kartpad.android", runner)
        self.assertIn("TEST_TOUCH_PERSISTENCE verify", runner)

    def test_touch_visual_contract_covers_phone_tablet_geometry_and_palette(self) -> None:
        verifier = (REPO / "scripts/check-android-touch-visual.py").read_text()
        runner = (REPO / "scripts/test-android-touch-visual.sh").read_text()
        self.assertIn('"Move stick"', verifier)
        self.assertIn('"Z button"', verifier)
        self.assertIn("max(z[0] - x[2], x[0] - z[2])", verifier)
        self.assertIn('44 if args.lane == "phone" else 16', verifier)
        self.assertIn("r_width != 560", verifier)
        self.assertIn('"A button": (18, 120, 71)', verifier)
        self.assertIn('"B button": (153, 32, 40)', verifier)
        self.assertIn('"Z button": (78, 47, 128)', verifier)
        self.assertIn("TEST_TOUCH_OVERLAY", runner)
        self.assertIn('phone) user_rotation=1', runner)
        self.assertIn('tablet) user_rotation=0', runner)

    def test_touch_settings_visual_contract_covers_every_ios_parity_control(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        verifier = (REPO / "scripts/check-android-touch-settings-visual.py").read_text()
        runner = (REPO / "scripts/test-android-touch-settings-visual.sh").read_text()
        self.assertIn("DEBUG_EXTRA_TOUCH_SETTINGS", activity)
        self.assertIn("showTouchControlSettings()", activity)
        for label in (
            '"Touch Control Settings"', '"1×"', '"4×"',
            '"Opacity: 82%"', '"All sizes: 100%"',
            '"Hide on controller"', '"Modern C-stick L/R"',
            '"MOVE CONTROLS"', '"RESET THIS DEVICE LAYOUT"', '"DONE"',
        ):
            self.assertIn(label, verifier)
        self.assertIn("columns=left-sliders/right-actions", verifier)
        self.assertIn("TEST_TOUCH_SETTINGS", runner)

    def test_touch_settings_widget_flow_persists_across_process_restart(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        runner = (REPO / "scripts/test-android-touch-settings-flow.sh").read_text()
        self.assertIn("TEST_TOUCH_SETTINGS_FLOW", activity)
        self.assertIn("render3.performClick()", activity)
        self.assertIn("AccessibilityAction.ACTION_SET_PROGRESS.id", activity)
        self.assertIn("setProgress(opacity, 39f)", activity)
        self.assertIn("setProgress(size, 50f)", activity)
        self.assertIn("hide.performClick()", activity)
        self.assertIn("modernCStick.performClick()", activity)
        self.assertIn('"verify" ->', activity)
        self.assertIn("shell am force-stop dev.kartpad.android", runner)
        self.assertIn("A4 touch settings flow passed", runner)

    def test_touch_editor_flow_exercises_hide_show_size_and_back(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        overlay = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        runner = (REPO / "scripts/test-android-touch-editor-flow.sh").read_text()
        self.assertIn("TEST_TOUCH_EDITOR_FLOW", activity)
        self.assertIn("runDebugSelectAForEditorFixture", activity)
        self.assertIn("runDebugDragSelectedAForEditorFixture", activity)
        self.assertIn('editorVisibility.text == "Show"', activity)
        self.assertIn('editorVisibility.text == "Hide"', activity)
        self.assertIn("editorBack.performClick()", activity)
        self.assertIn("touchSettingsDialog?.isShowing == true", activity)
        self.assertIn("resetTouchLayoutButton.performClick()", activity)
        self.assertIn("resetDialog.getButton(AlertDialog.BUTTON_POSITIVE).performClick()", activity)
        self.assertIn("MotionEvent.ACTION_DOWN", overlay)
        self.assertIn("MotionEvent.ACTION_MOVE", overlay)
        self.assertIn("MotionEvent.ACTION_UP", overlay)
        self.assertIn("A4 touch editor fixture passed", runner)

    def test_touch_presentation_settings_match_ios_ranges_and_defaults(self) -> None:
        settings = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadTouchSettings.kt").read_text()
        overlay = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        self.assertIn("DEFAULT_OPACITY = 0.82f", settings)
        self.assertIn("MIN_OPACITY = 0.25f", settings)
        self.assertIn("MAX_OPACITY = 1.0f", settings)
        self.assertIn("MIN_SIZE = 0.70f", settings)
        self.assertIn("MAX_SIZE = 1.35f", settings)
        self.assertIn("MIN_CONTROL_SIZE = 0.60f", settings)
        self.assertIn("MAX_CONTROL_SIZE = 1.75f", settings)
        self.assertIn("getBoolean(HIDE_ON_CONTROLLER, true)", settings)
        self.assertIn("modernCStickHorizontal", settings)
        self.assertIn("HIDDEN_CONTROLS", settings)
        self.assertIn("ORIGIN_X_PREFIX", settings)
        self.assertIn("controlSizeScale = KartPadTouchSettings.size(context)", overlay)
        self.assertIn("else -> controlOpacity", overlay)
        self.assertIn("alpha * 255f", overlay)
        self.assertIn('if (control.id.startsWith("Dpad")) "Dpad"', overlay)
        self.assertIn("fun setSelectedControlSize", overlay)
        self.assertIn("fun toggleSelectedControlVisibility", overlay)
        self.assertIn("if (modernCStickHorizontal) -rightX else rightX", overlay)
        self.assertIn('MenuRow("Touch Control Settings…", R.drawable.ic_kartpad_hand)', activity)
        self.assertIn('.setTitle("Touch Control Settings")', activity)
        self.assertIn('text = "Reset This Device Layout"', activity)
        self.assertIn('text = "Move controls"', activity)
        self.assertIn('text = "Modern C-stick L/R"', activity)
        self.assertIn('val renderScales = floatArrayOf(1f, 2f, 3f, 4f)', activity)
        self.assertIn('contentDescription = "Render resolution"', activity)
        self.assertIn("KartPadTouchSettings.setResolutionScale(this, scale)", activity)
        self.assertIn("val leftColumn = LinearLayout(this).apply", activity)
        self.assertIn("val rightColumn = LinearLayout(this).apply", activity)
        self.assertIn('text = "Back"', activity)
        self.assertIn("finishLayoutEditing(returnToSettings = true)", activity)
        self.assertIn("KartPadTouchSettings.hideOnController(this)", activity)
        reset_body = settings[settings.index("fun resetTouchControls"):]
        self.assertNotIn("key == HIDE_ON_CONTROLLER", reset_body)
        self.assertNotIn("key == MODERN_C_STICK", reset_body)

    def test_android_menu_preserves_kartpad_hierarchy_and_live_display_actions(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        native = (REPO / "android/app/src/main/cpp/kartpad_runtime_settings_jni.cpp").read_text()
        for title in (
            '"KartPad"', '"Switch Game Version…"', '"Multiplayer…"',
            '"Show FPS Counter"', '"Controls"', '"Display"',
            '"Game Data & Saves"', '"Controller Player Setup…"',
            '"Controller Button Mapping…"',
            '"Touch Control Settings…"', '"Motion Steering…"',
            '"Experimental Wii Remote + Nunchuk…"', '"Aspect Ratio…"',
            '"Render Resolution…"', '"Manage Retro Rewind…"', '"Manage Miis…"',
            '"Import or Reimport Wii Disc Image…"',
            '"Import from Extracted Folder…"', '"Remove Stored Game Data…"',
            '"Manage Saves…"',
            '"Report a Problem…"',
        ):
            self.assertIn(title, activity)
        self.assertNotIn("SunPad", activity)
        self.assertIn("nativeApplyDisplaySettings", activity)
        self.assertIn("restartToGameSelector", activity)
        self.assertIn("startActivity(chooser)", activity)
        self.assertIn("kotlin.system.exitProcess(0)", activity)
        manifest = (REPO / "android/app/src/main/AndroidManifest.xml").read_text()
        self.assertIn('android:process=":launcher"', manifest)
        self.assertIn('hint = "What went wrong?"', activity)
        self.assertIn('hint = "Area and what you were doing (optional)"', activity)
        self.assertIn('hint = "Every time, sometimes, once, or not sure?"', activity)
        self.assertIn('appendQueryParameter("report-id", id)', activity)
        self.assertIn('appendQueryParameter("summary", problem.text.toString().trim())', activity)
        self.assertIn("PopupWindow(card, dp(320)", activity)
        self.assertIn("showAtLocation(mLayout, Gravity.TOP or Gravity.END", activity)
        self.assertIn("getInsetsIgnoringVisibility", activity)
        self.assertIn("WindowInsets.Type.systemBars()", activity)
        self.assertIn("WindowInsets.Type.displayCutout()", activity)
        self.assertIn("menuSafeInsetTop + dp(8)", activity)
        self.assertIn("menuSafeInsetEnd + dp(12)", activity)
        self.assertIn("menuSafeInsetBottom - dp(16)", activity)
        self.assertIn("isOutsideTouchable = true", activity)
        self.assertIn("showControlsMenu()", activity)
        self.assertIn("showDisplayMenu()", activity)
        self.assertIn("showGameDataMenu()", activity)
        self.assertIn("rows.map(::kartPadMenuRowHeight)", activity)
        self.assertIn("TypedValue.COMPLEX_UNIT_SP", activity)
        self.assertIn("paint.measureText(row.title)", activity)
        self.assertIn("maxLines = 2", activity)
        self.assertIn("TextUtils.TruncateAt.END", activity)
        self.assertIn("R.drawable.ic_kartpad_gamecontroller", activity)
        self.assertIn("R.drawable.ic_kartpad_display", activity)
        self.assertIn("R.drawable.ic_kartpad_folder", activity)
        self.assertIn("R.drawable.ic_kartpad_report", activity)
        self.assertIn("DEBUG_EXTRA_MENU", activity)
        runtime_patch = (REPO / "patches/wiicompiled-android-runtime-settings.patch").read_text()
        self.assertIn("PublishDisplaySettings", native)
        self.assertNotIn("AuroraGetSurfaceSize", native)
        self.assertIn("ConsumeDisplaySettings", runtime_patch)
        self.assertIn("ConfigureMkwMobileAspectMode", runtime_patch)
        self.assertIn("VISetFrameBufferScale", runtime_patch)

    def test_display_choice_labels_match_ios_and_mark_experiments(self) -> None:
        android = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        settings = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadTouchSettings.kt").read_text()
        ios = (REPO / "apple/third_party/sunpad/SunPadGameOverlay.mm").read_text()
        for label in (
            "Original 4:3",
            "16:9 (Experimental)",
            "Fill Screen (Experimental)",
            "1× (Native)",
            "2×",
            "3×",
            "4×",
        ):
            self.assertIn(label, ios)
            self.assertIn(label, android)
        self.assertNotIn('arrayOf("4:3", "16:9", "Fill Screen")', android)
        self.assertNotIn('arrayOf("Native (1x)", "2x", "3x", "4x")', android)
        self.assertIn(".getInt(ASPECT_MODE, 0)", settings)
        self.assertNotIn(".getInt(ASPECT_MODE, 2)", settings)

    def test_android_exposes_persistent_one_to_four_player_controller_setup(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        native = (REPO / "android/app/src/main/cpp/kartpad_controller_slots_jni.cpp").read_text()
        fixture = (REPO / "android/app/src/main/cpp/kartpad_controller_slots_fixture_jni.cpp").read_text()
        patch = (REPO / "patches/aurora-android-gamepad-assignment.patch").read_text()
        prepare = (REPO / "scripts/prepare-android-game-runtime.sh").read_text()
        self.assertIn("for (player in 0 until 4)", activity)
        self.assertIn('"Player ${player + 1}', activity)
        self.assertIn("nativeControllerDevices()", activity)
        self.assertIn("nativeAssignControllerPlayer", activity)
        self.assertIn("nativeClearControllerPlayer", activity)
        self.assertIn("list_standard_gamepads", native)
        self.assertIn("assign_standard_gamepad", native)
        self.assertIn("clear_standard_gamepad_player", native)
        self.assertIn('"KartPad Virtual One"', fixture)
        self.assertIn("g_players[index] = -1", fixture)
        self.assertIn("DEBUG_EXTRA_CONTROLLER_SETUP", activity)
        self.assertIn(
            "g_portPreferences[player].identity = controller_identity(selected)", patch,
        )
        self.assertIn("assign_player_index(controller, -1)", patch)
        self.assertIn("aurora-android-gamepad-assignment.patch", prepare)

    def test_z_has_clear_spacing_from_x(self) -> None:
        source = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        self.assertIn('0.896f, 0.4258446f, Color.argb(235, 184, 184, 184)', source)
        self.assertIn('0.969f, 0.410f, Color.argb(240, 97, 46, 148)', source)

    def test_touch_overlay_preserves_ipad_default_geometry_on_tablets(self) -> None:
        source = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        self.assertIn("smallestScreenWidthDp >= 600", source)
        self.assertIn('"move" -> PointF(172f, 172f)', source)
        self.assertIn('"R" -> PointF(280f, 62f)', source)
        self.assertIn('"Start" -> PointF(116f, 62f)', source)
        self.assertIn('"move" -> PointF(0.13103953f, 0.79058945f)', source)
        self.assertIn('"Z" -> PointF(0.8275988f, 0.721303f)', source)
        self.assertIn('else -> PointF(0.26866764f, 0.79472595f)', source)
        self.assertIn("DEBUG_EXTRA_TOUCH_OVERLAY", activity)
        self.assertIn("BuildConfig.GAME_RUNTIME || debugTouchOverlay", activity)

    def test_selector_matches_ios_two_choice_import_flow(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadLaunchActivity.kt").read_text()
        verifier = (REPO / "scripts/check-android-selector-visual.py").read_text()
        self.assertIn('original.setOnClickListener { selectMode("base") }', activity)
        self.assertIn('retro.setOnClickListener { selectMode("retro_rewind") }', activity)
        self.assertIn("if (!gameDataReady)", activity)
        self.assertIn("pendingProfile = profile", activity)
        self.assertIn("startActivityForResult(", activity)
        self.assertIn("pendingProfile?.takeIf { gameDataReady }", activity)
        self.assertNotIn('text = "Manage Game Data…"', activity)
        self.assertNotIn('"Manage Game Data…",', verifier)
        self.assertIn("translationY = -dp(18).toFloat()", activity)
        self.assertIn("setPadding(dp(28), dp(24), dp(28), dp(24))", activity)
        self.assertIn("bottomMargin = dp(12)", activity)
        self.assertIn('17f,\n                Color.argb(158', activity)
        self.assertIn("private class ModeButton", activity)
        self.assertIn("gravity = Gravity.CENTER", activity)
        self.assertIn("setIcon(icon, dp(20), dp(12))", activity)
        self.assertIn("Button::class.java.name", activity)

    def test_consolidated_menu_has_real_emulator_hierarchy_gate(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        runner = (REPO / "scripts/test-android-menu-parity.sh").read_text()
        for label in (
            "Switch Game Version…",
            "Multiplayer…",
            "Show FPS Counter",
            "Controller Player Setup…",
            "Controller Button Mapping…",
            "Touch Control Settings…",
            "Motion Steering…",
            "Experimental Wii Remote + Nunchuk…",
            "Aspect Ratio…",
            "Render Resolution…",
            "Import or Reimport Wii Disc Image…",
            "Import from Extracted Folder…",
            "Remove Stored Game Data…",
            "Manage Retro Rewind…",
            "Manage Saves…",
            "Manage Miis…",
            "Report a Problem…",
        ):
            self.assertIn(f'"{label}"', activity)
            self.assertIn(f'"{label}"', runner)
        self.assertIn("TEST_MENU", runner)
        self.assertNotIn("shell pm clear dev.kartpad.android", runner)
        self.assertIn("expected_fps_value", runner)
        self.assertIn("top=8 controls=5 display=2 data=6 actions=16", runner)
        self.assertIn("assert_icon_count 7", runner)
        self.assertIn("assert_icon_count 5", runner)
        self.assertIn("assert_icon_count 2", runner)
        self.assertIn("assert_icon_count 6", runner)
        for icon in ("hand", "gyroscope", "antenna", "refresh", "trash", "mii"):
            self.assertIn(f"R.drawable.ic_kartpad_{icon}", activity)
        self.assertIn('open_top_action "Multiplayer…"', runner)
        self.assertIn('open_top_action "Report a Problem…"', runner)
        self.assertIn('open_submenu_action "Controls" "Touch Control Settings…"', runner)
        self.assertIn('open_submenu_action "Display" "Aspect Ratio…"', runner)
        self.assertIn('open_submenu_action "Game Data & Saves" "Manage Saves…"', runner)
        self.assertIn('open_submenu_action "Game Data & Saves" "Manage Miis…"', runner)
        self.assertIn('open_submenu_action "Game Data & Saves" "Import or Reimport Wii Disc Image…"', runner)
        self.assertIn('open_submenu_action "Game Data & Saves" "Import from Extracted Folder…"', runner)
        self.assertIn("topResumedActivity=.*com.google.android.documentsui", runner)
        self.assertIn('tap_label "Show FPS Counter"', runner)
        self.assertIn('name="show_fps" value="false"', runner)

    def test_motion_steering_matches_ios_curve_and_merges_with_touch(self) -> None:
        motion = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadMotionSteering.kt").read_text()
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        overlay = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadOverlayView.kt").read_text()
        settings = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadTouchSettings.kt").read_text()
        self.assertIn("Sensor.TYPE_GRAVITY", motion)
        self.assertIn("Sensor.TYPE_ACCELEROMETER", motion)
        self.assertIn("private const val DEAD_ZONE = 0.045", motion)
        self.assertIn("val fullLock = 0.70 / boundedSensitivity", motion)
        self.assertIn("sensitivity.coerceIn(0.5f, 2f)", motion)
        self.assertIn("fun recenter()", motion)
        self.assertIn("showMotionSteering()", activity)
        self.assertIn('"Turn On & Recenter"', activity)
        self.assertIn('"Cycle Sensitivity"', activity)
        self.assertIn("motion_steering_enabled", settings)
        self.assertIn("fun setMotionSteering(value: Float)", overlay)
        self.assertIn("abs(leftX) >= abs(motionSteeringX)", overlay)
        self.assertIn("setControllerConnected(controllerCount > 0)", activity)

    def test_motion_steering_has_real_emulator_sensor_flow(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        runner = (REPO / "scripts/test-android-motion-sensor.sh").read_text()
        self.assertIn("DEBUG_EXTRA_MOTION_SENSOR", activity)
        self.assertIn("A4 motion sensor sample", activity)
        self.assertIn("KartPadTouchSettings.setMotionInverted", activity)
        self.assertIn("emu sensor set acceleration", runner)
        self.assertIn("run_mode standard positive", runner)
        self.assertIn("run_mode inverted negative", runner)
        self.assertIn("started registered=true", runner)

    def test_controller_mapping_is_persisted_swapped_and_applied_natively(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        store = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadControllerMapping.kt").read_text()
        native = (REPO / "runtime/include/kartpad/android/controller_mapping.hpp").read_text()
        patch = (REPO / "patches/wiicompiled-android-controller-mapping.patch").read_text()
        self.assertIn('arrayOf("A", "B", "X", "Y", "Z")', store)
        self.assertIn('"Left Shoulder"', store)
        self.assertIn("mapping.indexOf(physical)", store)
        self.assertIn("mapping[other] = previous", store)
        self.assertIn("showControllerMappingChoices(game)", activity)
        self.assertIn('text = "Reset to Default"', activity)
        self.assertIn("nativeApplyControllerMapping", activity)
        self.assertIn("IsValidControllerButtonMapping", native)
        self.assertIn("ApplyControllerButtonMapping", patch)
        gamepad = (REPO / "runtime/include/kartpad/android/gamepad_contract.h").read_text()
        fixture = (REPO / "android/app/src/main/cpp/fixture_main.cpp").read_text()
        self.assertIn("map(kGamepadLeftShoulder, kClassicZr)", gamepad)
        self.assertIn("output.buttons |= kClassicL", gamepad)
        expected = fixture.split("constexpr uint32_t kExpectedButtons =", 1)[1].split(";", 1)[0]
        self.assertIn("kClassicZr", expected)
        self.assertNotIn("kClassicZl", expected)

    def test_mii_manager_stages_validated_changes_for_restart(self) -> None:
        activity = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt").read_text()
        storage = (REPO / "android/app/src/main/java/dev/kartpad/android/KartPadMiiStorage.kt").read_text()
        native = (REPO / "android/app/src/main/cpp/kartpad_mii_jni.cpp").read_text()
        cmake = (REPO / "android/app/src/main/cpp/CMakeLists.txt").read_text()
        self.assertIn("KartPadMiiStorage.applyPending(filesDir)", activity)
        self.assertLess(
            activity.index("KartPadMiiStorage.applyPending(filesDir)"),
            activity.index("super.onCreate(savedInstanceState)"),
        )
        self.assertIn("showMiiManager()", activity)
        self.assertIn("Intent.ACTION_OPEN_DOCUMENT", activity)
        self.assertIn("nativeImportMii", activity)
        self.assertIn("nativeRemoveMii", activity)
        self.assertIn("AtomicFile", storage)
        self.assertIn("MiiBackups", storage)
        self.assertIn("stored == crc", storage)
        self.assertIn("kartpad::mii::ImportMii", native)
        self.assertIn("kartpad::mii::RemoveMii", native)
        self.assertIn("kartpad_mii_jni.cpp", cmake)

    def test_runtime_preparation_applies_touch_bridge(self) -> None:
        script = (REPO / "scripts/prepare-android-game-runtime.sh").read_text()
        self.assertIn("wiicompiled-android-touch-input.patch", script)

    def test_touch_c_stick_reaches_both_guest_status_formats(self) -> None:
        patch = (REPO / "patches/wiicompiled-android-touch-input.patch").read_text()
        self.assertIn("statusPtr + 0x74, touchInput.right_stick_x", patch)
        self.assertIn("statusPtr + 0x78, touchInput.right_stick_y", patch)
        self.assertIn("statusPtr + 0x30, static_cast<uint16_t>(rightStickX)", patch)
        self.assertIn("statusPtr + 0x32, static_cast<uint16_t>(rightStickY)", patch)
        patch = (REPO / "patches/wiicompiled-android-touch-input.patch").read_text()
        self.assertIn('"kartpad/android/touch_input.h"', patch)
        self.assertIn("ConsumeTouchInput()", patch)
        self.assertIn("CoreButtonsForClassic(touchInput.buttons)", patch)

    def test_game_build_selects_dual_preparation_for_a_dual_graph(self) -> None:
        script = (REPO / "scripts/build-android-game-app.sh").read_text()
        self.assertIn('runtime_product="base"', script)
        self.assertIn('runtime_product="dual"', script)
        self.assertIn('"$runtime_build" "$runtime_product"', script)
        self.assertIn('native_target="KartPadDual"', script)


if __name__ == "__main__":
    unittest.main()
