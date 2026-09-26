package dev.kartpad.android

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit
import org.json.JSONObject

/** Local-only health context for the existing explicit diagnostic export. */
internal object KartPadRuntimeHealth {
    private val worker = Executors.newSingleThreadScheduledExecutor { task ->
        Thread(task, "KartPadHealth").apply { isDaemon = true }
    }
    private var sample: ScheduledFuture<*>? = null
    private var networkSample: ScheduledFuture<*>? = null
    private external fun nativeSampleNetworkWaits()
    // Accessed only on the worker, including across brief activity pauses.
    private var lastHeadroomMs = -10_000L

    fun start(context: Context, profile: String) {
        stop()
        var waitSamplingAvailable = true // Worker-owned; report a missing hook only once per start.
        if (BuildConfig.GAME_RUNTIME) networkSample = worker.scheduleWithFixedDelay({
            if (waitSamplingAvailable) runCatching { nativeSampleNetworkWaits() }
                .onFailure {
                    waitSamplingAvailable = false
                    Log.w("KartPadHealth", "Network wait sample unavailable")
                }
        }, 1, 1, TimeUnit.SECONDS)
        val app = context.applicationContext
        val safeProfile = if (profile == "retro_rewind") "retro_rewind" else "base"
        sample = worker.scheduleWithFixedDelay({
            runCatching { record(app, safeProfile) }
                .onFailure { Log.w("KartPadHealth", "Health sample unavailable") }
        }, 0, 10, TimeUnit.SECONDS)
    }

    fun stop() {
        networkSample?.cancel(false)
        networkSample = null
        sample?.cancel(false)
        sample = null
    }

    private fun record(context: Context, profile: String) {
        val elapsed = SystemClock.elapsedRealtime()
        val power = context.getSystemService(PowerManager::class.java)
        val battery = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val headroom = if (Build.VERSION.SDK_INT >= 30 && elapsed - lastHeadroomMs >= 10_000) {
            lastHeadroomMs = elapsed
            runCatching { power.getThermalHeadroom(0) }.getOrNull()?.takeIf { it.isFinite() }
        } else null
        val temp = battery?.takeIf { it.hasExtra(BatteryManager.EXTRA_TEMPERATURE) }
            ?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0)?.div(10.0)
        val memory = runCatching {
            ActivityManager.MemoryInfo().also {
                context.getSystemService(ActivityManager::class.java)?.getMemoryInfo(it)
            }
        }.getOrNull()?.takeIf { it.totalMem > 0 }
        val line = JSONObject()
            .put("schema", 2)
            .put("pid", android.os.Process.myPid())
            .put("unix_ms", System.currentTimeMillis())
            .put("pss_kib", runCatching { android.os.Debug.getPss() }.getOrNull() ?: JSONObject.NULL)
            .put("physical_footprint_bytes", JSONObject.NULL)
            .put("device_ram_mib", memory?.totalMem?.div(1_048_576) ?: JSONObject.NULL)
            .put("available_ram_mib", memory?.availMem?.div(1_048_576) ?: JSONObject.NULL)
            .put("system_low_memory", memory?.lowMemory ?: JSONObject.NULL)
            .put("network", networkKind(context))
            .put("elapsed_ms", elapsed)
            .put("version_code", BuildConfig.VERSION_CODE)
            .put("api", Build.VERSION.SDK_INT)
            .put("profile", profile)
            .put("renderer_validation", KartPadRendererDiagnostics.active)
            .put("thermal_scale", "android_power_manager")
            .put("thermal_status", if (Build.VERSION.SDK_INT >= 29) power.currentThermalStatus else JSONObject.NULL)
            .put("thermal_headroom", headroom ?: JSONObject.NULL)
            .put("battery_c", temp ?: JSONObject.NULL)
            .put("plugged", battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: JSONObject.NULL)
            .put("power_save", power.isPowerSaveMode)
            .put("resolution_scale", KartPadTouchSettings.resolutionScale(context))
            .put("aspect_mode", KartPadTouchSettings.aspectMode(context))
            .toString()
        KartPadHealthJournal(File(context.filesDir, "KartPad/Logs/android-health.log")).append(line)
    }

    /** Transport class only (wifi, cellular, vpn, ...); never addresses, SSIDs or carriers. */
    private fun networkKind(context: Context): String = runCatching {
        val manager = context.getSystemService(ConnectivityManager::class.java)
            ?: return@runCatching "unknown"
        val caps = manager.getNetworkCapabilities(manager.activeNetwork) ?: return@runCatching "none"
        val kinds = listOf(
            NetworkCapabilities.TRANSPORT_VPN to "vpn",
            NetworkCapabilities.TRANSPORT_WIFI to "wifi",
            NetworkCapabilities.TRANSPORT_CELLULAR to "cellular",
            NetworkCapabilities.TRANSPORT_ETHERNET to "ethernet",
        ).filter { caps.hasTransport(it.first) }.map { it.second }
        kinds.joinToString("+").ifEmpty { "other" }
    }.getOrDefault("unknown")
}
