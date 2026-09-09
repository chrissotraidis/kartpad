package dev.kartpad.android

import android.app.Activity
import android.app.AlertDialog
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.text.InputFilter
import android.view.View
import android.view.WindowInsets
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.TextView
import java.util.UUID

/** Keeps the report open while Android's document picker or share sheet is in front. */
class KartPadProblemReportActivity : Activity() {
    private lateinit var problem: EditText
    private lateinit var area: EditText
    private lateinit var frequency: EditText
    private lateinit var reason: EditText
    private lateinit var choices: RadioGroup
    private lateinit var reviewed: CheckBox
    private lateinit var selectedFile: TextView
    private lateinit var status: TextView
    private var attachment: Uri? = null
    private var attachmentName = ""
    private var reportId = ""
    private var export: LocalExport? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        reportId = savedInstanceState?.getString("report_id")
            ?: "KP-${UUID.randomUUID().toString().take(8).uppercase()}"
        attachment = savedInstanceState?.getString("attachment")?.let(Uri::parse)
        attachmentName = savedInstanceState?.getString("attachment_name").orEmpty()
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(20), dp(24), dp(20))
        }
        fun label(text: String) = TextView(this).apply {
            this.text = text
            textSize = 16f
            setPadding(0, dp(8), 0, dp(8))
            column.addView(this)
        }
        fun field(hint: String, key: String, limit: Int, lines: Int = 1) = EditText(this).apply {
            this.hint = hint
            contentDescription = hint
            isSingleLine = lines == 1
            minLines = lines
            maxLines = 4
            filters = arrayOf(InputFilter.LengthFilter(limit))
            setText(savedInstanceState?.getString(key).orEmpty())
            column.addView(this)
        }
        fun button(text: String, action: () -> Unit) = Button(this).apply {
            this.text = text
            isAllCaps = false
            setOnClickListener { action() }
            column.addView(this)
        }
        label("Report a Problem").textSize = 24f
        problem = field("What went wrong?", "problem", 2000, 2)
        area = field("Area and what you were doing", "area", 1000)
        frequency = field("Every time, sometimes, once, or not sure?", "frequency", 160)
        label("Device logs are strongly recommended for slowdowns, graphics problems and crashes. Export privately, review locally, then choose only relevant log text. Reports on GitHub are public.")
        button("Export Private Logs…") {
            AlertDialog.Builder(this)
                .setTitle("Review before sharing")
                .setMessage("This saves a private ZIP. Open it locally and choose relevant .log, .txt or .json files to share. Do not attach the whole private ZIP, game data, saves, NAND, identities or credentials. Exporting does not upload anything or select an attachment.")
                .setNegativeButton("Back", null)
                .setPositiveButton("Save Private ZIP…") { _, _ ->
                    launchDocument(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        type = "application/zip"
                        addCategory(Intent.CATEGORY_OPENABLE)
                        putExtra(Intent.EXTRA_TITLE, "KartPad-private-diagnostics.zip")
                    }, EXPORT_LOGS)
                }.show()
        }
        choices = RadioGroup(this).apply {
            orientation = RadioGroup.VERTICAL
            addView(RadioButton(this@KartPadProblemReportActivity).apply {
                id = WITH_LOGS
                text = "I will include reviewed logs"
            })
            addView(RadioButton(this@KartPadProblemReportActivity).apply {
                id = WITHOUT_LOGS
                text = "I cannot include logs"
            })
            column.addView(this)
        }
        val chooseFile = button("Choose Reviewed Log Text…") {
            launchDocument(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                type = "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("text/*", "application/json", "application/octet-stream"))
                addCategory(Intent.CATEGORY_OPENABLE)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }, CHOOSE_LOG)
        }
        selectedFile = label(if (attachment == null) "No log file selected." else "Selected: $attachmentName")
        reviewed = CheckBox(this).apply {
            text = "I reviewed this log file and want to share it. It contains no private game data, saves or credentials."
            isChecked = savedInstanceState?.getBoolean("reviewed") == true
            column.addView(this)
        }
        reason = field("Why logs are unavailable (for example, the app crashes before creating them)", "reason", 300, 2)
        fun refreshChoice() {
            val withLogs = choices.checkedRadioButtonId == WITH_LOGS
            chooseFile.visibility = if (withLogs) View.VISIBLE else View.GONE
            selectedFile.visibility = chooseFile.visibility
            reviewed.visibility = chooseFile.visibility
            reason.visibility = if (choices.checkedRadioButtonId == WITHOUT_LOGS) View.VISIBLE else View.GONE
        }
        choices.setOnCheckedChangeListener { _, _ -> refreshChoice() }
        choices.check(savedInstanceState?.getInt("choice", -1) ?: -1)
        refreshChoice()
        status = label(savedInstanceState?.getString("status").orEmpty()).apply {
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        button("Share Report…") { handoff(github = false) }
        button("Report on GitHub…") { handoff(github = true) }
        button("Back to Game") { finish() }
        setContentView(ScrollView(this).apply {
            addView(column)
            setOnApplyWindowInsetsListener { view, insets ->
                if (android.os.Build.VERSION.SDK_INT >= 30) {
                    val safe = insets.getInsets(WindowInsets.Type.systemBars() or
                        WindowInsets.Type.displayCutout() or WindowInsets.Type.ime())
                    view.setPadding(safe.left, safe.top, safe.right, safe.bottom)
                } else {
                    @Suppress("DEPRECATION")
                    view.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                        insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
                }
                insets
            }
        })
        export = lastNonConfigurationInstance as? LocalExport
        if (export == null && status.text.toString() == "Exporting private logs…") {
            status.text = "The app stopped during export. Check the destination for an incomplete ZIP, or export again. Your draft was restored."
        }
        export?.let { job ->
            status.text = job.status
            job.onUpdate = { status.text = it }
        }
    }

    private fun evidence() = KartPadReportEvidence(
        when (choices.checkedRadioButtonId) { WITH_LOGS -> "logs"; WITHOUT_LOGS -> "unavailable"; else -> "" },
        attachment != null, reviewed.isChecked, reason.text.toString(),
    )

    private fun handoff(github: Boolean) {
        val evidence = evidence()
        evidence.validationError()?.let { status.text = it; return }
        // SAF documents can be removed or changed while their editor is open.
        // Recheck the same gate for both share and browser handoffs.
        if (evidence.choice == "logs" && (attachment?.let(::logMetadata) == null || runCatching {
                contentResolver.openAssetFileDescriptor(attachment!!, "r")?.use { true } == true
            }.getOrDefault(false).not())) {
            reviewed.isChecked = false
            status.text = "The selected log is no longer readable or eligible. Choose it again; your draft is still here."
            return
        }
        if (github) {
            AlertDialog.Builder(this)
                .setTitle("GitHub report draft")
                .setMessage(if (evidence.choice == "logs")
                    "The browser cannot attach your selected file automatically. Attach that reviewed log file in the GitHub draft before submitting. Your answers stay here if you return."
                    else "Your report will explain why logs are unavailable. GitHub reports are public; review the draft before submitting.")
                .setNegativeButton("Back", null)
                .setPositiveButton("Open GitHub Draft") { _, _ -> openHandoff(githubIntent(evidence)) }
                .show()
        } else {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_SUBJECT, "KartPad Android problem $reportId")
                putExtra(Intent.EXTRA_TEXT, report(evidence.summary(false)))
                if (evidence.choice == "logs") {
                    putExtra(Intent.EXTRA_STREAM, attachment)
                    clipData = ClipData("Reviewed diagnostic log", arrayOf("text/plain"), ClipData.Item(attachment!!))
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
            }
            openHandoff(Intent.createChooser(send, "Share KartPad report"))
        }
    }

    private fun report(logEvidence: String) = buildString {
        appendLine("KartPad Android diagnostic report")
        appendLine("Report ID: $reportId")
        appendLine(intent.getStringExtra(TECHNICAL_CONTEXT).orEmpty())
        appendLine("\nWhat went wrong:\n${problem.text.toString().trim().ifBlank { "Not provided" }}")
        appendLine("\nArea and what you were doing:\n${area.text.toString().trim().ifBlank { "Not provided" }}")
        appendLine("\nFrequency:\n${frequency.text.toString().trim().ifBlank { "Not provided" }}")
        appendLine("\nLog evidence:\n$logEvidence")
    }

    private fun githubIntent(evidence: KartPadReportEvidence): Intent {
        val uri = Uri.parse("https://github.com/chrissotraidis/kartpad/issues/new").buildUpon()
            .appendQueryParameter("template", "bug_report.yml")
            .appendQueryParameter("title", "[Bug]: ${problem.text.toString().trim().ifBlank { "KartPad problem" }.take(100)}")
            .appendQueryParameter("report-id", reportId)
            .appendQueryParameter("revision", "${BuildConfig.VERSION_NAME} (build ${BuildConfig.VERSION_CODE})")
            .appendQueryParameter("platform", "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}; Android ${android.os.Build.VERSION.RELEASE} (API ${android.os.Build.VERSION.SDK_INT})")
            .appendQueryParameter("performance-profile", intent.getStringExtra(PERFORMANCE).orEmpty())
            .appendQueryParameter("summary", problem.text.toString().trim())
            .appendQueryParameter("context", "Runtime profile: ${intent.getStringExtra(PROFILE).orEmpty()}\n${area.text.toString().trim()}")
            .appendQueryParameter("frequency", frequency.text.toString().trim())
            .appendQueryParameter("diagnostics", evidence.summary(true))
            .build()
        return Intent(Intent.ACTION_VIEW, uri)
    }

    private fun openHandoff(action: Intent) {
        runCatching { startActivity(action) }.onFailure {
            status.text = "No app could open this action. Your draft is still here; try the other sharing option."
        }
    }

    private fun launchDocument(action: Intent, request: Int) {
        runCatching { startActivityForResult(action, request) }.onFailure {
            status.text = "The document picker could not open. Your draft is still here."
        }
    }

    private fun logMetadata(uri: Uri): Pair<String, Long>? = runCatching {
        if (uri.scheme != "content") return@runCatching null
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use {
            if (!it.moveToFirst() || it.isNull(1)) return@use null
            val name = it.getString(0).orEmpty().substringAfterLast('/').filterNot { char -> char.isISOControl() }.take(120)
            val size = it.getLong(1)
            if (name.substringAfterLast('.').lowercase() !in setOf("log", "txt", "json") || size !in 1..4L * 1024 * 1024) return@use null
            name to size
        }
    }.getOrNull()

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK) return
        val uri = data?.data?.takeIf { it.scheme == "content" } ?: return
        if (requestCode == CHOOSE_LOG) {
            val metadata = logMetadata(uri)
            if (metadata == null) {
                status.text = "Choose a .log, .txt or .json file up to 4 MiB with a known size. Do not attach the private ZIP."
                return
            }
            attachment = uri
            attachmentName = metadata.first
            reviewed.isChecked = false
            selectedFile.text = "Selected: $attachmentName. Review it before checking the confirmation below."
            status.text = ""
        } else if (requestCode == EXPORT_LOGS) {
            if (export?.running == true) {
                status.text = "An export is already running. Wait for it to finish."
                return
            }
            export = LocalExport(applicationContext, uri).also { job ->
                status.text = job.status
                job.onUpdate = { status.text = it }
                job.start()
            }
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString("report_id", reportId)
        outState.putString("attachment", attachment?.toString())
        outState.putString("attachment_name", attachmentName)
        outState.putString("problem", problem.text.toString())
        outState.putString("area", area.text.toString())
        outState.putString("frequency", frequency.text.toString())
        outState.putString("reason", reason.text.toString())
        outState.putString("status", status.text.toString())
        outState.putInt("choice", choices.checkedRadioButtonId)
        outState.putBoolean("reviewed", reviewed.isChecked)
        super.onSaveInstanceState(outState)
    }

    override fun onRetainNonConfigurationInstance(): Any? = export
    override fun onDestroy() { export?.onUpdate = null; super.onDestroy() }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private class LocalExport(val context: android.content.Context, val destination: Uri) {
        @Volatile var status = "Exporting private logs…"
        @Volatile var running = true
        var onUpdate: ((String) -> Unit)? = null
        fun start() {
            Thread {
                val success = runCatching { KartPadDiagnosticExport.write(context, destination) }.isSuccess
                status = if (success) "Private ZIP saved. Review locally, then choose a relevant log text file. Nothing was uploaded."
                    else "Export failed. The destination may contain an incomplete ZIP. Your report draft is still here."
                running = false
                Handler(Looper.getMainLooper()).post { onUpdate?.invoke(status) }
            }.start()
        }
    }

    companion object {
        const val TECHNICAL_CONTEXT = "technical_context"
        const val PERFORMANCE = "performance"
        const val PROFILE = "profile"
        private const val WITH_LOGS = 101
        private const val WITHOUT_LOGS = 102
        private const val CHOOSE_LOG = 4401
        private const val EXPORT_LOGS = 4402
    }
}
