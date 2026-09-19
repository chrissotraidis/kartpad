package dev.kartpad.android

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/** OS traces are included only in the explicitly requested private diagnostic ZIP. */
internal object KartPadExitTraces {
    private const val LIMIT = 1024 * 1024

    fun summary(context: Context): String = collect(context, null).toString(2)

    private fun collect(context: Context, zip: ZipOutputStream?): JSONObject {
        val manifest = JSONObject().put("schema", 1)
            .put("scope", "recent app exits; not necessarily the selected runtime session")
            .put("export_version_code", BuildConfig.VERSION_CODE)
        val entries = JSONArray()
        manifest.put("traces", entries)
        if (Build.VERSION.SDK_INT < 30) {
            manifest.put("availability", "requires_android_11")
        } else {
            runCatching {
                val manager = context.getSystemService(ActivityManager::class.java)
                    ?: error("unavailable")
                val exits = manager.getHistoricalProcessExitReasons(context.packageName, 0, 8)
                    .filter { it.reason == ApplicationExitInfo.REASON_ANR ||
                        (Build.VERSION.SDK_INT >= 31 && it.reason == ApplicationExitInfo.REASON_CRASH_NATIVE) }
                    .sortedByDescending { it.timestamp }.take(3)
                for ((index, exit) in exits.withIndex()) {
                    val native = exit.reason == ApplicationExitInfo.REASON_CRASH_NATIVE
                    val row = JSONObject().put("timestamp_ms", exit.timestamp).put("pid", exit.pid)
                        .put("reason", if (native) "native_crash" else "anr")
                    entries.put(row)
                    // Read and close before opening a ZIP entry; optional OS failure must not damage the archive.
                    val bytes = runCatching { exit.traceInputStream?.use { it.readBytesBounded(LIMIT) } }
                    if (bytes.isFailure) row.put("availability", "unavailable")
                    else if (bytes.getOrNull() == null) row.put("availability", "not_retained")
                    else {
                        val trace = requireNotNull(bytes.getOrNull())
                        if (trace.size > LIMIT) row.put("availability", "too_large")
                        else {
                            val name = "OS-exits/exit-$index-${exit.timestamp}." + if (native) "pb" else "txt"
                            if (native) row.put("native_summary", KartPadTombstoneSummary.summarize(trace))
                            row.put("availability", if (zip == null) "retained" else "included").put("bytes", trace.size)
                            if (zip != null) {
                                zip.putNextEntry(ZipEntry(name))
                                zip.write(trace)
                                zip.closeEntry()
                                row.put("file", name)
                            }
                        }
                    }
                }
                manifest.put("availability", "available")
            }.onFailure {
                if (it is java.io.IOException) throw it // An output failure must fail the export.
                manifest.put("availability", "unavailable")
            }
        }
        return manifest
    }

    fun write(context: Context, zip: ZipOutputStream) {
        val manifest = collect(context, zip)
        zip.putNextEntry(ZipEntry("OS-exits/manifest.json"))
        zip.write(manifest.toString(2).toByteArray())
        zip.closeEntry()
    }
}
