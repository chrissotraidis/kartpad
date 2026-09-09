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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        KartPadExitDiagnostics.mark(this, pausedProfile() ?: "chooser")
        setContentView(buildContent())
        original.setOnClickListener { selectMode("base") }
        retro.setOnClickListener { selectMode("retro_rewind") }
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
                pendingProfile?.takeIf { gameDataReady }?.let { profile ->
                    pendingProfile = null
                    continueSelectedMode(profile)
                }
            }
        }
    }

    private fun selectMode(profile: String) {
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
        setTextColor(if (secondary) Color.rgb(179, 191, 209) else Color.WHITE)
        includeFontPadding = false
    }

    private fun layout(bottom: Int = 0) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT,
    ).apply { bottomMargin = bottom }

    private fun link(title: String, action: () -> Unit) = Button(this).apply {
        text = title
        isAllCaps = false
        setTextColor(Color.rgb(122, 191, 255))
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
        val stacked = largeText || (!compact && config.screenWidthDp < 660)
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(16), 0, dp(16))
        }
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(ImageView(this@KartPadLaunchActivity).apply {
                setImageResource(R.drawable.kartpad_app_icon)
                importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            }, LinearLayout.LayoutParams(dp(48), dp(48)).apply { marginEnd = dp(16) })
            addView(label("KartPad", 30f).apply { setTypeface(typeface, Typeface.BOLD) },
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            addView(link("Help") { showSetupHelp() })
        }
        column.addView(header, layout(dp(if (compact) 12 else 30)))
        if (!compact) {
            column.addView(label(if (pausedProfile() == null) "Choose a game" else "Back to the race", 32f), layout(dp(12)))
            column.addView(label(if (pausedProfile() == null)
                "Start with Mario Kart Wii. Add Retro Rewind whenever you're ready."
                else "Your game is paused. Resume now, or choose a game for the next launch.",
                17f, true), layout(dp(22)))
        }
        original = ModeButton(this, "Mario Kart Wii", compact, false).apply {
            id = R.id.kartpad_mode_original
            setIcon(R.drawable.ic_kartpad_checkered_flag)
        }
        retro = ModeButton(this, "Retro Rewind", compact, true).apply {
            id = R.id.kartpad_mode_retro_rewind
            setIcon(R.drawable.ic_kartpad_gobackward)
        }
        refreshModeCards()
        val choices = LinearLayout(this).apply {
            orientation = if (stacked) LinearLayout.VERTICAL else LinearLayout.HORIZONTAL
            for ((index, card) in listOf(original, retro).withIndex()) {
                addView(card, LinearLayout.LayoutParams(
                    if (stacked) LinearLayout.LayoutParams.MATCH_PARENT else 0,
                    LinearLayout.LayoutParams.WRAP_CONTENT, if (stacked) 0f else 1f,
                ).apply {
                    if (index == 0) {
                        if (stacked) bottomMargin = dp(16) else marginEnd = dp(20)
                    }
                })
            }
        }
        column.addView(choices, layout(dp(10)))
        progress = ProgressBar(this).apply { isIndeterminate = true }
        column.addView(progress, LinearLayout.LayoutParams(dp(28), dp(28)).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        })
        status = label("Checking game data…", 13f, true).apply {
            id = R.id.kartpad_mode_status
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        column.addView(status, layout())
        if (!compact) {
            column.addView(label("A little help getting started", 18f), layout(dp(8)))
            column.addView(link("Setup guide") { openGuide("INSTALL_ANDROID.md") }, layout())
            column.addView(link("Troubleshooting") { openGuide("SUPPORT.md") }, layout())
        }
        // No fixed minimum width: narrow windows and large text may scroll, never clip.
        val contentWidth = dp(minOf(920, maxOf(0, config.screenWidthDp - 48)))
        val scroll = ScrollView(this).apply {
            isFillViewport = true
            addView(column, FrameLayout.LayoutParams(contentWidth,
                FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.CENTER_HORIZONTAL))
        }
        return FrameLayout(this).apply {
            setBackgroundColor(Color.rgb(9, 13, 20))
            setPadding(dp(24), 0, dp(24), 0)
            addView(scroll, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        }
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
            setTextColor(Color.argb(184, 255, 255, 255))
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener {
                AlertDialog.Builder(this@KartPadLaunchActivity)
                    .setTitle("Export Private Diagnostics")
                    .setMessage("Save recent runtime logs to a location you choose. Logs may contain local paths or personal details. No game images, saves, profiles, or signing material are copied. Keep this file private and review it before sharing.")
                    .setNegativeButton("Cancel", null)
                    .setPositiveButton("Save Locally…") { _, _ ->
                        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/zip"
                            putExtra(Intent.EXTRA_TITLE, "KartPad-private-diagnostics.zip")
                        }, REQUEST_DIAGNOSTICS)
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
            setTextColor(Color.argb(184, 255, 255, 255))
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


        val scroll = ScrollView(this).apply { addView(column) }
        AlertDialog.Builder(this).setTitle("Getting Started").setView(scroll)
            .setPositiveButton("Done", null).show()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_DIAGNOSTICS || resultCode != RESULT_OK) return
        val destination = data?.data ?: return
        showStatus("Exporting private diagnostics…")
        validator.execute {
            val succeeded = runCatching {
                KartPadDiagnosticExport.write(applicationContext, destination)
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
        private const val LOG_TAG = "KartPadLauncher"
        private const val EXTRA_DEBUG_RETRO_NOT_INSTALLED =
            "dev.kartpad.android.TEST_MODE_CHOOSER_RETRO_NOT_INSTALLED"
        private const val EXTRA_DEBUG_GAME_DATA_VALID =
            "dev.kartpad.android.TEST_MODE_CHOOSER_GAME_DATA_VALID"
        private const val REQUEST_GAME_DATA = 4_303
        private const val REQUEST_DIAGNOSTICS = 4_304
    }

    /** One focusable game card preserves the chooser's existing selection callback. */
    private class ModeButton(
        context: android.content.Context, private val gameTitle: String,
        compact: Boolean, isRetro: Boolean,
    ) : LinearLayout(context) {
        private fun dp(value: Int) = (value * resources.displayMetrics.density + 0.5f).toInt()
        private val accent = if (isRetro) Color.rgb(196, 171, 255) else Color.rgb(110, 186, 255)
        private val icon = ImageView(context)
        private fun text(size: Float, color: Int) = TextView(context).apply {
            textSize = size
            setTextColor(color)
            includeFontPadding = false
        }
        private val badge = text(11f, accent)
        private val note = text(13f, Color.rgb(179, 191, 209))
        private val action = text(16f, Color.WHITE).apply {
            gravity = Gravity.CENTER
            minHeight = dp(50)
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
        init {
            orientation = VERTICAL
            isClickable = true
            isFocusable = true
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
            descendantFocusability = FOCUS_BLOCK_DESCENDANTS
            setPadding(dp(24), dp(24), dp(24), dp(24))
            fun fill(color: Int) = GradientDrawable().apply {
                cornerRadius = dp(20).toFloat()
                setColor(color)
                setStroke(dp(1), Color.rgb(43, 54, 71))
            }
            background = StateListDrawable().apply {
                addState(intArrayOf(android.R.attr.state_pressed), fill(Color.rgb(33, 46, 65)))
                addState(intArrayOf(android.R.attr.state_focused), fill(Color.rgb(33, 46, 65)))
                addState(intArrayOf(), fill(Color.rgb(19, 26, 38)))
            }
            val top = LinearLayout(context).apply {
                orientation = HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(icon, LayoutParams(dp(32), dp(32)).apply { marginEnd = dp(12) })
                addView(badge.apply { gravity = Gravity.END }, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
            }
            addView(top, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(18) })
            addView(text(if (compact) 22f else 28f, Color.WHITE).apply { text = gameTitle },
                LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(18) })
            if (!compact) {
                addView(text(16f, Color.rgb(179, 191, 209)).apply {
                    text = if (isRetro) "More tracks, characters and Retro WFC online play. Uses your Mario Kart Wii game data."
                    else "Grand Prix, time trials and local races. Your original game, on this device."
                }, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(12) })
                addView(note, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply { bottomMargin = dp(18) })
            }
            addView(action, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
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
            badge.text = status
            action.text = "$actionTitle  →"
            note.text = metadata
            action.background = GradientDrawable().apply {
                cornerRadius = dp(8).toFloat()
                setColor(if (primary) Color.rgb(41, 120, 224) else Color.rgb(48, 59, 79))
            }
            contentDescription = "$actionTitle, $gameTitle. $status. $metadata"
        }
    }
}
