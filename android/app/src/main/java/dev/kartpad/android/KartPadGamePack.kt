package dev.kartpad.android

import android.content.Context
import android.net.Uri
import java.io.File
import java.util.concurrent.Executors

/**
 * The player's game pack: KartPad's translated game code, built by PadForge on
 * the player's own computer from their own disc. The published app contains no
 * game code; the runtime loads this file at startup (KARTPAD_GAME_PACK) and
 * checks that it was built for this app version.
 */
object KartPadGamePack {
    const val PADFORGE_URL = "https://github.com/chrissotraidis/padforge"
    private val ELF_MAGIC = byteArrayOf(0x7F, 'E'.code.toByte(), 'L'.code.toByte(), 'F'.code.toByte())
    private val INFO_SYMBOL = "kartpad_game_pack_info".toByteArray()

    // Lives with the app process, so a copy survives the launcher screen being
    // rebuilt (for example when the file picker rotates the screen).
    private val importer = Executors.newSingleThreadExecutor()

    val required: Boolean get() = BuildConfig.GAME_PACK_APP

    // One pack per app version: after an update the player is asked for a new
    // pack instead of starting one built for the previous version.
    fun file(context: Context) =
        File(context.filesDir, "gamepack/libkartpad_game-${BuildConfig.VERSION_NAME}.so")

    fun isInstalled(context: Context) = file(context).isFile

    /** Imports on a background thread and reports the result (an error message, or null). */
    fun importInBackground(context: Context, source: Uri, done: (String?) -> Unit) {
        val app = context.applicationContext
        importer.execute { done(import(app, source)) }
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
                return "That file is not a KartPad game pack. Choose the file PadForge made."
            }
            if (!partial.renameTo(destination)) {
                partial.delete()
                return "The game pack could not be saved."
            }
            // Packs for other app versions can never load again.
            destination.parentFile?.listFiles()?.forEach { if (it != destination) it.delete() }
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
        val window = ByteArray(1 shl 20)
        var carry = 0
        candidate.inputStream().use { stream ->
            while (true) {
                val read = stream.read(window, carry, window.size - carry)
                if (read <= 0) return false
                val end = carry + read
                if (indexOf(window, end, INFO_SYMBOL) >= 0) return true
                carry = minOf(INFO_SYMBOL.size - 1, end)
                System.arraycopy(window, end - carry, window, 0, carry)
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
