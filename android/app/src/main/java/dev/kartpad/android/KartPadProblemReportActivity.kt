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
import android.widget.Spinner
import android.widget.ArrayAdapter
import android.content.pm.PackageManager
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
    private lateinit var destination: RadioGroup
    private lateinit var upstreamKind: Spinner
    private var attachment: Uri? = null
    private var attachmentName = ""
    private var reportId = ""
    private var export: LocalExport? = null
    private var exportSession: String? = null
    private var logCheckGeneration = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        reportId = savedInstanceState?.getString("report_id")
            ?: "KP-${UUID.randomUUID().toString().take(8).uppercase()}"
        attachment = savedInstanceState?.getString("attachment")?.let(Uri::parse)
        attachmentName = savedInstanceState?.getString("attachment_name").orEmpty()
        exportSession = savedInstanceState?.getString("export_session")
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
        label("KartPad builds on WiiCompiled. Choose where to send your draft below.")
        label("").apply {
            text = android.text.Html.fromHtml("<a href='https://github.com/chrissotraidis/kartpad/blob/main/docs/REPORTING.md'>Reporting guide</a> · <a href='https://github.com/patchzyy/Wiicompiled'>About WiiCompiled</a>", android.text.Html.FROM_HTML_MODE_LEGACY)
            movementMethod = android.text.method.LinkMovementMethod.getInstance()
        }
        label("Send to")
        destination = RadioGroup(this).apply {
            orientation = RadioGroup.VERTICAL
            arrayOf("KartPad — this app, device-specific issues, or unsure", "WiiCompiled — the underlying game runtime").forEachIndexed { index, title ->
                addView(RadioButton(this@KartPadProblemReportActivity).apply {
                    id = 201 + index
                    text = title
                })
            }
            column.addView(this)
            check(201 + (savedInstanceState?.getInt("destination", 0) ?: 0))
        }
        button("Search reports in both projects") {
            val query = "is:issue repo:chrissotraidis/kartpad repo:patchzyy/Wiicompiled " + problem.text.toString().trim().take(160)
            openBrowser(Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/search").buildUpon()
                .appendQueryParameter("q", query).appendQueryParameter("type", "issues").build()))
        }
        upstreamKind = Spinner(this).apply {
            adapter = ArrayAdapter(this@KartPadProblemReportActivity, android.R.layout.simple_spinner_dropdown_item, KartPadUpstreamReport.kinds)
            column.addView(this)
            setSelection(savedInstanceState?.getInt("upstream_kind", 0) ?: 0)
        }
        val upstreamNote = label("This is a modified KartPad build. Only confirm upstream checks you have verified; if its form does not fit, report to KartPad.")
        fun updateDestination() {
            upstreamKind.visibility = if (destination.checkedRadioButtonId == 202) View.VISIBLE else View.GONE
            upstreamNote.visibility = upstreamKind.visibility
        }
        destination.setOnCheckedChangeListener { _, _ -> updateDestination() }
        updateDestination()
        problem = field("What went wrong?", "problem", 2000, 2)
        area = field("Area and what you were doing", "area", 1000)
        frequency = field("Every time, sometimes, once, or not sure?", "frequency", 160)
        label("GitHub opens a public draft in your browser. Attach reviewed logs or screenshots there; nothing is uploaded by KartPad.")
        status = label(savedInstanceState?.getString("status").orEmpty()).apply {
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
        }
        button("Open GitHub Draft") { handoff(github = true) }
        label("Optional: prepare logs or share a report file")
        button("Save Diagnostic Log…") {
            val sessions = runCatching { KartPadDiagnosticExport.sessions(this) }.getOrDefault(emptyList())
            if (sessions.isEmpty()) {
                exportSession = null
                launchDocument(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    type = "text/plain"
                    addCategory(Intent.CATEGORY_OPENABLE)
                    putExtra(Intent.EXTRA_TITLE, "KartPad-diagnostic-log.txt")
                }, EXPORT_LOGS)
            }
            else AlertDialog.Builder(this).setTitle("Which game session had the problem?")
                .setItems(sessions.map { "${it.id}\nLast written: ${java.util.Date(it.modified)}" }.toTypedArray()) { _, index ->
                    exportSession = sessions[index].id
                    launchDocument(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        type = "text/plain"
                        addCategory(Intent.CATEGORY_OPENABLE)
                        putExtra(Intent.EXTRA_TITLE, "KartPad-diagnostic-log.txt")
                    }, EXPORT_LOGS)
                }.setNegativeButton("Back", null).show()
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
        button("Review Selected Log") {
            attachment?.let { uri ->
                openHandoff(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "text/plain")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
            } ?: showLogError("Save a diagnostic log or choose a log first.")
        }
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
        choices.setOnCheckedChangeListener { _, _ -> logCheckGeneration++; refreshChoice() }
        choices.check(savedInstanceState?.getInt("choice", -1) ?: -1)
        refreshChoice()
        button("Share Report…") { handoff(github = false) }
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
        if (status.text.toString().startsWith("Checking the log file")) {
            status.text = "The file check was interrupted. Choose or share the log again; your draft was restored."
        }
        export = lastNonConfigurationInstance as? LocalExport
        if (export == null && status.text.toString() == "Saving diagnostic log…") {
            status.text = "The app stopped during export. Check the destination for an incomplete log file, or export again. Your draft was restored."
        }
        export?.let { job ->
            updateExport(job)
            job.onUpdate = { updateExport(job) }
        }
    }

    private fun evidence() = KartPadReportEvidence(
        when (choices.checkedRadioButtonId) { WITH_LOGS -> "logs"; WITHOUT_LOGS -> "unavailable"; else -> "" },
        attachment != null, reviewed.isChecked, reason.text.toString(),
    )

    private fun handoff(github: Boolean) {
        val evidence = evidence()
        if (github) {
            logCheckGeneration++
            status.text = "Opening your GitHub draft in a browser…"
            openBrowser(githubIntent(evidence))
            return
        }
        evidence.validationError()?.let { showLogError(it); return }
        if (evidence.choice == "logs") {
            val sharingUri = requireNotNull(attachment)
            checkLogAsync(sharingUri) { metadata ->
                if (metadata == null) {
                    reviewed.isChecked = false
                    showLogError("The selected log is no longer readable. Choose it again; your draft is still here.")
                } else if (attachment == sharingUri && reviewed.isChecked) shareReport(evidence, sharingUri)
            }
        } else shareReport(evidence)
    }

    private fun shareReport(evidence: KartPadReportEvidence, sharingUri: Uri? = null) {
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, "KartPad Android problem $reportId")
            putExtra(Intent.EXTRA_TEXT, report(evidence.summary(false)))
            if (evidence.choice == "logs") {
                putExtra(Intent.EXTRA_STREAM, sharingUri)
                clipData = ClipData("Reviewed diagnostic log", arrayOf("text/plain"), ClipData.Item(requireNotNull(sharingUri)))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }
        status.text = "Opening the share sheet…"
        openHandoff(Intent.createChooser(send, "Share KartPad report"))
    }

    private fun showLogError(message: String) {
        status.text = message
        android.widget.Toast.makeText(this, message, android.widget.Toast.LENGTH_LONG).show()
    }

    private fun checkLogAsync(uri: Uri, complete: (Pair<String, Long>?) -> Unit) {
        val generation = ++logCheckGeneration
        status.text = "Checking the log file… Your draft stays available."
        android.widget.Toast.makeText(this, "Checking the log file…", android.widget.Toast.LENGTH_SHORT).show()
        Thread {
            val metadata = runCatching {
                logMetadata(uri)?.takeIf {
                    contentResolver.openAssetFileDescriptor(uri, "r")?.use { true } == true
                }
            }.getOrNull()
            runOnUiThread {
                if (!isFinishing && !isDestroyed && generation == logCheckGeneration) complete(metadata)
            }
        }.start()
    }

    private fun report(logEvidence: String) = buildString {
        appendLine("KartPad Android diagnostic report")
        appendLine("Report ID: $reportId")
        appendLine(technicalSummary())
        appendLine("\nWhat went wrong:\n${problem.text.toString().trim().ifBlank { "Not provided" }}")
        appendLine("\nArea and what you were doing:\n${area.text.toString().trim().ifBlank { "Not provided" }}")
        appendLine("\nFrequency:\n${frequency.text.toString().trim().ifBlank { "Not provided" }}")
        appendLine("\nLog evidence:\n$logEvidence")
    }

    private fun technicalSummary() =
        KartPadReportMetadata.summary(intent.getStringExtra(TECHNICAL_CONTEXT) ?: buildString {
            appendLine("Version: ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
            appendLine("Android: ${android.os.Build.VERSION.RELEASE} (API ${android.os.Build.VERSION.SDK_INT})")
            appendLine("Device: ${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}")
            append("Runtime profile and upstream runtime version: unknown outside the game; see selected console.log header.")
        })

    private fun openBrowser(action: Intent) {
        // Resolve a generic web link to avoid the GitHub app dropping issue-form fields.
        val web = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com")).addCategory(Intent.CATEGORY_BROWSABLE)
        val browsers = packageManager.queryIntentActivities(web, PackageManager.MATCH_DEFAULT_ONLY)
            .map { it.activityInfo.packageName }.distinct()
        if (browsers.isEmpty()) {
            status.text = "No browser is available. Install or enable a web browser, then try again. Your draft is still here."
            return
        }
        val options = browsers.map { Intent(action).setPackage(it).addCategory(Intent.CATEGORY_BROWSABLE) }
        val preferred = packageManager.resolveActivity(web, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
        val direct = options.firstOrNull { it.`package` == preferred }
        openHandoff(direct ?: if (options.size == 1) options.first() else
            Intent.createChooser(options.first(), "Open report in browser").putExtra(Intent.EXTRA_INITIAL_INTENTS, options.drop(1).toTypedArray()))
    }

    private fun githubIntent(evidence: KartPadReportEvidence): Intent {
        if (destination.checkedRadioButtonId == 202) {
            val uri = Uri.parse("https://github.com/patchzyy/Wiicompiled/issues/new").buildUpon()
            KartPadUpstreamReport.fields(upstreamKind.selectedItemPosition, problem.text.toString().trim(), area.text.toString().trim(),
                frequency.text.toString().trim(), "Report ID: $reportId\n${technicalSummary()}", evidence.browserSummary())
                .forEach { (key, value) -> uri.appendQueryParameter(key, value) }
            return Intent(Intent.ACTION_VIEW, uri.build())
        }
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
            .appendQueryParameter("diagnostics", "${evidence.browserSummary()}\n\n${technicalSummary()}")
            .build()
        return Intent(Intent.ACTION_VIEW, uri)
    }

    private fun openHandoff(action: Intent) {
        runCatching { startActivity(action) }.onFailure {
            status.text = "No app could open this action. Your draft is still here; try the other sharing option."
        }
    }

    private fun launchDocument(action: Intent, request: Int) {
        logCheckGeneration++
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
            reviewed.isChecked = false
            checkLogAsync(uri) { metadata ->
                if (metadata == null) {
                    showLogError("Choose a readable .log, .txt or .json file up to 4 MiB with a known size. Do not attach the private ZIP.")
                } else {
                    attachment = uri
                    attachmentName = metadata.first
                    selectedFile.text = "Selected: $attachmentName. Review it before checking the confirmation below."
                    status.text = "Log selected. Review it before sharing."
                }
            }
        } else if (requestCode == EXPORT_LOGS) {
            if (export?.running == true) {
                status.text = "An export is already running. Wait for it to finish."
                return
            }
            val session = exportSession
            // A saved file may be overwritten at the same URI; any prior review is now stale.
            reviewed.isChecked = false
            if (attachment == uri) attachment = null
            export = LocalExport(applicationContext, uri, session).also { job ->
                status.text = job.status
                job.onUpdate = { updateExport(job) }
                job.start()
            }
        }
    }

    private fun updateExport(job: LocalExport) {
        status.text = job.status
        if (job.succeeded && attachment != job.destination) {
            attachment = job.destination
            attachmentName = "KartPad-diagnostic-log.txt"
            selectedFile.text = "Selected: $attachmentName"
            reviewed.isChecked = false
            choices.check(WITH_LOGS)
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString("report_id", reportId)
        outState.putInt("destination", if (destination.checkedRadioButtonId == 202) 1 else 0)
        outState.putInt("upstream_kind", upstreamKind.selectedItemPosition)
        outState.putString("export_session", exportSession)
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
    override fun onDestroy() { logCheckGeneration++; export?.onUpdate = null; super.onDestroy() }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()

    private class LocalExport(val context: android.content.Context, val destination: Uri, val session: String?) {
        @Volatile var status = "Saving diagnostic log…"
        @Volatile var running = true
        @Volatile var succeeded = false
        var onUpdate: ((String) -> Unit)? = null
        fun start() {
            Thread {
                val success = runCatching { KartPadDiagnosticExport.writeText(context, destination, session) }.isSuccess
                succeeded = success
                status = if (success) "Log saved and selected. Review it before sharing; attach the saved file on GitHub. Nothing was uploaded."
                    else "Export failed. The destination may contain an incomplete log file. Your report draft is still here."
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
