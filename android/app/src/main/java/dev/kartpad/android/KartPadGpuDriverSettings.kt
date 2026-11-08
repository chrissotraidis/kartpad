package dev.kartpad.android

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.system.Os
import android.widget.Toast
import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipFile
import java.util.zip.ZipInputStream
import org.json.JSONArray
import org.json.JSONObject

/**
 * Custom Vulkan drivers for Snapdragon phones (Turnip, or a newer Qualcomm driver), in the
 * AdrenoTools package format other Android emulators use: a .zip with meta.json and the driver .so.
 * Many Adreno rendering faults are driver bugs that only a different driver fixes.
 *
 * Adapted from DriftDroid's GpuDriverSettings.kt (github.com/dorPXP/driftdroid, GPL-3.0). KartPad
 * adds a start-failure fallback and refreshes the hook libraries when the app is updated.
 *
 * Packages are unpacked under files/KartPad/gpu_drivers/<name>/. The choice is passed to the
 * runtime through the environment at launch (runtime/src/android/gpu_driver.cpp), which loads it
 * before graphics start for either graphics engine. If a driver fails to load, the runtime uses
 * the phone's driver; if the game closes twice while starting with one, the next start goes back
 * to the phone's driver.
 */
internal object KartPadGpuDriverSettings {
    const val REQUEST_PICK_ZIP = 0x4b50
    private const val FAILED_STARTS_BEFORE_SYSTEM = 2
    private val hookLibraries =
        listOf("libmain_hook.so", "libhook_impl.so", "libfile_redirect_hook.so", "libgsl_alloc_hook.so")
    private val environment =
        listOf("KARTPAD_GPU_DRIVER_DIR", "KARTPAD_GPU_DRIVER_LIB", "KARTPAD_GPU_HOOK_DIR", "KARTPAD_GPU_TMP_DIR",
            "KARTPAD_GPU_DRIVER_STARTS", "KARTPAD_GPU_DRIVER_STATUS")

    /**
     * Where Download a Driver looks: GitHub releases of the AdrenoTools driver packages other
     * Android emulators use. Each asset is the same .zip that Install from a .zip File accepts.
     */
    private data class Source(val title: String, val description: String, val repository: String)
    private val sources = listOf(
        Source("Turnip and Qualcomm (K11MCH1)", "Turnip builds plus newer Qualcomm drivers", "K11MCH1/AdrenoToolsDrivers"),
        Source("Mainline and Stable Turnip (whitebelyash)", "Recent Mesa Turnip, including older Adreno 6xx", "whitebelyash/freedreno_turnip-CI"),
        Source("Turnip CI (Weab-chan)", "Automatic Mesa Turnip builds", "Weab-chan/freedreno_turnip-CI"),
    )
    private data class Download(val label: String, val url: String)

    /** True when this start went back to the phone's driver because the chosen one kept failing. */
    @Volatile
    var fellBackToSystem = false
        private set

    private data class Driver(val dir: File, val name: String, val library: String, val details: String)

    private fun preferences(context: Context) = context.getSharedPreferences("kartpad_gpu_driver", Context.MODE_PRIVATE)
    private fun driversDir(context: Context) = File(File(context.filesDir, "KartPad"), "gpu_drivers")
    private fun hooksDir(context: Context) = File(driversDir(context), "hooks")
    private fun startsFile(context: Context) = File(driversDir(context), "starts")
    private fun statusFile(context: Context) = File(driversDir(context), "last-status")

    private fun installed(context: Context): List<Driver> =
        driversDir(context)
            .listFiles { file -> file.isDirectory && File(file, "meta.json").isFile }
            .orEmpty()
            .mapNotNull(::readDriver)
            .sortedBy { it.name.lowercase() }

    private fun readDriver(dir: File): Driver? =
        runCatching {
            val meta = JSONObject(File(dir, "meta.json").readText())
            val library = meta.getString("libraryName")
            if (library.contains('/') || !File(dir, library).isFile) return null
            val details = listOf(meta.optString("driverVersion"), meta.optString("description"))
                .filter { it.isNotBlank() }
                .joinToString(" - ")
            Driver(dir, meta.optString("name").ifBlank { dir.name }, library, details)
        }.getOrNull()

    private fun selected(context: Context): Driver? =
        preferences(context).getString("driver", null)
            ?.let { folder -> installed(context).firstOrNull { it.dir.name == folder } }

    /** For problem reports: the chosen driver's name, or null for the phone's own driver. */
    fun selectedName(context: Context): String? = selected(context)?.let { "${it.name} (${it.library})" }

    /**
     * Why the chosen driver didn't load on the latest start, or null when it loaded (or none was
     * chosen). The runtime writes the status (runtime/src/android/gpu_driver.cpp); without this the
     * menu kept naming a driver that had silently fallen back to the phone's.
     */
    fun loadProblem(context: Context): String? {
        if (selected(context) == null) return null
        val lines = runCatching { statusFile(context).readLines() }.getOrNull() ?: return null
        if (lines.firstOrNull() == "loaded") return null
        val reason = lines.getOrNull(1).orEmpty()
        val detail = lines.getOrNull(2).orEmpty()
        return listOf(reason, detail).filter { it.isNotBlank() }.joinToString(": ").ifBlank { "unknown" }
    }

    /** The GPU Driver row in Graphics & Performance. */
    fun menuDetail(context: Context): String {
        val name = selected(context)?.name ?: return "Phone's driver"
        return if (loadProblem(context) != null) "Phone's driver ($name didn't load)" else name
    }

    /** For problem reports: what actually ran, not just what was chosen. */
    fun reportState(context: Context): String {
        val name = selectedName(context) ?: return "system"
        return loadProblem(context)?.let { "$name not loaded, used system: $it" } ?: name
    }

    /**
     * The runtime needs the hook libraries as real files; they ship inside the APK, which Android
     * leaves packed. Copy them out, again whenever the app is updated.
     */
    private fun refreshHookLibraries(context: Context) {
        val hooks = hooksDir(context)
        val stamp = File(hooks, "app-version")
        val version = "${BuildConfig.VERSION_CODE}:${File(context.applicationInfo.sourceDir).lastModified()}"
        if (stamp.isFile && stamp.readText() == version && hookLibraries.all { File(hooks, it).isFile }) return
        hooks.mkdirs()
        ZipFile(context.applicationInfo.sourceDir).use { apk ->
            for (name in hookLibraries) {
                val entry = apk.getEntry("lib/arm64-v8a/$name") ?: error("$name is missing from the app")
                val part = File(hooks, "$name.part")
                apk.getInputStream(entry).use { input -> part.outputStream().use { input.copyTo(it) } }
                if (!part.renameTo(File(hooks, name))) error("Could not store $name")
            }
        }
        stamp.writeText(version)
    }

    /** Before the native runtime starts: pass the chosen driver, or nothing for the phone's own. */
    fun configureLaunch(context: Context) {
        environment.forEach { Os.unsetenv(it) }
        val driver = selected(context) ?: return
        val starts = startsFile(context)
        val failed = runCatching { starts.readText().trim().toInt() }.getOrDefault(0)
        if (failed >= FAILED_STARTS_BEFORE_SYSTEM) {
            preferences(context).edit().remove("driver").commit()
            starts.delete()
            fellBackToSystem = true
            return
        }
        runCatching {
            refreshHookLibraries(context)
            val tmp = File(context.codeCacheDir, "gpu_driver").apply { mkdirs() }
            Os.setenv("KARTPAD_GPU_DRIVER_DIR", driver.dir.absolutePath + "/", true)
            Os.setenv("KARTPAD_GPU_DRIVER_LIB", driver.library, true)
            Os.setenv("KARTPAD_GPU_HOOK_DIR", hooksDir(context).absolutePath + "/", true)
            Os.setenv("KARTPAD_GPU_TMP_DIR", tmp.absolutePath + "/", true)
            // The runtime marks this file failed if graphics can't start with the driver.
            Os.setenv("KARTPAD_GPU_DRIVER_STARTS", starts.absolutePath, true)
            // Written by the runtime when it loads the driver or falls back to the phone's.
            statusFile(context).delete()
            Os.setenv("KARTPAD_GPU_DRIVER_STATUS", statusFile(context).absolutePath, true)
            // Counted now, cleared by markStarted once the game has run for a minute.
            starts.writeText((failed + 1).toString())
        }.onFailure { environment.forEach { name -> Os.unsetenv(name) } }
    }

    /** The game ran for a while: this start with the chosen driver did not fail. */
    fun markStarted(context: Context) {
        startsFile(context).delete()
    }

    private fun select(context: Context, driver: Driver?): Boolean =
        runCatching {
            if (driver != null) refreshHookLibraries(context)
            startsFile(context).delete()
            statusFile(context).delete()
            val edit = preferences(context).edit()
            if (driver == null) edit.remove("driver") else edit.putString("driver", driver.dir.name)
            check(edit.commit())
            // Dawn's saved Vulkan pipeline data belongs to the previous driver. Drivers should
            // reject another driver's data, but old Adreno drivers are the ones this is for.
            // The engine's own list of shaders (pipeline_cache.db) is driver-independent and stays.
            val cache = File(context.cacheDir, "KartPad")
            for (base in listOf("dawn_cache.db", "dawn_cache_wiicompiled.db")) {
                for (suffix in listOf("", "-wal", "-shm")) File(cache, base + suffix).delete()
            }
        }.isSuccess

    fun show(activity: Activity, onChanged: () -> Unit) {
        val drivers = installed(activity)
        val current = selected(activity)
        val problem = loadProblem(activity)
        var choice = drivers.indexOfFirst { it.dir == current?.dir } + 1
        val labels = (listOf("Phone's Driver (Default)") +
            drivers.map { driver ->
                listOfNotNull(
                    driver.name,
                    driver.details.ifBlank { null },
                    if (driver.dir == current?.dir && problem != null) "Didn't load last start ($problem)" else null,
                ).joinToString("\n")
            }).toTypedArray()
        AlertDialog.Builder(activity)
            .setTitle("GPU Driver (Snapdragon)")
            .setSingleChoiceItems(labels, choice) { _, which -> choice = which }
            .setNeutralButton("Add Driver…") { _, _ -> showAddDriver(activity, onChanged) }
            .setNegativeButton("Back", null)
            .setPositiveButton("Save") { _, _ ->
                val driver = drivers.getOrNull(choice - 1)
                if (driver?.dir == current?.dir) return@setPositiveButton
                if (!select(activity, driver)) {
                    Toast.makeText(activity, "The driver choice could not be saved.", Toast.LENGTH_LONG).show()
                    return@setPositiveButton
                }
                onChanged()
            }
            .show()
    }

    private fun showAddDriver(activity: Activity, onChanged: () -> Unit) {
        AlertDialog.Builder(activity)
            .setTitle("Add a GPU Driver")
            .setItems(arrayOf("Download a Driver…", "Install from a .zip File…")) { _, which ->
                if (which == 0) showSources(activity, onChanged) else pickZip(activity)
            }
            .setNegativeButton("Back") { _, _ -> show(activity, onChanged) }
            .show()
    }

    private fun showSources(activity: Activity, onChanged: () -> Unit) {
        val labels = sources.map { "${it.title}\n${it.description}" }.toTypedArray()
        AlertDialog.Builder(activity)
            .setTitle("Download a Driver")
            .setItems(labels) { _, which -> listDownloads(activity, sources[which], onChanged) }
            .setNegativeButton("Back") { _, _ -> showAddDriver(activity, onChanged) }
            .show()
    }

    private fun listDownloads(activity: Activity, source: Source, onChanged: () -> Unit) {
        val waiting = AlertDialog.Builder(activity).setTitle(source.title)
            .setMessage("Looking for drivers…").setCancelable(false).show()
        Thread {
            val result = runCatching { fetchDownloads(source) }
            activity.runOnUiThread {
                waiting.dismiss()
                if (activity.isFinishing) return@runOnUiThread
                val downloads = result.getOrNull()
                if (downloads.isNullOrEmpty()) {
                    AlertDialog.Builder(activity).setTitle("No Drivers Found")
                        .setMessage("KartPad couldn't list drivers from ${source.repository}. Check the connection, " +
                            "or download a driver .zip in a browser and use Install from a .zip File.")
                        .setPositiveButton("OK") { _, _ -> showSources(activity, onChanged) }.show()
                    return@runOnUiThread
                }
                AlertDialog.Builder(activity)
                    .setTitle(source.title)
                    .setItems(downloads.map { it.label }.toTypedArray()) { _, which ->
                        download(activity, downloads[which], onChanged)
                    }
                    .setNegativeButton("Back") { _, _ -> showSources(activity, onChanged) }
                    .show()
            }
        }.start()
    }

    /** The newest releases' .zip assets, newest first. */
    private fun fetchDownloads(source: Source): List<Download> {
        val releases = JSONArray(httpGet("https://api.github.com/repos/${source.repository}/releases?per_page=8")
            .bufferedReader().use { it.readText() })
        val downloads = mutableListOf<Download>()
        for (i in 0 until releases.length()) {
            val release = releases.getJSONObject(i)
            if (release.optBoolean("draft")) continue
            val title = release.optString("name").ifBlank { release.optString("tag_name") }
            val date = release.optString("published_at").take(10)
            val assets = release.optJSONArray("assets") ?: continue
            for (j in 0 until assets.length()) {
                val asset = assets.getJSONObject(j)
                val name = asset.optString("name")
                val url = asset.optString("browser_download_url")
                if (!name.endsWith(".zip", ignoreCase = true) || !url.startsWith("https://")) continue
                if (asset.optLong("size") > MAX_PACKAGE_BYTES) continue
                downloads += Download("$name\n$title · $date", url)
            }
        }
        return downloads.take(24)
    }

    private fun download(activity: Activity, item: Download, onChanged: () -> Unit) {
        val waiting = AlertDialog.Builder(activity).setTitle("Downloading Driver")
            .setMessage(item.label.substringBefore('\n')).setCancelable(false).show()
        Thread {
            val error = runCatching { httpGet(item.url).use { install(activity, it) } }
                .exceptionOrNull()?.let { it.message ?: it.toString() }
            activity.runOnUiThread {
                waiting.dismiss()
                if (activity.isFinishing) return@runOnUiThread
                if (error != null) {
                    AlertDialog.Builder(activity).setTitle("Driver Not Installed").setMessage(error)
                        .setPositiveButton("OK", null).show()
                } else {
                    show(activity, onChanged)
                }
            }
        }.start()
    }

    private fun httpGet(url: String): InputStream {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 30_000
        connection.setRequestProperty("Accept", "application/vnd.github+json, application/octet-stream")
        connection.setRequestProperty("User-Agent", "KartPad/${BuildConfig.VERSION_NAME}")
        if (connection.responseCode !in 200..299) {
            val code = connection.responseCode
            connection.disconnect()
            error("The download failed (HTTP $code).")
        }
        return connection.inputStream
    }

    private fun pickZip(activity: Activity) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            // Packages are often named *.adpkg.zip and reported with assorted MIME types.
            .setType("*/*")
        activity.startActivityForResult(intent, REQUEST_PICK_ZIP)
    }

    /** From the activity's onActivityResult for [REQUEST_PICK_ZIP]. */
    fun onZipPicked(activity: Activity, uri: Uri?, onChanged: () -> Unit) {
        if (uri == null) return
        Thread {
            val error = runCatching {
                val input = activity.contentResolver.openInputStream(uri) ?: error("Could not open that file.")
                input.use { install(activity, it) }
            }.exceptionOrNull()?.let { it.message ?: it.toString() }
            activity.runOnUiThread {
                if (activity.isFinishing) return@runOnUiThread
                if (error != null) {
                    AlertDialog.Builder(activity)
                        .setTitle("Driver Not Installed")
                        .setMessage(error)
                        .setPositiveButton("OK", null)
                        .show()
                } else {
                    show(activity, onChanged)
                }
            }
        }.start()
    }

    private const val MAX_PACKAGE_BYTES = 512L * 1024 * 1024

    private fun install(context: Context, input: InputStream) {
        val staging = File(driversDir(context), ".staging")
        staging.deleteRecursively()
        staging.mkdirs()
        try {
            ZipInputStream(input).use { zip ->
                var total = 0L
                while (true) {
                    val entry = zip.nextEntry ?: break
                    // Packages are flat; keeping only the file name also rules out path tricks.
                    val name = File(entry.name).name
                    if (entry.isDirectory || name.isEmpty() || name.startsWith(".")) continue
                    File(staging, name).outputStream().use { output ->
                        val buffer = ByteArray(1 shl 16)
                        while (true) {
                            val read = zip.read(buffer)
                            if (read < 0) break
                            total += read
                            if (total > MAX_PACKAGE_BYTES) error("That file is too large to be a driver package.")
                            output.write(buffer, 0, read)
                        }
                    }
                }
            }
            val metaFile = File(staging, "meta.json")
            if (!metaFile.isFile) error("That is not a driver package (there is no meta.json inside the zip).")
            val meta = runCatching { JSONObject(metaFile.readText()) }.getOrElse { error("The package's meta.json could not be read.") }
            val library = meta.optString("libraryName")
            if (library.isBlank() || library.contains('/') || !File(staging, library).isFile) {
                error("The driver package is incomplete: its driver file is missing.")
            }
            if (meta.optInt("minApi", 0) > Build.VERSION.SDK_INT) {
                error("This driver needs a newer Android version than this phone has.")
            }
            val name = meta.optString("name").ifBlank { "driver" }
            val folder = name.replace(Regex("[^A-Za-z0-9._-]+"), "_").trim('_', '.').ifBlank { "driver" }
            if (folder == "hooks") error("That package name is reserved; rename the package and try again.")
            val target = File(driversDir(context), folder)
            target.deleteRecursively()
            if (!staging.renameTo(target)) error("Could not store the driver.")
        } finally {
            staging.deleteRecursively()
        }
    }
}
