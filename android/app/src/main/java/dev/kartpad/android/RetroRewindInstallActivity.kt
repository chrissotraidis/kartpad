package dev.kartpad.android

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.lifecycle.LiveData
import java.util.concurrent.Executors

/** Production owner for visible, lifecycle-independent Retro Rewind installation work. */
internal class RetroRewindInstallActivity : Activity() {
    private lateinit var status: TextView
    private lateinit var detail: TextView
    private lateinit var progress: ProgressBar
    private lateinit var primary: Button
    private lateinit var cancel: Button
    private lateinit var workLiveData: LiveData<List<WorkInfo>>
    private val validator = Executors.newSingleThreadExecutor()
    private var validationGeneration = 0
    private var lastLoggedState = ""
    private val workObserver = androidx.lifecycle.Observer<List<WorkInfo>> { work ->
        renderWork(selectCurrent(work.orEmpty()))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildContent())
        primary.setOnClickListener { requestNotificationPermissionOrInstall() }
        cancel.setOnClickListener {
            Log.i(LOG_TAG, "A3 installer UI cancel requested")
            RetroRewindInstallWork.cancel(this)
        }
        workLiveData = WorkManager.getInstance(applicationContext)
            .getWorkInfosForUniqueWorkLiveData(RetroRewindInstallWork.UNIQUE_NAME)
        workLiveData.observeForever(workObserver)
        if (BuildConfig.DEBUG && savedInstanceState == null &&
            intent.getBooleanExtra(EXTRA_DEBUG_FIXTURE, false)
        ) {
            primary.performClick()
        }
    }

    override fun onDestroy() {
        workLiveData.removeObserver(workObserver)
        validationGeneration += 1
        validator.shutdownNow()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return
        if (grantResults.singleOrNull() == PackageManager.PERMISSION_GRANTED) {
            enqueueInstall()
        } else {
            logState("notification-permission-required")
            renderRetry(
                "Notification permission is required so this long installation remains visible and controllable.",
            )
        }
    }

    private fun requestNotificationPermissionOrInstall() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
            return
        }
        enqueueInstall()
    }

    private fun enqueueInstall() {
        if (BuildConfig.DEBUG && intent.getBooleanExtra(EXTRA_DEBUG_FIXTURE, false)) {
            RetroRewindInstallWork.enqueueDebugFixture(this, steps = 120, delayMillis = 250)
        } else {
            RetroRewindInstallWork.enqueue(this)
        }
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

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(32), dp(28), dp(32), dp(28))
            setBackgroundColor(Color.rgb(24, 12, 22))
        }
        column.addView(label("KartPad", 34f, Color.WHITE), matchWrap(bottom = dp(4)))
        column.addView(
            label("Retro Rewind ${RetroRewindRelease.VERSION}", 22f, Color.rgb(255, 117, 76)),
            matchWrap(bottom = dp(18)),
        )
        column.addView(
            label(
                "Optional community content for extra tracks, characters, and Retro WFC. " +
                    "KartPad downloads the pinned official full pack and verifies it before use.",
                16f,
                Color.rgb(220, 211, 218),
            ),
            matchWrap(bottom = dp(22)),
        )
        status = label("Checking installation…", 20f, Color.WHITE)
        status.id = R.id.retro_rewind_install_status
        status.accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        column.addView(status, matchWrap(bottom = dp(8)))
        detail = label("", 15f, Color.rgb(190, 180, 188))
        detail.id = R.id.retro_rewind_install_detail
        column.addView(detail, matchWrap(bottom = dp(16)))
        progress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            id = R.id.retro_rewind_install_progress
            max = 1000
            isIndeterminate = true
        }
        column.addView(progress, matchFixed(dp(360), dp(8), dp(18)))
        primary = Button(this).apply {
            id = R.id.retro_rewind_install_primary
            text = "Download official pack"
            contentDescription = text
        }
        column.addView(primary, matchFixed(dp(360), dp(56), dp(10)))
        cancel = Button(this).apply {
            id = R.id.retro_rewind_install_cancel
            text = "Cancel installation"
            contentDescription = text
            visibility = View.GONE
        }
        column.addView(cancel, matchFixed(dp(360), dp(56), 0))

        return ScrollView(this).apply {
            isFillViewport = true
            addView(column)
        }
    }

    private fun matchWrap(bottom: Int) = LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT,
    ).apply { bottomMargin = bottom }

    private fun matchFixed(width: Int, height: Int, bottom: Int) = LinearLayout.LayoutParams(
        width,
        height,
    ).apply { bottomMargin = bottom }

    private fun selectCurrent(work: List<WorkInfo>): WorkInfo? =
        work.firstOrNull { !it.state.isFinished } ?: work.lastOrNull()

    private fun renderWork(info: WorkInfo?) {
        if (info == null) {
            validateInstalled()
            return
        }
        validationGeneration += 1
        val data = if (info.state.isFinished) info.outputData else info.progress
        val phase = data.getString(RetroRewindInstallWork.KEY_PHASE).orEmpty()
        val completed = data.getLong(RetroRewindInstallWork.KEY_COMPLETED_BYTES, 0)
        val total = data.getLong(RetroRewindInstallWork.KEY_TOTAL_BYTES, 0)
        val active = !info.state.isFinished
        cancel.visibility = if (active) View.VISIBLE else View.GONE
        primary.visibility = if (active) View.GONE else View.VISIBLE
        when (info.state) {
            WorkInfo.State.ENQUEUED, WorkInfo.State.BLOCKED -> renderWaiting()
            WorkInfo.State.RUNNING -> renderProgress(phase, completed, total)
            WorkInfo.State.SUCCEEDED -> {
                if (BuildConfig.DEBUG && intent.getBooleanExtra(EXTRA_DEBUG_FIXTURE, false)) {
                    renderFixtureComplete()
                } else {
                    validateInstalled()
                }
            }
            WorkInfo.State.CANCELLED -> {
                logState("cancelled")
                renderRetry("Installation cancelled. The partial download was kept for resume.")
            }
            WorkInfo.State.FAILED -> {
                logState("failed")
                val error = data.getString(RetroRewindInstallWork.KEY_ERROR) ?: "unknown"
                val latest = data.getString(RetroRewindInstallWork.KEY_LATEST_VERSION)
                renderRetry(friendlyError(error, latest))
            }
        }
    }

    private fun validateInstalled() {
        val generation = ++validationGeneration
        renderChecking()
        validator.execute {
            val result = RetroRewindInstallValidator.validate(
                RetroRewindInstallStorage.installedRoot(filesDir).resolve(RetroRewindRelease.ROOT),
                RetroRewindInstallValidator.productionContract(),
            )
            runOnUiThread {
                if (generation != validationGeneration || isFinishing || isDestroyed) return@runOnUiThread
                if (result.isValid) renderInstalled() else renderNotInstalled()
            }
        }
    }

    private fun renderChecking() {
        status.text = "Checking installation…"
        detail.text = "Verifying the installed version and required files."
        progress.isIndeterminate = true
        progress.visibility = View.VISIBLE
        primary.visibility = View.GONE
        cancel.visibility = View.GONE
    }

    private fun renderWaiting() {
        logState("waiting")
        status.text = "Waiting to download…"
        detail.text = "Connect to the internet to continue. You can leave this screen."
        progress.isIndeterminate = true
        progress.visibility = View.VISIBLE
    }

    private fun renderProgress(phase: String, completed: Long, total: Long) {
        logState("running-$phase")
        status.text = when (phase) {
            "version" -> "Checking Retro Rewind version…"
            "space" -> "Checking free space…"
            "extract" -> "Installing Retro Rewind…"
            else -> "Downloading Retro Rewind…"
        }
        if (total > 0 && completed in 0..total) {
            val percent = (completed * 100 / total).toInt()
            progress.isIndeterminate = false
            progress.progress = (completed * progress.max / total).toInt()
            detail.text = "$percent% • ${formatBytes(completed)} of ${formatBytes(total)}"
        } else {
            progress.isIndeterminate = true
            detail.text = "You can leave this screen; installation continues in the background."
        }
        progress.visibility = View.VISIBLE
    }

    private fun renderInstalled() {
        logState("installed")
        status.text = "Retro Rewind is ready"
        detail.text = "Installed version ${RetroRewindRelease.VERSION} passed KartPad's pinned checks."
        progress.visibility = View.GONE
        primary.visibility = View.GONE
        cancel.visibility = View.GONE
    }

    private fun renderFixtureComplete() {
        logState("fixture-complete")
        status.text = "Installer UI fixture completed"
        detail.text = "The bounded test worker finished; no game data was installed."
        progress.visibility = View.GONE
        primary.visibility = View.GONE
        cancel.visibility = View.GONE
    }

    private fun renderNotInstalled() {
        logState("not-installed")
        status.text = "Retro Rewind is not installed"
        detail.text = "The download is 1.73 GiB. Installation requires about 4.03 GiB free on shared app storage."
        progress.visibility = View.GONE
        primary.text = "Download official pack"
        primary.contentDescription = primary.text
        primary.visibility = View.VISIBLE
        cancel.visibility = View.GONE
    }

    private fun renderRetry(message: String) {
        status.text = "Retro Rewind needs attention"
        detail.text = message
        progress.visibility = View.GONE
        primary.text = "Retry installation"
        primary.contentDescription = primary.text
    }

    private fun friendlyError(error: String, latestVersion: String?): String = when {
        error == "version-update-required" ->
            "Retro Rewind ${latestVersion ?: "a newer release"} requires a newer KartPad build before installation or online play."
        error.startsWith("version-") ->
            "KartPad could not verify the current official Retro Rewind version. Try again before installing."
        error.startsWith("space-") -> "Not enough safe app storage is available for this installation."
        error.startsWith("download-network_failure") -> "The download could not reach the official server."
        error.startsWith("download-") -> "The official download failed its pinned integrity or protocol checks."
        error.startsWith("install-") -> "The pack could not be safely verified and installed."
        error == "recovery" -> "KartPad could not safely recover the previous installation."
        else -> "Installation failed ($error)."
    }

    private fun formatBytes(bytes: Long): String {
        val gib = bytes.toDouble() / (1024.0 * 1024.0 * 1024.0)
        val mib = bytes.toDouble() / (1024.0 * 1024.0)
        return when {
            gib >= 0.1 -> String.format(java.util.Locale.US, "%.2f GiB", gib)
            mib >= 0.1 -> String.format(java.util.Locale.US, "%.1f MiB", mib)
            else -> "$bytes B"
        }
    }

    private fun logState(state: String) {
        if (state == lastLoggedState) return
        lastLoggedState = state
        Log.i(LOG_TAG, "A3 installer UI state=$state")
    }

    companion object {
        private const val LOG_TAG = "KartPadInstaller"
        private const val NOTIFICATION_PERMISSION_REQUEST = 0x4b50
        private const val EXTRA_DEBUG_FIXTURE = "dev.kartpad.android.TEST_RETRO_REWIND_INSTALLER_UI"
    }
}
