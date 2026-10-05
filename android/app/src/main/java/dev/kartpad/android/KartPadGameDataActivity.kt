package dev.kartpad.android

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import android.widget.TextView
import java.util.concurrent.Executors

/** Storage Access Framework owner for import/reimport and save-preserving removal. */
class KartPadGameDataActivity : Activity() {
    private lateinit var status: TextView
    private lateinit var importButton: Button
    private lateinit var importFolderButton: Button
    private lateinit var importZipButton: Button
    private lateinit var removeButton: Button
    private lateinit var progress: ProgressBar
    private val worker = Executors.newSingleThreadExecutor()
    private var changed = false
    private var automaticActionConsumed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        changed = savedInstanceState?.getBoolean(STATE_CHANGED) ?: false
        automaticActionConsumed = savedInstanceState?.getBoolean(STATE_ACTION_CONSUMED) ?: false
        if (changed) setResult(RESULT_OK)
        setContentView(buildContent())
        importButton.setOnClickListener { chooseDiscImage() }
        importFolderButton.setOnClickListener { chooseExtractedFolder() }
        importZipButton.setOnClickListener { chooseZip() }
        removeButton.setOnClickListener { confirmRemoval() }
        refreshStatus()
        val action = intent.getStringExtra(EXTRA_ACTION)
        if (!automaticActionConsumed && action != null) {
            automaticActionConsumed = true
            status.post {
                when (action) {
                    ACTION_IMPORT -> chooseDiscImage()
                    ACTION_IMPORT_FOLDER -> chooseExtractedFolder()
                    ACTION_REMOVE -> confirmRemoval()
                }
            }
        }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean(STATE_CHANGED, changed)
        outState.putBoolean(STATE_ACTION_CONSUMED, automaticActionConsumed)
        super.onSaveInstanceState(outState)
    }

    private fun chooseExtractedFolder() {
        startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                )
            },
            REQUEST_EXTRACTED_FOLDER,
        )
    }

    private fun chooseDiscImage() {
        if (!BuildConfig.DISC_IMAGE_IMPORT) {
            status.text = "Disc-image import is unavailable in this build."
            return
        }
        if (!KartPadCommonKey.isInstalled(filesDir)) {
            AlertDialog.Builder(this)
                .setTitle("Disc Images Need Your Wii's Key")
                .setMessage(
                    "To read a disc image, KartPad needs the 16-byte common key from your own Wii, saved as " +
                        "common-key.bin (for example from a BootMii NAND backup). Most people don't have it, and " +
                        "KartPad can't provide it.\n\n" +
                        "Easier: in Dolphin on a computer, right-click Mario Kart Wii, choose Properties, then " +
                        "Filesystem, right-click the disc and choose Extract Entire Disc. Copy that folder (or a zip " +
                        "of it) to this phone and import it here. No key needed.",
                )
                .setPositiveButton("Use Extracted Folder…") { _, _ -> chooseExtractedFolder() }
                .setNeutralButton("Choose common-key.bin…") { _, _ -> chooseCommonKey() }
                .setNegativeButton("Cancel", null)
                .show()
            return
        }
        startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
            REQUEST_DISC_IMAGE,
        )
    }

    private fun chooseZip() {
        startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf("application/zip", "application/x-zip-compressed", "application/octet-stream"),
                )
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
            REQUEST_ZIP,
        )
    }

    private fun chooseCommonKey() {
        startActivityForResult(
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
            REQUEST_COMMON_KEY,
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK) return
        val selected = data?.data ?: return
        if (requestCode == REQUEST_COMMON_KEY) {
            runCatching { KartPadCommonKey.install(contentResolver, selected, filesDir) }
                .onSuccess { chooseDiscImage() }
                .onFailure { error -> showImportFailure(error) }
            return
        }
        if (requestCode == REQUEST_DISC_IMAGE) {
            importDiscImage(selected)
            return
        }
        if (requestCode == REQUEST_ZIP) {
            importZip(selected)
            return
        }
        if (requestCode != REQUEST_EXTRACTED_FOLDER) return
        val tree = selected
        runCatching {
            contentResolver.takePersistableUriPermission(tree, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        setWorking(true, "Checking the selected folder…")
        worker.execute {
            runCatching {
                KartPadGameDataStorage.importExtractedTree(contentResolver, tree, filesDir) { message ->
                    runOnUiThread { status.text = message }
                }
            }.onSuccess { result ->
                runOnUiThread {
                    changed = true
                    setResult(RESULT_OK)
                    setWorking(false, "Game data is installed and checked (${result.files} items).")
                    AlertDialog.Builder(this)
                        .setTitle("Game Data Imported")
                        .setMessage("Restart KartPad to use the new copy. Saves, Miis, control settings, and Retro Rewind are unchanged.")
                        .setPositiveButton("Done") { _, _ -> finishWithResult() }
                        .setNegativeButton("Keep Managing", null)
                        .show()
                }
            }.onFailure { error ->
                runOnUiThread {
                    setWorking(false, safeError(error, "The selected folder could not be imported."))
                    AlertDialog.Builder(this)
                        .setTitle("Game Data Import Failed")
                        .setMessage(safeError(error, "The selected folder could not be imported."))
                        .setNegativeButton("Back", null)
                        .show()
                }
            }
        }
    }

    private fun importDiscImage(image: android.net.Uri) {
        setWorking(true, "Opening the selected Wii disc image…")
        worker.execute {
            runCatching {
                KartPadGameDataStorage.importDiscImage(contentResolver, image, filesDir) { message ->
                    runOnUiThread { status.text = message }
                }
            }.onSuccess { result ->
                runOnUiThread { showImportSuccess(result) }
            }.onFailure { error ->
                runOnUiThread { showImportFailure(error) }
            }
        }
    }

    private fun importZip(zip: android.net.Uri) {
        setWorking(true, "Opening the zip…")
        worker.execute {
            runCatching {
                KartPadGameDataStorage.importZip(contentResolver, zip, filesDir) { message ->
                    runOnUiThread { status.text = message }
                }
            }.onSuccess { result ->
                runOnUiThread { showImportSuccess(result) }
            }.onFailure { error ->
                runOnUiThread { showImportFailure(error) }
            }
        }
    }

    private fun showImportSuccess(result: KartPadGameDataStorage.ImportResult) {
        changed = true
        setResult(RESULT_OK)
        setWorking(false, "Game data is installed and checked (${result.files} items).")
        AlertDialog.Builder(this)
            .setTitle("Game Data Imported")
            .setMessage("Restart KartPad to use the new copy. Saves, Miis, control settings, and Retro Rewind are unchanged.")
            .setPositiveButton("Done") { _, _ -> finishWithResult() }
            .setNegativeButton("Keep Managing", null)
            .show()
    }

    private fun showImportFailure(error: Throwable) {
        android.util.Log.e("KartPadDiscImport", "Disc-image import failed", error)
        setWorking(false, safeError(error, "The selected game data could not be imported."))
        AlertDialog.Builder(this)
            .setTitle("Game Data Import Failed")
            .setMessage(safeError(error, "The selected game data could not be imported."))
            .setNegativeButton("Back", null)
            .show()
    }

    private fun confirmRemoval() {
        AlertDialog.Builder(this)
            .setTitle("Remove Stored Game Data?")
            .setMessage("The private extracted game files will be removed before the next game starts. Saves, Miis, Retro Rewind, and control settings are not affected.")
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Remove") { _, _ ->
                runCatching { KartPadGameDataStorage.scheduleRemoval(filesDir) }
                    .onSuccess {
                        changed = true
                        setResult(RESULT_OK)
                        refreshStatus()
                        AlertDialog.Builder(this)
                            .setTitle("Game Data Removal Scheduled")
                            .setMessage("Restart KartPad to remove the private game-data copy safely.")
                            .setNeutralButton("Undo") { _, _ ->
                                KartPadGameDataStorage.cancelRemoval(filesDir)
                                changed = false
                                setResult(RESULT_CANCELED)
                                refreshStatus()
                            }
                            .setPositiveButton("Done") { _, _ -> finishWithResult() }
                            .show()
                    }
                    .onFailure { error ->
                        AlertDialog.Builder(this)
                            .setTitle("Game Data Removal Failed")
                            .setMessage(safeError(error, "The removal could not be scheduled."))
                            .setNegativeButton("Back", null)
                            .show()
                    }
            }
            .show()
    }

    private fun refreshStatus() {
        val pending = KartPadGameDataStorage.removalScheduled(filesDir)
        val error = KartPadGameDataStorage.validationError(filesDir)
        status.text = when {
            pending -> "Removal is scheduled for the next game restart."
            error == null -> "Game data is installed and checked."
            else -> "No game data yet. Import the folder Dolphin made, or a zip of it."
        }
        removeButton.isEnabled = error == null && !pending
    }

    private fun setWorking(working: Boolean, message: String) {
        progress.visibility = if (working) View.VISIBLE else View.GONE
        importButton.isEnabled = !working && BuildConfig.DISC_IMAGE_IMPORT
        importFolderButton.isEnabled = !working
        importZipButton.isEnabled = !working
        removeButton.isEnabled = !working && KartPadGameDataStorage.validationError(filesDir) == null
        status.text = message
    }

    private fun finishWithResult() {
        setResult(if (changed) RESULT_OK else RESULT_CANCELED)
        finish()
    }

    private fun buildContent(): View {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density + 0.5f).toInt()
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(28), dp(18), dp(28), dp(18))
            setBackgroundColor(Color.rgb(24, 12, 22))
        }
        column.addView(TextView(this).apply {
            text = "Game Data & Saves"
            textSize = 27f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        })
        column.addView(TextView(this).apply {
            text = "Import your own Mario Kart Wii (PAL, RMCP01) once. Easiest: the folder Dolphin's " +
                "Extract Entire Disc makes (DATA, or the folder that holds it), or a zip of that folder. " +
                "Your saves are kept."
            textSize = 14f
            setTextColor(Color.LTGRAY)
            gravity = Gravity.CENTER
            setPadding(0, dp(5), 0, dp(10))
        })
        status = TextView(this).apply {
            textSize = 16f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
            setPadding(0, dp(6), 0, dp(8))
        }
        column.addView(status)
        progress = ProgressBar(this).apply { visibility = View.GONE }
        column.addView(progress)
        importFolderButton = Button(this).apply {
            text = "Import from Extracted Game Data Folder…"
            contentDescription = "Recommended: choose the game data folder Dolphin extracted"
        }
        column.addView(importFolderButton)
        importZipButton = Button(this).apply {
            text = "Import Game Data Zip…"
            contentDescription = "Choose a zip of the game data folder"
        }
        column.addView(importZipButton)
        importButton = Button(this).apply {
            text = "Import or Reimport Wii Disc Image…"
            contentDescription = "Choose a disc image; needs your own Wii common key"
            isEnabled = BuildConfig.DISC_IMAGE_IMPORT
        }
        column.addView(importButton)
        column.addView(TextView(this).apply {
            text = "Disc images (ISO, WBFS, RVZ) need your own Wii's common key."
            textSize = 13f
            setTextColor(Color.LTGRAY)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(8))
        })
        removeButton = Button(this).apply {
            text = "Remove Stored Game Data…"
            contentDescription = "Remove stored game data without removing saves"
        }
        column.addView(removeButton)
        column.addView(Button(this).apply {
            text = "Done"
            setOnClickListener { finishWithResult() }
        })
        return ScrollView(this).apply {
            isFillViewport = true
            addView(column)
        }
    }

    private fun safeError(error: Throwable, fallback: String): String {
        var cause = error
        while (cause.cause != null && cause.cause !== cause) cause = cause.cause!!
        return when {
            cause is android.system.ErrnoException && cause.errno == android.system.OsConstants.ENOSPC ->
                "Not enough free storage to finish importing game data. Free some space and try again. Existing game data and saves are unchanged."
            cause is IllegalArgumentException && !cause.message.isNullOrBlank() -> cause.message!!
            cause is UnsatisfiedLinkError -> "Disc-image support could not start in this build."
            else -> fallback
        }
    }

    companion object {
        const val EXTRA_ACTION = "dev.kartpad.android.GAME_DATA_ACTION"
        const val ACTION_IMPORT = "import"
        const val ACTION_IMPORT_FOLDER = "import-folder"
        const val ACTION_REMOVE = "remove"
        private const val REQUEST_EXTRACTED_FOLDER = 4_401
        private const val REQUEST_DISC_IMAGE = 4_402
        private const val REQUEST_COMMON_KEY = 4_403
        private const val REQUEST_ZIP = 4_404
        private const val STATE_CHANGED = "changed"
        private const val STATE_ACTION_CONSUMED = "automatic_action_consumed"
    }
}
