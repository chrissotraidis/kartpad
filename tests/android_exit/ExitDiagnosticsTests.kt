package dev.kartpad.android
import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import org.json.JSONObject

object BuildConfig { const val VERSION_CODE = 23; const val VERSION_NAME = "host-test" }

fun main() {
    testPrivateExitTraces()
    testDiagnosticExport()
    val manager = ActivityManager()
    val context = Context(manager)
    Build.VERSION.SDK_INT = 28
    KartPadExitDiagnostics.mark(context, "base")
    check(manager.marked == null)
    check(JSONObject(KartPadExitDiagnostics.snapshot(context)).getString("availability") == "requires_android_11")
    check(manager.calls == 0)
    Build.VERSION.SDK_INT = 30
    KartPadExitDiagnostics.mark(context, "base")
    check(manager.marked!!.decodeToString() == "kp1:23:base")
    KartPadExitDiagnostics.mark(context, "private-file-path")
    check(manager.marked!!.decodeToString() == "kp1:23:base")
    manager.exits = listOf(
        ApplicationExitInfo(5, "kp1:22:retro_rewind".toByteArray(), pss=2048, rss=4096, status=11),
        ApplicationExitInfo(3),
        ApplicationExitInfo(6, "kp1:23:base:private-data".toByteArray()),
        ApplicationExitInfo(10, "kp1:23:chooser".toByteArray()),
        ApplicationExitInfo(999, ByteArray(129) { 65 })
    ) + List(10) { ApplicationExitInfo(1) }
    val report = JSONObject(KartPadExitDiagnostics.snapshot(context))
    val exits = report.getJSONArray("exits")
    check(exits.length() == 8)
    val first = exits.getJSONObject(0)
    check(first.getInt("pid") == 42)
    check(first.getString("reason") == "native_crash" && first.getInt("status") == 11)
    check(first.getInt("version_code") == 22 && first.getString("last_profile") == "retro_rewind")
    check(first.getLong("pss_kib") == 2048L && first.getLong("rss_kib") == 4096L)
    check(first.keySet() == setOf("pid", "timestamp_ms", "reason_code", "reason", "status", "importance",
        "pss_kib", "rss_kib", "version_code", "last_profile"))
    check(exits.getJSONObject(1).getString("reason") == "low_memory")
    check(exits.getJSONObject(1).isNull("version_code") && exits.getJSONObject(1).isNull("pss_kib"))
    check(exits.getJSONObject(2).isNull("last_profile"))
    check(exits.getJSONObject(3).getString("reason") == "user_requested")
    check(exits.getJSONObject(4).getString("reason") == "unknown")
    check(!report.toString().contains("private"))
    manager.deny = true
    KartPadExitDiagnostics.mark(context, "chooser") // optional API failure must not escape
    val denied = JSONObject(KartPadExitDiagnostics.snapshot(context))
    check(denied.getString("availability") == "unavailable" && !denied.has("exits"))
    check(!denied.toString().contains("private"))
    check(JSONObject(KartPadExitDiagnostics.snapshot(Context(null))).getString("availability") == "unavailable")
    val root = kotlin.io.path.createTempDirectory("kartpad-renderer-setting").toFile()
    try {
        val chooser = Context(manager, root)
        val game = Context(manager, root)
        check(KartPadCharacterGraphicsTest.mode(game) == KartPadCharacterGraphicsTest.Mode.NORMAL)
        // Reset only the process latch to model separate game-process starts.
        fun newCharacterProcess() {
            val latch = KartPadCharacterGraphicsTest::class.java.getDeclaredField("configured")
            latch.isAccessible = true
            latch.setBoolean(null, false)
        }
        for (mode in KartPadCharacterGraphicsTest.Mode.entries) {
            newCharacterProcess()
            check(KartPadCharacterGraphicsTest.setMode(chooser, mode))
            check(KartPadCharacterGraphicsTest.mode(game) == mode)
            KartPadCharacterGraphicsTest.configure(game)
            check(android.system.Os.getenv("KARTPAD_RENDERER_CONST_PNMTX") == mode.environment)
        }
        check(KartPadCharacterGraphicsTest.setMode(chooser, KartPadCharacterGraphicsTest.Mode.ORIGINAL))
        KartPadCharacterGraphicsTest.configure(game) // Activity recreation must keep the running mode.
        check(KartPadCharacterGraphicsTest.active == KartPadCharacterGraphicsTest.Mode.COMPATIBILITY)
        check(android.system.Os.getenv("KARTPAD_RENDERER_CONST_PNMTX") == "1")
        check(KartPadCharacterGraphicsTest.setMode(chooser, KartPadCharacterGraphicsTest.Mode.COMPATIBILITY))
        android.util.AtomicFile.failSuffix = "CharacterGraphicsTest"
        check(!KartPadCharacterGraphicsTest.setMode(chooser, KartPadCharacterGraphicsTest.Mode.NORMAL))
        check(KartPadCharacterGraphicsTest.mode(game) == KartPadCharacterGraphicsTest.Mode.COMPATIBILITY)
        android.util.AtomicFile.failSuffix = null
        android.util.AtomicFile.silentFailSuffix = "CharacterGraphicsTest"
        check(!KartPadCharacterGraphicsTest.setMode(chooser, KartPadCharacterGraphicsTest.Mode.NORMAL))
        check(KartPadCharacterGraphicsTest.mode(game) == KartPadCharacterGraphicsTest.Mode.COMPATIBILITY)
        android.util.AtomicFile.silentFailSuffix = null
        for (invalid in listOf("compatibility\n", "1", "unknown", "x".repeat(100))) {
            newCharacterProcess()
            java.io.File(root, "KartPad/CharacterGraphicsTest").writeText(invalid)
            KartPadCharacterGraphicsTest.configure(game)
            check(KartPadCharacterGraphicsTest.active == KartPadCharacterGraphicsTest.Mode.NORMAL)
            check(android.system.Os.getenv("KARTPAD_RENDERER_CONST_PNMTX") == null)
        }
        android.util.AtomicFile.readFailSuffix = "CharacterGraphicsTest"
        check(!KartPadCharacterGraphicsTest.setMode(chooser, KartPadCharacterGraphicsTest.Mode.NORMAL))
        android.util.AtomicFile.readFailSuffix = null
        check(!KartPadRendererDiagnostics.enabled(game))
        fun newRendererProcess() {
            val latch = KartPadRendererDiagnostics::class.java.getDeclaredField("configured")
            latch.isAccessible = true
            latch.setBoolean(null, false)
        }
        check(KartPadRendererDiagnostics.setEnabled(chooser, true))
        KartPadRendererDiagnostics.configure(game)
        check(KartPadRendererDiagnostics.active && android.system.Os.getenv("KARTPAD_RENDERER_VALIDATION") == "1")
        android.util.AtomicFile.failSuffix = "RendererValidation"
        check(!KartPadRendererDiagnostics.setEnabled(chooser, false))
        check(KartPadRendererDiagnostics.enabled(game))
        android.util.AtomicFile.failSuffix = null
        android.util.AtomicFile.silentFailSuffix = "RendererValidation"
        check(!KartPadRendererDiagnostics.setEnabled(chooser, false))
        check(KartPadRendererDiagnostics.enabled(game))
        android.util.AtomicFile.silentFailSuffix = null
        check(KartPadRendererDiagnostics.setEnabled(chooser, false))
        KartPadRendererDiagnostics.configure(game)
        // The native renderer caches its environment setting. Activity recreation
        // must not relabel the running session with the next-launch preference.
        check(KartPadRendererDiagnostics.active && android.system.Os.getenv("KARTPAD_RENDERER_VALIDATION") == "1")
        newRendererProcess()
        KartPadRendererDiagnostics.configure(game)
        check(!KartPadRendererDiagnostics.active && android.system.Os.getenv("KARTPAD_RENDERER_VALIDATION") == "0")
        java.io.File(root, "KartPad/RendererValidation").writeText("1\nprivate-data")
        check(!KartPadRendererDiagnostics.enabled(game))
        newRendererProcess()
        KartPadRendererDiagnostics.configure(game)
        check(!KartPadRendererDiagnostics.active)
        android.util.AtomicFile.readFailSuffix = "RendererValidation"
        // The default-off read policy must not falsely confirm a write.
        check(!KartPadRendererDiagnostics.setEnabled(chooser, false))
        android.util.AtomicFile.readFailSuffix = null
    } finally {
        android.util.AtomicFile.failSuffix = null
        android.util.AtomicFile.silentFailSuffix = null
        android.util.AtomicFile.readFailSuffix = null
        root.deleteRecursively()
    }
    println("PASS: API compatibility, bounded exit attribution, privacy, failure recovery, durable renderer setting")
}
