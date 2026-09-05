package dev.kartpad.android

import android.app.Activity
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
class KartPadLaunchActivity : Activity() {
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
        setContentView(buildContent())
        original.setOnClickListener { selectMode("base") }
        retro.setOnClickListener { selectMode("retro_rewind") }
    }

    override fun onResume() {
        super.onResume()
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
            val gameDataValid = forceGameDataValid ||
                (removalError == null && KartPadGameDataStorage.validationError(filesDir) == null)
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
                setModeText(
                    retro,
                    "Retro Rewind",
                    if (valid) {
                        "Installed ${RetroRewindRelease.VERSION} • Extra content + Retro WFC"
                    } else {
                        "Download ${RetroRewindRelease.VERSION} • Extra content + Retro WFC"
                    },
                )
                if (removalError != null) {
                    showStatus(removalError)
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

    private fun buildContent(): View {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density + 0.5f).toInt()
        fun label(text: String, size: Float, color: Int): TextView = TextView(this).apply {
            this.text = text
            textSize = size
            setTextColor(color)
            gravity = Gravity.CENTER
        }
        fun layout(bottom: Int) = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply { bottomMargin = bottom }

        fun roundedButton(normal: Int, pressed: Int): StateListDrawable = StateListDrawable().apply {
            fun fill(color: Int) = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(18).toFloat()
                setColor(color)
            }
            addState(intArrayOf(android.R.attr.state_pressed), fill(pressed))
            addState(intArrayOf(-android.R.attr.state_enabled), fill(Color.rgb(62, 62, 72)))
            addState(intArrayOf(), fill(normal))
        }
        fun styleModeButton(button: ModeButton, color: Int, pressed: Int, icon: Int) {
            button.apply {
                minimumHeight = dp(96)
                setPadding(dp(28), dp(24), dp(28), dp(24))
                background = roundedButton(color, pressed)
                backgroundTintList = null
                elevation = 0f
                stateListAnimator = null
                setIcon(icon, dp(20), dp(12))
            }
        }

        val background = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(
                Color.rgb(6, 19, 38),
                Color.rgb(26, 14, 46),
                Color.rgb(46, 11, 20),
            ),
        )
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            translationY = -dp(18).toFloat()
        }
        column.addView(ImageView(this).apply {
            setImageResource(R.drawable.ic_kartpad_steering_wheel)
            imageTintList = ColorStateList.valueOf(Color.rgb(255, 107, 46))
            contentDescription = "KartPad"
            scaleType = ImageView.ScaleType.CENTER_INSIDE
        }, LinearLayout.LayoutParams(dp(48), dp(48)).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            bottomMargin = dp(12)
        })
        column.addView(label("KartPad", 34f, Color.WHITE).apply {
            setTypeface(typeface, Typeface.BOLD)
            includeFontPadding = false
        }, layout(dp(12)))
        column.addView(
            label("Choose your way to race", 20f, Color.argb(224, 255, 255, 255)).apply {
                setTypeface(typeface, Typeface.BOLD)
                includeFontPadding = false
            },
            layout(dp(12)),
        )
        column.addView(
            label(
                "Your own RMCP01 disc image or extracted game data is required before play.",
                17f,
                Color.argb(158, 255, 255, 255),
            ),
            layout(dp(24)),
        )
        original = ModeButton(this).apply {
            id = R.id.kartpad_mode_original
            styleModeButton(
                this,
                Color.rgb(8, 125, 255),
                Color.rgb(4, 99, 214),
                R.drawable.ic_kartpad_checkered_flag,
            )
            setModeText(this, "Mario Kart Wii", "Original game")
        }
        retro = ModeButton(this).apply {
            id = R.id.kartpad_mode_retro_rewind
            styleModeButton(
                this,
                Color.rgb(245, 56, 99),
                Color.rgb(207, 38, 78),
                R.drawable.ic_kartpad_gobackward,
            )
            setModeText(this, "Retro Rewind", "Checking installation…")
            isEnabled = false
        }
        val choices = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            addView(
                original,
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    .apply { marginEnd = dp(9) },
            )
            addView(
                retro,
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    .apply { marginStart = dp(9) },
            )
        }
        column.addView(choices, layout(dp(10)))
        progress = ProgressBar(this).apply {
            isIndeterminate = true
        }
        column.addView(progress, LinearLayout.LayoutParams(dp(28), dp(28)).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            bottomMargin = dp(2)
        })
        status = label(
            "Checking game data and Retro Rewind ${RetroRewindRelease.VERSION}…",
            13f,
            Color.argb(184, 255, 255, 255),
        )
        status.id = R.id.kartpad_mode_status
        status.accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        column.addView(status, layout(0))

        val availableWidthDp = (resources.displayMetrics.widthPixels / density).toInt() - 64
        val contentWidth = dp(minOf(760, maxOf(320, availableWidthDp)))
        val scroll = ScrollView(this).apply {
            isFillViewport = true
            clipToPadding = false
            addView(column, FrameLayout.LayoutParams(
                contentWidth,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ))
        }
        return FrameLayout(this).apply {
            this.background = background
            setPadding(dp(32), 0, dp(32), 0)
            addView(scroll, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ))
        }
    }

    private fun setModeText(button: ModeButton, title: String, subtitle: String) {
        button.setModeText(title, subtitle)
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
    }

    /** Centers the icon and two-line label as one unit, matching UIButton.Configuration. */
    private class ModeButton(context: android.content.Context) : LinearLayout(context) {
        private val icon = ImageView(context)
        private val title = TextView(context).apply {
            textSize = 18f
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            includeFontPadding = false
            gravity = Gravity.CENTER
        }
        private val subtitle = TextView(context).apply {
            textSize = 14f
            setTextColor(Color.argb(205, 255, 255, 255))
            includeFontPadding = false
            gravity = Gravity.CENTER
        }
        private val labels = LinearLayout(context).apply {
            orientation = VERTICAL
            gravity = Gravity.CENTER
            addView(title, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
            addView(subtitle, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT))
        }

        init {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER
            isClickable = true
            isFocusable = true
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
            addView(icon)
            addView(labels)
        }

        override fun getAccessibilityClassName(): CharSequence = Button::class.java.name

        fun setIcon(resource: Int, size: Int, spacing: Int) {
            icon.setImageResource(resource)
            icon.imageTintList = ColorStateList.valueOf(Color.WHITE)
            icon.layoutParams = LayoutParams(size, size).apply { marginEnd = spacing }
        }

        fun setModeText(title: String, subtitle: String) {
            this.title.text = title
            this.subtitle.text = subtitle
            contentDescription = "$title\n$subtitle"
        }
    }
}
