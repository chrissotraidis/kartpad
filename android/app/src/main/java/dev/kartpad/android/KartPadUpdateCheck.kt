package dev.kartpad.android

import android.content.Context
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Looks for a newer KartPad release on GitHub at most once a day. It sends no
 * information about the player or their game, and any failure stays silent:
 * the notice simply does not appear.
 */
internal object KartPadUpdateCheck {
    private const val LATEST = "https://api.github.com/repos/chrissotraidis/kartpad/releases/latest"
    private const val PREFERENCES = "kartpad_launcher"
    private const val CHECKED_AT = "update_checked_at"
    private const val VERSION = "update_version"
    private const val PAGE = "update_page"
    private const val APK = "update_apk"
    private const val INTERVAL_MILLIS = 24L * 60 * 60 * 1000
    private const val TIMEOUT_MILLIS = 10_000
    private const val MAXIMUM_BYTES = 512 * 1024

    data class Update(val version: String, val pageUrl: String, val apkUrl: String?)

    /** The last release seen, if it is newer than this app. No network access. */
    fun known(context: Context): Update? {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val version = preferences.getString(VERSION, null) ?: return null
        val page = preferences.getString(PAGE, null) ?: return null
        if (!KartPadReleaseVersion.isNewer(version, BuildConfig.VERSION_NAME)) return null
        return Update(version, page, preferences.getString(APK, null))
    }

    /** Refreshes the stored release once a day. Blocks; call it off the main thread. */
    fun refresh(context: Context, now: Long = System.currentTimeMillis()) {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val last = preferences.getLong(CHECKED_AT, 0L)
        if (now >= last && now - last < INTERVAL_MILLIS) return
        preferences.edit().putLong(CHECKED_AT, now).apply()
        val update = runCatching { parse(fetch()) }.getOrNull() ?: return
        preferences.edit()
            .putString(VERSION, update.version)
            .putString(PAGE, update.pageUrl)
            .putString(APK, update.apkUrl)
            .apply()
    }

    internal fun parse(json: String): Update? {
        val release = JSONObject(json)
        if (release.optBoolean("draft") || release.optBoolean("prerelease")) return null
        val version = KartPadReleaseVersion.normalize(release.optString("tag_name")) ?: return null
        val page = release.optString("html_url").takeIf(KartPadReleaseVersion::isReleasePage) ?: return null
        val assets = release.optJSONArray("assets")
        var apk: String? = null
        for (index in 0 until (assets?.length() ?: 0)) {
            val asset = assets?.optJSONObject(index) ?: continue
            val url = asset.optString("browser_download_url")
            if (asset.optString("name") == KartPadReleaseVersion.apkName(version) &&
                KartPadReleaseVersion.isReleaseDownload(url)
            ) {
                apk = url
            }
        }
        return Update(version, page, apk)
    }

    private fun fetch(): String {
        val connection = URL(LATEST).openConnection() as HttpURLConnection
        try {
            connection.instanceFollowRedirects = false
            connection.connectTimeout = TIMEOUT_MILLIS
            connection.readTimeout = TIMEOUT_MILLIS
            connection.setRequestProperty("Accept", "application/vnd.github+json")
            connection.setRequestProperty("User-Agent", "KartPad-Android")
            check(connection.responseCode == HttpURLConnection.HTTP_OK) { "HTTP ${connection.responseCode}" }
            connection.inputStream.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(16 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    output.write(buffer, 0, read)
                    check(output.size() <= MAXIMUM_BYTES) { "release response too large" }
                }
                return output.toString(Charsets.UTF_8.name())
            }
        } finally {
            connection.disconnect()
        }
    }
}
