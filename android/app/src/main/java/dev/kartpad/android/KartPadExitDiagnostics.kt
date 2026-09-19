package dev.kartpad.android

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/** Bounded metadata for this app only. Never reads system traces or descriptions. */
internal object KartPadExitDiagnostics {
    private var lastState: String? = null
    private val statePattern = Regex("kp1:([1-9][0-9]{0,8}):(chooser|base|retro_rewind)")

    fun mark(context: Context, profile: String) {
        if (Build.VERSION.SDK_INT < 30) return
        val state = "kp1:${BuildConfig.VERSION_CODE}:$profile"
        if (!statePattern.matches(state) || state == lastState) return
        // OEMs may deny or throttle this optional diagnostic API. Never block play.
        runCatching {
            context.getSystemService(ActivityManager::class.java)
                ?.setProcessStateSummary(state.toByteArray(Charsets.US_ASCII))
            lastState = state
        }
    }

    fun snapshot(context: Context): String {
        val report = JSONObject().put("schema", 1)
            .put("export_version_code", BuildConfig.VERSION_CODE)
            .put("timestamp_basis", "unix_epoch_ms")
        if (Build.VERSION.SDK_INT < 30) {
            return report.put("availability", "requires_android_11").toString(2)
        }
        return try {
            val manager = context.getSystemService(ActivityManager::class.java)
                ?: return report.put("availability", "unavailable").toString(2)
            val entries = JSONArray()
            for (exit in manager.getHistoricalProcessExitReasons(context.packageName, 0, 8).take(8)) {
                val stateBytes = exit.processStateSummary
                val state = stateBytes?.takeIf { it.size <= 128 }
                    ?.toString(Charsets.US_ASCII)?.let { statePattern.matchEntire(it) }
                entries.put(JSONObject()
                    .put("timestamp_ms", exit.timestamp).put("pid", exit.pid)
                    .put("reason_code", exit.reason)
                    .put("reason", reasonName(exit.reason))
                    .put("status", exit.status)
                    .put("importance", exit.importance)
                    .put("pss_kib", exit.pss.takeIf { it > 0 } ?: JSONObject.NULL)
                    .put("rss_kib", exit.rss.takeIf { it > 0 } ?: JSONObject.NULL)
                    .put("version_code", state?.groupValues?.get(1)?.toIntOrNull() ?: JSONObject.NULL)
                    .put("last_profile", state?.groupValues?.get(2) ?: JSONObject.NULL))
            }
            report.put("availability", "available").put("exits", entries).toString(2)
        } catch (_: RuntimeException) {
            report.put("availability", "unavailable").toString(2)
        }
    }

    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_EXIT_SELF -> "self_exit"
        ApplicationExitInfo.REASON_SIGNALED -> "signal"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "low_memory"
        ApplicationExitInfo.REASON_CRASH -> "java_crash"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "native_crash"
        ApplicationExitInfo.REASON_ANR -> "not_responding"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "initialization_failure"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "permission_change"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "excessive_resource_usage"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "user_requested"
        ApplicationExitInfo.REASON_USER_STOPPED -> "user_stopped"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "dependency_died"
        ApplicationExitInfo.REASON_OTHER -> "other"
        else -> "unknown"
    }
}
