package dev.kartpad.android

import android.content.Context
import android.net.Uri
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.Executors

/**
 * The player's game pack: KartPad's translated game code, built by PadMint on
 * the player's own computer from their own disc. The published app contains no
 * game code; the runtime loads this file at startup (KARTPAD_GAME_PACK) and
 * checks its pack interface fingerprint (pack ABI 3): any KartPad version whose
 * fingerprint is unchanged keeps working with the same pack.
 */
object KartPadGamePack {
    const val PADMINT_URL = "https://github.com/chrissotraidis/padmint"
    private val ELF_MAGIC = byteArrayOf(0x7F, 'E'.code.toByte(), 'L'.code.toByte(), 'F'.code.toByte())
    private val INFO_SYMBOL = "kartpad_game_pack_info".toByteArray()
    // KARTPAD_GAME_PACK_FINGERPRINT_PREFIX in the runtime's game_pack.h.
    private val FINGERPRINT_PREFIX = "kartpad-pack-fingerprint:".toByteArray()
    private const val FINGERPRINT_LENGTH = 64

    // Lives with the app process, so a copy survives the launcher screen being
    // rebuilt (for example when the file picker rotates the screen).
    private val importer = Executors.newSingleThreadExecutor()

    val required: Boolean get() = BuildConfig.GAME_PACK_APP

    /** The ready-to-play app carries its game pack, installed with its other native libraries. */
    val bundled: Boolean get() = BuildConfig.BUNDLED_GAME_PACK

    // One pack, kept across updates. The fingerprint recorded beside it at import
    // decides whether this app version can load it.
    fun file(context: Context) =
        if (bundled) File(context.applicationInfo.nativeLibraryDir, "libkartpad_game.so")
        else File(context.filesDir, "gamepack/libkartpad_game.so")

    private fun fingerprintFile(pack: File) = File(pack.path + ".fingerprint")

    fun isInstalled(context: Context): Boolean {
        val pack = file(context)
        if (!pack.isFile) return false
        if (bundled) return true // built with this app, from the same pack interface
        val recorded = runCatching { fingerprintFile(pack).readText().trim() }.getOrNull()
        return recorded == BuildConfig.PACK_FINGERPRINT
    }

    /** A pack from an earlier KartPad is present but this version cannot load it. */
    fun hasOlderPack(context: Context): Boolean =
        !bundled && !isInstalled(context) &&
            file(context).parentFile?.listFiles()?.any { it.isFile && it.name.endsWith(".so") } == true

    /** Imports on a background thread and reports the result (an error message, or null). */
    fun importInBackground(context: Context, source: Uri, done: (String?) -> Unit) {
        val app = context.applicationContext
        importer.execute { done(import(app, source)) }
    }

    /** The ready-to-play app needs no imported pack: free the space an earlier one took. */
    fun removeImportedPack(context: Context) {
        if (!bundled) return
        val folder = File(context.applicationContext.filesDir, "gamepack")
        if (folder.isDirectory) importer.execute { folder.deleteRecursively() }
    }

    /** Copies the chosen file into app storage. Returns an error message, or null on success. */
    fun import(context: Context, source: Uri): String? {
        val destination = file(context)
        destination.parentFile?.mkdirs()
        val partial = File(destination.path + ".partial")
        try {
            val input = context.contentResolver.openInputStream(source)
                ?: return "The chosen file could not be opened."
            input.use { stream -> partial.outputStream().use { stream.copyTo(it) } }
            if (!looksLikeGamePack(partial)) {
                partial.delete()
                return "That file is not a KartPad game pack. Choose the file PadMint made."
            }
            val fingerprint = fingerprint(partial)
            if (fingerprint != BuildConfig.PACK_FINGERPRINT) {
                partial.delete()
                return "That game pack was made for a different version of KartPad. " +
                    "Build a new one with PadMint for KartPad ${BuildConfig.VERSION_NAME}."
            }
            if (!partial.renameTo(destination)) {
                partial.delete()
                return "The game pack could not be saved."
            }
            fingerprintFile(destination).writeText(fingerprint + "\n")
            // Older packs (libkartpad_game-<version>.so before pack ABI 3) can never load again.
            val keep = setOf(destination, fingerprintFile(destination))
            destination.parentFile?.listFiles()?.forEach { if (it !in keep) it.delete() }
            return null
        } catch (error: Exception) {
            partial.delete()
            if (error.message?.contains("ENOSPC") == true) {
                return "There is not enough free space on this device. " +
                    "The game pack needs about 150 MB. Free some space and try again."
            }
            return "The game pack could not be copied: ${error.message}"
        }
    }

    private fun looksLikeGamePack(candidate: File): Boolean {
        val header = ByteArray(4)
        candidate.inputStream().use { if (it.read(header) != 4) return false }
        if (!header.contentEquals(ELF_MAGIC)) return false
        // The exported info symbol name sits in the dynamic string table.
        return offsetOf(candidate, INFO_SYMBOL) >= 0
    }

    /** The pack interface fingerprint the pack was built with, or null (older packs). */
    fun fingerprint(candidate: File): String? {
        val at = offsetOf(candidate, FINGERPRINT_PREFIX)
        if (at < 0) return null
        val value = ByteArray(FINGERPRINT_LENGTH)
        RandomAccessFile(candidate, "r").use { file ->
            file.seek(at + FINGERPRINT_PREFIX.size)
            if (file.read(value) != FINGERPRINT_LENGTH) return null
        }
        val text = String(value, Charsets.US_ASCII)
        return text.takeIf { hex -> hex.all { it in '0'..'9' || it in 'a'..'f' } }
    }

    /** File offset of the first occurrence of needle, or -1. */
    private fun offsetOf(candidate: File, needle: ByteArray): Long {
        val window = ByteArray(1 shl 20)
        var carry = 0
        var windowStart = 0L
        candidate.inputStream().use { stream ->
            while (true) {
                val read = stream.read(window, carry, window.size - carry)
                if (read <= 0) return -1
                val end = carry + read
                val index = indexOf(window, end, needle)
                if (index >= 0) return windowStart + index
                val keep = minOf(needle.size - 1, end)
                System.arraycopy(window, end - keep, window, 0, keep)
                windowStart += (end - keep).toLong()
                carry = keep
            }
        }
    }

    private fun indexOf(buffer: ByteArray, length: Int, needle: ByteArray): Int {
        outer@ for (i in 0..length - needle.size) {
            for (j in needle.indices) if (buffer[i + j] != needle[j]) continue@outer
            return i
        }
        return -1
    }
}
