package dev.kartpad.android

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Switch
import android.graphics.drawable.RippleDrawable
import java.util.concurrent.Executors

/** Production owner for choosing the immutable runtime profile before SDL starts. */
open class KartPadLaunchActivity : Activity() {
    protected open fun pausedProfile(): String? = null
    private fun requestedProfileFile() = java.io.File(filesDir, "KartPad/RequestedRuntimeProfile")
    private lateinit var status: TextView
    private lateinit var original: ModeButton
    private lateinit var retro: ModeButton
    private lateinit var progress: ProgressBar
    private val validator = Executors.newSingleThreadExecutor()
    private var validationGeneration = 0
    private var retroInstalled = false
    private var gameDataReady = false
    private var pendingProfile: String? = null
    private var exportSession: String? = null
    private lateinit var preferredLaunch: KartPadPreferredLaunch
    private var darkMode = true
    private lateinit var preferenceButton: Button
    private val primaryTextColor get() = if (darkMode) Color.rgb(247, 247, 247) else Color.rgb(12, 17, 26)
    private val secondaryForeground get() = if (darkMode) Color.rgb(170, 170, 170) else Color.rgb(94, 94, 94)
    private val racingRed get() = if (darkMode) Color.rgb(255, 51, 66) else Color.rgb(204, 9, 31)

    private fun rebuildContent() {
        setContentView(buildContent())
        original.setOnClickListener { selectMode("base") }
        retro.setOnClickListener { selectMode("retro_rewind") }
    }

    private fun updatePreferenceLabel() {
        val value = KartPadPreferredGame.read(filesDir)
        val index = KartPadPreferredGame.values.indexOf(value).coerceAtLeast(0)
        preferenceButton.text = KartPadPreferredGame.labels[index] + "  ⌄"
        preferenceButton.contentDescription = "On launch: " + KartPadPreferredGame.labels[index]
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        darkMode = getSharedPreferences("kartpad_launcher", MODE_PRIVATE).getBoolean("dark_mode", true)
        setTheme(if (darkMode) android.R.style.Theme_Material_NoActionBar_Fullscreen else android.R.style.Theme_Material_Light_NoActionBar_Fullscreen)
        super.onCreate(savedInstanceState)
        exportSession = savedInstanceState?.getString("diagnostic_session")
        preferredLaunch = KartPadPreferredLaunch(
            savedInstanceState?.getBoolean(STATE_PREFERRED_CONSUMED) == true ||
                intent.getBooleanExtra(EXTRA_SKIP_PREFERRED_GAME, false) || pausedProfile() != null,
        )
        KartPadExitDiagnostics.mark(this, pausedProfile() ?: "chooser")
        rebuildContent()
    }

    override fun onResume() {
        super.onResume()
        pausedProfile()?.let { current ->
            progress.visibility = View.GONE
            original.isEnabled = true
            retro.isEnabled = true
            refreshModeCards()
            hideStatus("Current game paused")
            return
        }
        if (pendingProfile == null) {
            pendingProfile = runCatching { requestedProfileFile().readText() }.getOrNull()
                ?.takeIf { it == "base" || it == "retro_rewind" }
        }
        validateRetroRewind()
    }

    override fun onPause() {
        // Do not launch over another app or a setup/help screen after validation.
        preferredLaunch.consumed = true
        super.onPause()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString("diagnostic_session", exportSession)
        outState.putBoolean(STATE_PREFERRED_CONSUMED, preferredLaunch.consumed)
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        validationGeneration += 1
        validator.shutdownNow()
        super.onDestroy()
    }

    private fun validateRetroRewind() {
        val generation = ++validationGeneration
        val forceNotInstalled = BuildConfig.DEBUG &&
            intent.getBooleanExtra(EXTRA_DEBUG_RETRO_NOT_INSTALLED, false)
        val forceGameDataValid = BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME &&
            intent.getBooleanExtra(EXTRA_DEBUG_GAME_DATA_VALID, false)
        retroInstalled = false
        showStatus("Checking game data and Retro Rewind ${RetroRewindRelease.VERSION}…")
        progress.visibility = View.VISIBLE
        original.isEnabled = false
        retro.isEnabled = false
        validator.execute {
            val removalError = KartPadGameDataStorage.applyScheduledRemoval(filesDir)
            val gameDataError = when {
                forceGameDataValid -> null
                removalError != null -> removalError
                else -> KartPadGameDataStorage.validationError(filesDir) ?: runCatching {
                    KartPadGameDataStorage.ensureRuntimePath(filesDir)
                }.exceptionOrNull()?.let {
                    "Validated game data could not be configured for the runtime."
                }
            }
            val gameDataValid = gameDataError == null
            val valid = !forceNotInstalled && runCatching {
                RetroRewindInstallStorage.recover(filesDir)
                RetroRewindInstallValidator.validate(
                    RetroRewindInstallStorage.installedRoot(filesDir)
                        .resolve(RetroRewindRelease.ROOT),
                    RetroRewindInstallValidator.productionContract(),
                ).isValid.also { installed ->
                    if (installed) {
                        KartPadRuntimePathConfig.ensureRetroRewindRoot(filesDir)
                    }
                }
            }.getOrDefault(false)
            runOnUiThread {
                if (generation != validationGeneration || isFinishing || isDestroyed) {
                    return@runOnUiThread
                }
                retroInstalled = valid
                progress.visibility = View.GONE
                gameDataReady = gameDataValid
                original.isEnabled = true
                retro.isEnabled = true
                refreshModeCards()
                if (gameDataError != null) {
                    showStatus(gameDataError)
                } else if (!gameDataValid) {
                    hideStatus("Game data is required. Choose a mode to import it.")
                } else if (valid) {
                    hideStatus("Original and Retro Rewind ${RetroRewindRelease.VERSION} are ready")
                } else {
                    hideStatus("Original is ready; Retro Rewind is optional")
                }
                Log.i(LOG_TAG, "A3 mode chooser retro-installed=$valid")
                val automaticProfile = preferredLaunch.choose(
                    KartPadPreferredGame.read(filesDir), gameDataReady, retroInstalled, pendingProfile,
                )
                pendingProfile?.takeIf { gameDataReady }?.let { profile ->
                    pendingProfile = null
                    continueSelectedMode(profile)
                } ?: automaticProfile?.let { launch(it) }
            }
        }
    }

    private fun selectMode(profile: String) {
        preferredLaunch.consumed = true
        pausedProfile()?.let { current ->
            if (profile == current) {
                finish()
            } else {
                AlertDialog.Builder(this)
                    .setTitle("Switch on Next Launch")
                    .setMessage("Fully close KartPad from Recents and reopen it to switch games. Saved progress and controls are kept; unsaved race progress is not carried over. Resume does not apply pending changes.")
                    .setNegativeButton("Cancel", null)
                    .setPositiveButton("Use on Next Launch") { _, _ ->
                        val file = android.util.AtomicFile(requestedProfileFile())
                        requestedProfileFile().parentFile?.mkdirs()
                        runCatching {
                            val output = file.startWrite()
                            try { output.write(profile.toByteArray()); file.finishWrite(output) }
                            catch (error: Throwable) { file.failWrite(output); throw error }
                        }.onFailure { showStatus("The next-launch choice could not be saved.") }
                    }.show()
            }
            return
        }
        if (!gameDataReady) {
            pendingProfile = profile
            startActivityForResult(
                Intent(this, KartPadGameDataActivity::class.java),
                REQUEST_GAME_DATA,
            )
            return
        }
        continueSelectedMode(profile)
    }

    private fun continueSelectedMode(profile: String) {
        if (profile == "retro_rewind" && !retroInstalled) {
            startActivity(Intent(this, RetroRewindInstallActivity::class.java))
        } else {
            launch(profile)
        }
    }

    private fun launch(profile: String) {
        requestedProfileFile().delete()
        Log.i(LOG_TAG, "A3 mode chooser selected=$profile")
        startActivity(
            Intent(this, KartPadActivity::class.java)
                .putExtra(KartPadActivity.EXTRA_RUNTIME_PROFILE, profile),
        )
        // The translated runtime is process-global and is not restartable in
        // place. Do not leave the chooser behind the SDL activity where Back
        // could imply that another profile can be selected in this process.
        finish()
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density + 0.5f).toInt()

    private fun label(text: String, size: Float, secondary: Boolean = false) = TextView(this).apply {
        this.text = text
        textSize = size
        setTextColor(if (secondary) secondaryForeground else primaryTextColor)
        includeFontPadding = false
    }

    private fun layout(bottom: Int = 0) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT,
    ).apply { bottomMargin = bottom }

    private fun link(title: String, action: () -> Unit) = Button(this).apply {
        text = title
        isAllCaps = false
        setTextColor(racingRed)
        setBackgroundColor(Color.TRANSPARENT)
        minHeight = dp(48)
        setOnClickListener { action() }
    }

    private fun openGuide(path: String) {
        runCatching {
            startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(
                "https://github.com/chrissotraidis/kartpad/blob/main/docs/$path",
            )))
        }.onFailure {
            AlertDialog.Builder(this).setTitle("Could Not Open GitHub")
                .setMessage("Please try again when a browser is available. Setup and troubleshooting guides are in the chrissotraidis/kartpad repository on GitHub.")
                .setPositiveButton("OK", null).show()
        }
    }

    private fun refreshModeCards() {
        val current = pausedProfile()
        for ((button, profile) in listOf(original to "base", retro to "retro_rewind")) {
            val isRetro = profile == "retro_rewind"
            val ready = gameDataReady && (!isRetro || retroInstalled)
            val badge = when {
                current == profile -> "CURRENT GAME · PAUSED"
                current != null -> "NEXT LAUNCH"
                ready -> "READY TO PLAY"
                isRetro && !gameDataReady -> "BASE GAME REQUIRED"
                else -> "SETUP NEEDED"
            }
            val action = when {
                current == profile -> "Resume Game"
                current != null -> "Use on Next Launch"
                ready -> "Play Game"
                isRetro -> "Set Up Game"
                else -> "Import Game"
            }
            val note = if (isRetro) {
                if (retroInstalled) "Installed pack · ${RetroRewindRelease.VERSION}"
                else "Official pack · ${RetroRewindRelease.VERSION} · downloaded in the app"
            } else if (gameDataReady) "Game data imported"
            else "PAL (Europe) · ISO / WBFS · RMCP01 rev 0"
            button.update(badge, action, note, current == profile || (current == null && !isRetro))
        }
    }

    private fun buildContent(): View {
        val config = resources.configuration
        val largeText = config.fontScale >= 1.3f
        val compact = config.screenHeightDp < 500 && !largeText
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(12), 0, dp(12))
        }
        val header = LinearLayout(this).apply {
            orientation = if (largeText) LinearLayout.VERTICAL else LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val brand = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(ImageView(this@KartPadLaunchActivity).apply {
                setImageResource(R.drawable.kartpad_racing_mark)
                scaleType = ImageView.ScaleType.FIT_CENTER
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            }, LinearLayout.LayoutParams(dp(48), dp(48)).apply { marginEnd = dp(12) })
            addView(label("KartPad", 30f).apply { setTypeface(typeface, Typeface.BOLD) })
        }
        header.addView(brand, LinearLayout.LayoutParams(if (largeText) -1 else 0, -2, if (largeText) 0f else 1f))
        val theme = Switch(this).apply {
            text = "Dark mode"
            contentDescription = "Dark mode"
            setTextColor(primaryTextColor)
            isChecked = darkMode
            minHeight = dp(48)
            switchPadding = dp(10)
            thumbTintList = ColorStateList.valueOf(Color.WHITE)
            trackTintList = ColorStateList.valueOf(if (darkMode) Color.rgb(230, 6, 29) else Color.GRAY)
            setOnCheckedChangeListener { _, checked ->
                if (checked != darkMode) {
                    getSharedPreferences("kartpad_launcher", MODE_PRIVATE).edit().putBoolean("dark_mode", checked).apply()
                    // Activity recreation applies the theme to native dialogs as well.
                    // Saved preferred-launch state prevents a theme change from starting a game.
                    preferredLaunch.consumed = true
                    recreate()
                }
            }
        }
        header.addView(theme, LinearLayout.LayoutParams(-2, -2).apply { marginEnd = dp(16) })
        header.addView(link("Help") { showSetupHelp() })
        column.addView(header, layout(dp(if (compact) 16 else 28)))
        original = ModeButton(this, "Mario Kart Wii", compact, false, darkMode).apply {
            id = R.id.kartpad_mode_original
            setIcon(R.drawable.ic_kartpad_checkered_flag)
        }
        retro = ModeButton(this, "Retro Rewind", compact, true, darkMode).apply {
            id = R.id.kartpad_mode_retro_rewind
            setIcon(R.drawable.ic_kartpad_gobackward)
        }
        refreshModeCards()
        fun divider() = View(this).apply { setBackgroundColor(if (darkMode) Color.rgb(55, 55, 57) else Color.rgb(216, 214, 210)) }
        column.addView(original, layout(dp(10)))
        column.addView(divider(), LinearLayout.LayoutParams(-1, dp(1)).apply { bottomMargin = dp(10) })
        column.addView(retro, layout(dp(10)))
        column.addView(divider(), LinearLayout.LayoutParams(-1, dp(1)).apply { bottomMargin = dp(10) })
        progress = ProgressBar(this).apply { isIndeterminate = true }
        column.addView(progress, LinearLayout.LayoutParams(dp(24), dp(24)).apply { gravity = Gravity.CENTER_HORIZONTAL })
        status = label("Checking game data…", 13f, true).apply {
            id = R.id.kartpad_mode_status
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        column.addView(status, layout())
        preferenceButton = link("Ask every time") { showPreferredGame() }.apply { setTextColor(primaryTextColor) }
        updatePreferenceLabel()
        val launchChoice = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(label("On launch:", 13f, true), LinearLayout.LayoutParams(-2, -2).apply { marginEnd = dp(8) })
            addView(preferenceButton)
        }
        val footer = LinearLayout(this).apply {
            orientation = if (largeText || config.screenWidthDp < 650) LinearLayout.VERTICAL else LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(launchChoice)
            addView(label("Return here anytime from the in-game menu.", 13f, true).apply { gravity = Gravity.END },
                LinearLayout.LayoutParams(if (orientation == LinearLayout.HORIZONTAL) 0 else -1, -2,
                    if (orientation == LinearLayout.HORIZONTAL) 1f else 0f).apply { marginStart = dp(16) })
        }
        column.addView(footer, layout())
        val contentWidth = dp(minOf(1040, maxOf(0, config.screenWidthDp - 48)))
        val scroll = ScrollView(this).apply {
            isFillViewport = true
            addView(column, FrameLayout.LayoutParams(contentWidth, -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL))
        }
        return FrameLayout(this).apply {
            setBackgroundColor(if (darkMode) Color.rgb(17, 17, 17) else Color.rgb(251, 249, 242))
            addView(ImageView(this@KartPadLaunchActivity).apply {
                setImageResource(R.drawable.kartpad_checker)
                imageTintList = ColorStateList.valueOf(if (darkMode) Color.WHITE else Color.BLACK)
                alpha = if (darkMode) 1f else 0.65f
                scaleType = ImageView.ScaleType.CENTER_CROP
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            }, FrameLayout.LayoutParams(dp(70), -1, Gravity.END))
            setPadding(dp(24), 0, dp(24), 0)
            addView(scroll, FrameLayout.LayoutParams(-1, -1))
        }
    }

    private fun showPreferredGame() {
        preferredLaunch.consumed = true
        AlertDialog.Builder(this)
            .setTitle("Preferred Game on Next Launch")
            .setSingleChoiceItems(KartPadPreferredGame.labels,
                KartPadPreferredGame.values.indexOf(KartPadPreferredGame.read(filesDir))) { dialog, which ->
                runCatching { KartPadPreferredGame.write(filesDir, KartPadPreferredGame.values[which]) }
                    .onSuccess {
                        dialog.dismiss()
                        updatePreferenceLabel()
                        showStatus("Saved for next launch. Game data will be checked before starting.")
                    }
                    .onFailure {
                        dialog.dismiss()
                        showStatus("The preferred game could not be saved. Please try again.")
                    }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showSetupHelp() {
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(16), dp(24), dp(16))
        }
        fun section(title: String, body: String) {
            column.addView(label(title, 22f).apply { isAccessibilityHeading = true }, layout(dp(12)))
            column.addView(label(body, 16f, true), layout(dp(24)))
        }
        section("1. Import Mario Kart Wii",
            "Use your own PAL (Europe) ISO or WBFS: RMCP01, revision 0. An extracted DATA folder also works. RVZ files must be converted before importing.")
        section("2. Add Retro Rewind, if you want it",
            "Import Mario Kart Wii first, then choose Retro Rewind. KartPad can download and install the official ${RetroRewindRelease.VERSION} pack. You do not need to import a second disc.")
        section("Stuck on a step?",
            "The GitHub guides cover supported files, free space, installation and common problems. When reporting a problem, include your device, the exact steps and reviewed device logs when possible.")
        column.addView(link("Setup Guide on GitHub") { openGuide("INSTALL_ANDROID.md") }, layout())
        column.addView(link("Troubleshooting on GitHub") { openGuide("SUPPORT.md") }, layout())
        column.addView(link("Report a Problem…") {
            startActivity(Intent(this, KartPadProblemReportActivity::class.java))
        }, layout())
        column.addView(label("KartPad ${BuildConfig.VERSION_NAME} · Build ${BuildConfig.VERSION_CODE}", 13f, true), layout(dp(12)))
        column.addView(Button(this).apply {
            text = "Export Private Diagnostics…"
            isAllCaps = false
            setTextColor(secondaryForeground)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener {
                AlertDialog.Builder(this@KartPadLaunchActivity)
                    .setTitle("Export Private Diagnostics")
                    .setMessage("Save recent runtime logs and any retained app crash/hang traces to a location you choose. Traces may contain local paths, network information or other personal details. No game images, saves, profiles, or signing material are copied. Keep this file private and review it before sharing.")
                    .setNegativeButton("Cancel", null)
                    .setPositiveButton("Save Locally…") { _, _ ->
                        val sessions = runCatching { KartPadDiagnosticExport.sessions(this@KartPadLaunchActivity) }.getOrDefault(emptyList())
                        if (sessions.isEmpty()) {
                            // Early startup failures still have OS exit history, even without console.log.
                            exportSession = null
                            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/zip"
                                putExtra(Intent.EXTRA_TITLE, "KartPad-private-diagnostics.zip")
                            }, REQUEST_DIAGNOSTICS)
                        }
                        else AlertDialog.Builder(this@KartPadLaunchActivity).setTitle("Choose the game session")
                            .setItems(sessions.map { "${it.id}\nLast written: ${java.util.Date(it.modified)}" }.toTypedArray()) { _, index ->
                                exportSession = sessions[index].id
                                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = "application/zip"
                                    putExtra(Intent.EXTRA_TITLE, "KartPad-private-diagnostics.zip")
                                }, REQUEST_DIAGNOSTICS)
                            }.setNegativeButton("Back", null).show()
                    }.show()
            }
        }, layout(0))

        if (pausedProfile() == null && KartPadRatingStorage.hasPending(filesDir)) {
            column.addView(Button(this).apply {
                text = "Cancel Staged Rating Restore…"
                setOnClickListener {
                    AlertDialog.Builder(this@KartPadLaunchActivity)
                        .setTitle("Cancel Staged Rating Restore?")
                        .setMessage("Remove the pending request so you can start the game again. Current ratings and retained backups will stay as they are; this does not undo a restore that already completed.")
                        .setNegativeButton("Keep Restore", null)
                        .setPositiveButton("Cancel Restore") { _, _ ->
                            if (pausedProfile() == null) runCatching {
                                KartPadRatingStorage.cancelPending(filesDir)
                            }.onSuccess { visibility = View.GONE }
                                .onFailure { showStatus("The staged rating restore could not be cancelled.") }
                        }.show()
                }
            }, layout(0))
        }

        if (pausedProfile() == null) column.addView(Button(this).apply {
            fun refresh() {
                text = "Renderer Validation: " + if (KartPadRendererDiagnostics.enabled(context)) "On" else "Off"
            }
            refresh()
            isAllCaps = false
            setTextColor(secondaryForeground)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener {
                val enable = !KartPadRendererDiagnostics.enabled(context)
                AlertDialog.Builder(this@KartPadLaunchActivity)
                    .setTitle("Renderer Validation")
                    .setMessage("Checks the actual game renderer and enables buffer bounds protection. This may slow the game down; it is a diagnostic mode, not a graphics fix. Applies when you next open a game. After reproducing once, close KartPad, reopen this chooser and export private diagnostics. Turn it off here for normal play.")
                    .setNegativeButton("Cancel", null)
                    .setPositiveButton(if (enable) "Enable" else "Turn Off") { _, _ ->
                        if (!KartPadRendererDiagnostics.setEnabled(context, enable)) {
                            showStatus("The diagnostic setting could not be saved. Please try again.")
                        }
                        refresh()
                    }.show()
            }
        }, layout(0))


        column.addView(Button(this).apply {
            text = "Character Graphics Test…"
            isAllCaps = false
            setTextColor(secondaryForeground)
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { KartPadCharacterGraphicsTestDialog.show(this@KartPadLaunchActivity) }
        }, layout(0))

        val scroll = ScrollView(this).apply { addView(column) }
        AlertDialog.Builder(this).setTitle("Getting Started").setView(scroll)
            .setPositiveButton("Done", null).show()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_DIAGNOSTICS || resultCode != RESULT_OK) return
        val destination = data?.data ?: return
        val session = exportSession ?: run { showStatus("Choose the game session again before exporting."); return }
        showStatus("Exporting private diagnostics…")
        validator.execute {
            val succeeded = runCatching {
                KartPadDiagnosticExport.write(applicationContext, destination, session)
            }.isSuccess
            runOnUiThread {
                if (!isFinishing && !isDestroyed) showStatus(
                    if (succeeded) "Private diagnostics saved. Nothing was uploaded."
                    else "Diagnostics export failed. The destination may contain an incomplete archive.",
                )
            }
        }
    }

    private fun showStatus(message: String) {
        status.text = message
        status.visibility = View.VISIBLE
    }

    private fun hideStatus(accessibilityMessage: String) {
        status.text = accessibilityMessage
        status.visibility = View.GONE
        status.announceForAccessibility(accessibilityMessage)
    }

    companion object {
        const val EXTRA_SKIP_PREFERRED_GAME = "dev.kartpad.android.SKIP_PREFERRED_GAME"
        private const val STATE_PREFERRED_CONSUMED = "preferred_launch_consumed"
        private const val LOG_TAG = "KartPadLauncher"
        private const val EXTRA_DEBUG_RETRO_NOT_INSTALLED =
            "dev.kartpad.android.TEST_MODE_CHOOSER_RETRO_NOT_INSTALLED"
        private const val EXTRA_DEBUG_GAME_DATA_VALID =
            "dev.kartpad.android.TEST_MODE_CHOOSER_GAME_DATA_VALID"
        private const val REQUEST_GAME_DATA = 4_303
        private const val REQUEST_DIAGNOSTICS = 4_304
    }

    /** One focusable row retains the same selection callback and controller behavior. */
    private class ModeButton(
        context: android.content.Context, private val gameTitle: String,
        compact: Boolean, isRetro: Boolean, private val dark: Boolean,
    ) : LinearLayout(context) {
        private fun dp(value: Int) = (value * resources.displayMetrics.density + 0.5f).toInt()
        private val accent = if (isRetro) Color.rgb(255, 174, 20) else Color.rgb(26, 133, 255)
        private val primaryTextColor = if (dark) Color.rgb(247, 247, 247) else Color.rgb(12, 17, 26)
        private val red = if (dark) Color.rgb(255, 51, 66) else Color.rgb(204, 9, 31)
        private val icon = ImageView(context)
        private fun text(size: Float, color: Int) = TextView(context).apply {
            textSize = size
            setTextColor(color)
            includeFontPadding = false
        }
        private val badge = text(13f, if (dark) Color.rgb(170, 170, 170) else Color.rgb(94, 94, 94))
        private val action = text(16f, primaryTextColor).apply {
            gravity = Gravity.CENTER
            minHeight = dp(48)
            setPadding(dp(16), dp(14), dp(16), dp(14))
        }
        init {
            val stacked = resources.configuration.fontScale >= 1.3f || resources.configuration.screenWidthDp < 600
            orientation = if (stacked) VERTICAL else HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            isClickable = true
            isFocusable = true
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
            descendantFocusability = FOCUS_BLOCK_DESCENDANTS
            setPadding(dp(18), dp(16), dp(18), dp(16))
            val identity = LinearLayout(context).apply {
                orientation = HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(icon, LayoutParams(dp(36), dp(36)).apply { marginEnd = dp(18) })
                addView(LinearLayout(context).apply {
                    orientation = VERTICAL
                    addView(text(if (compact) 22f else 28f, primaryTextColor).apply {
                        text = gameTitle
                        setTypeface(typeface, Typeface.BOLD)
                    })
                    addView(badge, LayoutParams(-1, -2).apply { topMargin = dp(4) })
                }, LayoutParams(-1, -2))
            }
            addView(identity, LayoutParams(if (stacked) -1 else 0, -2, if (stacked) 0f else 1f))
            addView(action, LayoutParams(if (stacked) -1 else dp(215), -2).apply {
                if (stacked) topMargin = dp(12) else marginStart = dp(16)
            })
        }
        override fun getAccessibilityClassName(): CharSequence = Button::class.java.name
        override fun setEnabled(enabled: Boolean) {
            super.setEnabled(enabled)
            alpha = if (enabled) 1f else 0.5f
        }
        fun setIcon(resource: Int) {
            icon.setImageResource(resource)
            icon.imageTintList = ColorStateList.valueOf(accent)
            icon.importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        fun update(status: String, actionTitle: String, metadata: String, primary: Boolean) {
            badge.text = when (status) {
                "CURRENT GAME · PAUSED" -> "Paused"
                "NEXT LAUNCH" -> "Next launch"
                "READY TO PLAY" -> "Ready to play"
                "BASE GAME REQUIRED" -> "Import Mario Kart Wii first"
                else -> "Setup needed"
            }
            action.text = "$actionTitle  →"
            action.setTextColor(if (primary) Color.WHITE else red)
            action.background = GradientDrawable().apply {
                cornerRadius = dp(10).toFloat()
                setColor(if (primary) Color.rgb(228, 6, 27) else Color.TRANSPARENT)
            }
            val current = status == "CURRENT GAME · PAUSED"
            val shape = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(if (current) { if (dark) Color.rgb(47, 24, 27) else Color.rgb(249, 232, 229) } else Color.TRANSPARENT)
            }
            background = RippleDrawable(ColorStateList.valueOf(Color.argb(60, 255, 51, 66)), shape, null)
            contentDescription = "$actionTitle, $gameTitle. $status. $metadata"
        }
    }
}
