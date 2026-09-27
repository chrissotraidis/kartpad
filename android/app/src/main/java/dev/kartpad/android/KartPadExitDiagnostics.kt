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

    /**
     * The newest exit of the game process, when it ended unexpectedly: (timestamp, short reason).
     * Normal quits (exit status 0), swipes from Recents and background memory kills return null.
     */
    fun lastUnexpectedGameExit(context: Context): Pair<Long, String>? {
        if (Build.VERSION.SDK_INT < 30) return null
        return runCatching {
            val manager = context.getSystemService(ActivityManager::class.java) ?: return null
            val exit = manager.getHistoricalProcessExitReasons(context.packageName, 0, 8).firstOrNull { record ->
                val profile = record.processStateSummary?.takeIf { it.size <= 128 }
                    ?.toString(Charsets.US_ASCII)?.let { statePattern.matchEntire(it) }?.groupValues?.get(2)
                profile == "base" || profile == "retro_rewind"
            } ?: return null
            val foreground = exit.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
            val reason = when (exit.reason) {
                ApplicationExitInfo.REASON_CRASH, ApplicationExitInfo.REASON_CRASH_NATIVE -> "crash"
                ApplicationExitInfo.REASON_ANR -> "not responding"
                ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "failed to start"
                ApplicationExitInfo.REASON_EXIT_SELF -> "game error".takeIf { exit.status != 0 }
                ApplicationExitInfo.REASON_LOW_MEMORY -> "out of memory".takeIf { foreground }
                ApplicationExitInfo.REASON_SIGNALED, ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE ->
                    "closed by Android".takeIf { foreground }
                else -> null
            } ?: return null
            exit.timestamp to reason
        }.getOrNull()
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
