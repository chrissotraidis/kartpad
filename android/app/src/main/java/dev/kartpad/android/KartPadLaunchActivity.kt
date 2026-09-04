package dev.kartpad.android

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import java.util.concurrent.Executors

/** Production owner for choosing the immutable runtime profile before SDL starts. */
class KartPadLaunchActivity : Activity() {
    private lateinit var status: TextView
    private lateinit var original: Button
    private lateinit var retro: Button
    private lateinit var progress: ProgressBar
    private val validator = Executors.newSingleThreadExecutor()
    private var validationGeneration = 0
    private var retroInstalled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildContent())
        original.setOnClickListener { launch("base") }
        retro.setOnClickListener {
            if (retroInstalled) {
                launch("retro_rewind")
            } else {
                startActivity(Intent(this, RetroRewindInstallActivity::class.java))
            }
        }
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
        retroInstalled = false
        status.text = "Checking Retro Rewind ${RetroRewindRelease.VERSION}…"
        progress.visibility = View.VISIBLE
        retro.isEnabled = false
        validator.execute {
            val valid = !forceNotInstalled && runCatching {
                RetroRewindInstallStorage.recover(filesDir)
                RetroRewindInstallValidator.validate(
                    RetroRewindInstallStorage.installedRoot(filesDir)
                        .resolve(RetroRewindRelease.ROOT),
                    RetroRewindInstallValidator.productionContract(),
                ).isValid
            }.getOrDefault(false)
            runOnUiThread {
                if (generation != validationGeneration || isFinishing || isDestroyed) {
                    return@runOnUiThread
                }
                retroInstalled = valid
                progress.visibility = View.GONE
                retro.isEnabled = true
                if (valid) {
                    status.text = "Retro Rewind ${RetroRewindRelease.VERSION} is ready"
                    retro.text = "Retro Rewind\nInstalled ${RetroRewindRelease.VERSION} • Extra content + Retro WFC"
                } else {
                    status.text = "Retro Rewind is optional"
                    retro.text = "Retro Rewind\nDownload ${RetroRewindRelease.VERSION} • Extra content + Retro WFC"
                }
                retro.contentDescription = retro.text
                Log.i(LOG_TAG, "A3 mode chooser retro-installed=$valid")
            }
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

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(24), dp(12), dp(24), dp(12))
            setBackgroundColor(Color.rgb(24, 12, 22))
        }
        column.addView(label("KartPad", 28f, Color.WHITE), layout(dp(2)))
        column.addView(
            label("Choose your way to race", 17f, Color.rgb(255, 117, 76)),
            layout(dp(6)),
        )
        column.addView(
            label(
                "Your own RMCP01 disc image or extracted game data is required before play.",
                13f,
                Color.rgb(205, 194, 202),
            ),
            layout(dp(10)),
        )
        original = Button(this).apply {
            id = R.id.kartpad_mode_original
            text = "Mario Kart Wii\nOriginal game"
            contentDescription = text
            minHeight = dp(64)
        }
        retro = Button(this).apply {
            id = R.id.kartpad_mode_retro_rewind
            text = "Retro Rewind\nChecking installation…"
            contentDescription = text
            isEnabled = false
            minHeight = dp(64)
        }
        val choices = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            addView(
                original,
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    .apply { marginEnd = dp(6) },
            )
            addView(
                retro,
                LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    .apply { marginStart = dp(6) },
            )
        }
        column.addView(choices, layout(dp(6)))
        progress = ProgressBar(this).apply {
            isIndeterminate = true
        }
        column.addView(progress, layout(dp(6)))
        status = label("Checking Retro Rewind ${RetroRewindRelease.VERSION}…", 14f, Color.LTGRAY)
        status.id = R.id.kartpad_mode_status
        status.accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        column.addView(status, layout(0))

        return ScrollView(this).apply {
            isFillViewport = true
            addView(column)
        }
    }

    companion object {
        private const val LOG_TAG = "KartPadLauncher"
        private const val EXTRA_DEBUG_RETRO_NOT_INSTALLED =
            "dev.kartpad.android.TEST_MODE_CHOOSER_RETRO_NOT_INSTALLED"
    }
}
