package dev.kartpad.android

import android.content.Context
import android.os.SystemClock
import java.io.File
import org.json.JSONObject

/** Bounded, structured context shared by the short report and private export. */
internal object KartPadReportContext {
    internal fun buildProvenance(bytes: ByteArray): JSONObject? = runCatching {
        require(bytes.size <= 8192)
        val input = JSONObject(String(bytes, Charsets.UTF_8))
        require(input.get("schema") == 1)
        val revision = input.getString("source_revision")
        require(Regex("(?:[0-9a-f]{40}|[0-9a-f]{64})").matches(revision))
        val dirty = input.get("source_dirty")
        require(dirty is Boolean)
        val scope = "source_inputs_only_not_dependency_or_binary_identity"
        require(input.getString("scope") == scope)
        val result = JSONObject().put("schema", 1).put("source_revision", revision)
            .put("source_dirty", dirty).put("scope", scope)
        for (key in listOf("kartpad_source", "prepared_runtime", "translation")) {
            require(input.has(key))
            if (input.isNull(key) && key != "kartpad_source") {
                result.put(key, JSONObject.NULL)
            } else {
                val tree = input.getJSONObject(key)
                val hash = tree.getString("sha256")
                require(Regex("[0-9a-f]{64}").matches(hash))
                val count = tree.get("files")
                require(count is Int && count in 1..10000000)
                result.put(key, JSONObject().put("sha256", hash).put("files", count))
            }
        }
        result
    }.getOrNull()

    private fun packagedBuild(context: Context): JSONObject? = runCatching {
        context.assets.open("kartpad-build.json").use { input ->
            val bytes = ByteArray(8193)
            var count = 0
            while (count < bytes.size) {
                val read = input.read(bytes, count, bytes.size - count)
                if (read < 0) break
                check(read > 0)
                count += read
            }
            buildProvenance(bytes.copyOf(count))
        }
    }.getOrNull()

    fun snapshot(context: Context, profile: String?, activeRendererValidation: Boolean? = null): JSONObject {
        val versionFile = File(context.filesDir, "KartPad/RetroRewind/${RetroRewindRelease.ROOT}/version.txt")
        val installed = runCatching { versionFile.inputStream().use { input ->
            val bytes = ByteArray(129)
            var count = 0
            while (count < bytes.size) {
                val read = input.read(bytes, count, bytes.size - count)
                if (read < 0) break
                check(read > 0)
                count += read
            }
            if (count > 128) null else String(bytes, 0, count, Charsets.UTF_8).trim()
                .takeIf { it.length <= 64 && Regex("[0-9]+(\\.[0-9]+){1,3}").matches(it) }
        } }.getOrNull()
        val state = when {
            !versionFile.exists() -> "not_installed"
            installed == null -> "unreadable_or_invalid"
            installed != RetroRewindRelease.VERSION -> "version_mismatch"
            else -> "version_match_only"
        }
        return JSONObject()
            .put("schema", 1)
            .put("diagnostic_contract", 2)
            .put("context_scope", "export_time_not_selected_session")
            .put("capture_support", JSONObject()
                .put("native_stacks", "os_dependent")
                .put("startup_boundaries", "bounded_events_v2")
                .put("frame_timings", "bounded_events_v2")
                .put("function_cpu", "selected_functions_candidate_opt_in")
                .put("graphics_draws", "sampled_pnmtx_candidate_opt_in")
                .put("network_payloads", "not_collected")
                .put("guest_memory", "excluded"))
            .put("platform", "android")
            .put("app_version", BuildConfig.VERSION_NAME)
            .put("app_build", BuildConfig.VERSION_CODE.toString())
            .put("build_provenance", packagedBuild(context) ?: JSONObject.NULL)
            .put("runtime_profile", profile?.takeIf { it == "base" || it == "retro_rewind" } ?: "unknown")
            .put("captured_unix_ms", System.currentTimeMillis())
            .put("monotonic_ms", SystemClock.elapsedRealtime())
            .put("monotonic_clock", "android_elapsed_realtime")
            .put("retro_supported_version", RetroRewindRelease.VERSION)
            .put("retro_installed_version", installed ?: JSONObject.NULL)
            .put("retro_version_state", state)
            .put("retro_code_validation", "not_rechecked_for_report")
            .put("resolution_scale", KartPadTouchSettings.resolutionScale(context))
            .put("aspect_mode", KartPadTouchSettings.aspectMode(context))
            .put("renderer_validation", activeRendererValidation ?: JSONObject.NULL)
            .put("renderer_validation_configured", KartPadRendererDiagnostics.enabled(context))
    }
}
