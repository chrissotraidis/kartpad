package dev.kartpad.android

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.os.Build
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest

/**
 * Updates KartPad in place (#377): downloads the release APK, checks it against the
 * release's SHA256SUMS and against this app (same package, same signing key, newer
 * version), then hands it to Android's installer, which asks the player to confirm.
 * Saves and game data stay, as with any update installed over the app.
 */
internal object KartPadUpdateInstaller {
    const val ACTION_STATUS = "dev.kartpad.android.UPDATE_STATUS"
    private const val MAXIMUM_APK_BYTES = 512L * 1024 * 1024
    private const val MAXIMUM_SUMS_BYTES = 64 * 1024
    private const val TIMEOUT_MILLIS = 20_000

    class Cancelled : IOException("cancelled")

    private fun directory(context: Context) = File(context.cacheDir, "updates")

    /** Removes downloaded updates; called when no newer release is pending. */
    fun clear(context: Context) {
        directory(context).listFiles()?.forEach { it.delete() }
    }

    /**
     * Downloads and verifies the update. Blocks; call it off the main thread. Throws
     * [Cancelled] when [cancelled] turns true, and IllegalStateException with a
     * player-facing message when the download can't be trusted.
     */
    fun download(
        context: Context,
        update: KartPadUpdateCheck.Update,
        progress: (done: Long, total: Long) -> Unit,
        cancelled: () -> Boolean,
    ): File {
        val apkUrl = checkNotNull(update.apkUrl) { "This release has no Android download." }
        val name = KartPadReleaseVersion.apkName(update.version)
        val sums = String(read(KartPadReleaseVersion.sumsUrl(update.version), MAXIMUM_SUMS_BYTES.toLong()), Charsets.UTF_8)
        val expected = checkNotNull(KartPadReleaseVersion.sha256For(sums, name)) {
            "The release doesn't list a checksum for $name."
        }
        val folder = directory(context).apply { mkdirs() }
        clear(context)
        val partial = File(folder, "$name.partial")
        val digest = MessageDigest.getInstance("SHA-256")
        open(apkUrl) { input, total ->
            check(total <= MAXIMUM_APK_BYTES) { "The download is larger than expected." }
            partial.outputStream().use { output ->
                val buffer = ByteArray(256 * 1024)
                var done = 0L
                while (true) {
                    if (cancelled()) throw Cancelled()
                    val read = input.read(buffer)
                    if (read < 0) break
                    done += read
                    check(done <= MAXIMUM_APK_BYTES) { "The download is larger than expected." }
                    digest.update(buffer, 0, read)
                    output.write(buffer, 0, read)
                    progress(done, total)
                }
            }
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it) }
        check(actual == expected) { "The download didn't match the release's checksum. Please try again." }
        val apk = File(folder, name)
        check(partial.renameTo(apk)) { "The download couldn't be saved." }
        verify(context, apk, update.version)
        return apk
    }

    /** Same app, same signing key, and newer than this one; Android checks the key again on install. */
    private fun verify(context: Context, apk: File, version: String) {
        val manager = context.packageManager
        val flags = PackageManager.GET_SIGNING_CERTIFICATES
        val archive = checkNotNull(manager.getPackageArchiveInfo(apk.path, flags)) {
            "The download isn't a valid Android app."
        }
        val installed = manager.getPackageInfo(context.packageName, flags)
        check(archive.packageName == context.packageName) { "The download is a different app." }
        check(archive.versionName == version) { "The download is version ${archive.versionName}, not $version." }
        check(versionCode(archive) > versionCode(installed)) { "The download isn't newer than this KartPad." }
        check(signers(archive).isNotEmpty() && signers(archive) == signers(installed)) {
            "The download isn't signed like this KartPad, so Android wouldn't install it over this one."
        }
    }

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()

    private fun signers(info: PackageInfo): Set<String> =
        info.signingInfo?.apkContentsSigners.orEmpty().map { it.toCharsString() }.toSet()

    /** Hands the verified APK to Android's installer; the result arrives as [ACTION_STATUS]. */
    fun install(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                setPackageSource(PackageInstaller.PACKAGE_SOURCE_DOWNLOADED_FILE)
            }
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            session.openWrite("KartPad.apk", 0, apk.length()).use { output ->
                apk.inputStream().use { it.copyTo(output, 256 * 1024) }
                session.fsync(output)
            }
            val status = Intent(ACTION_STATUS).setPackage(context.packageName)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            session.commit(PendingIntent.getBroadcast(context, sessionId, status, flags).intentSender)
        }
    }

    private fun read(url: String, limit: Long): ByteArray {
        var bytes = ByteArray(0)
        open(url) { input, _ ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(16 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                output.write(buffer, 0, read)
                check(output.size() <= limit) { "The release's checksum list is larger than expected." }
            }
            bytes = output.toByteArray()
        }
        return bytes
    }

    /** GitHub release downloads redirect once to its file host; HTTPS is required throughout. */
    private fun open(url: String, body: (InputStream, Long) -> Unit) {
        check(KartPadReleaseVersion.isReleaseDownload(url)) { "Unexpected download address." }
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.instanceFollowRedirects = true
            connection.connectTimeout = TIMEOUT_MILLIS
            connection.readTimeout = TIMEOUT_MILLIS
            connection.setRequestProperty("User-Agent", "KartPad-Android")
            check(connection.responseCode == HttpURLConnection.HTTP_OK) {
                "GitHub answered ${connection.responseCode}. Please try again."
            }
            check(connection.url.protocol == "https") { "The download wasn't secure." }
            connection.inputStream.use { body(it, connection.contentLengthLong) }
        } finally {
            connection.disconnect()
        }
    }
}
