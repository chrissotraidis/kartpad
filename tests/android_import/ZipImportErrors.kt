package dev.kartpad.android

import android.content.ContentResolver
import android.net.Uri
import android.system.ErrnoException
import android.system.OsConstants
import java.io.*
import java.util.zip.*

private fun archive(): ByteArray {
    // More than two copy buffers, so a mid-payload failure follows real writes.
    val contents = ByteArray(32 * 1024) { (it * 31).toByte() }
    val output = ByteArrayOutputStream()
    ZipOutputStream(output).use { zip ->
        val entry = ZipEntry("sys/main.dol").apply {
            method = ZipEntry.STORED
            size = contents.size.toLong()
            compressedSize = size
            crc = CRC32().apply { update(contents) }.value
        }
        zip.putNextEntry(entry)
        zip.write(contents)
        zip.closeEntry()
    }
    return output.toByteArray()
}

fun main(args: Array<String>) {
    val files = File(args.single()).apply { mkdirs() }
    val support = KartPadGameDataStorage.root(files).apply { mkdirs() }
    val installed = KartPadGameDataStorage.installed(files).apply { mkdirs() }
    val kept = listOf(File(installed, "existing-data"), File(support, "save-sentinel"), File(support, "Config.toml"))
    kept.forEach { it.writeText("preserve ${it.name}") }
    val expected = kept.associateWith { it.readBytes().toList() }

    fun failure(input: InputStream): Pair<Throwable, String> {
        val resolver = object : ContentResolver() {
            override fun openInputStream(uri: Uri) = input
        }
        val error = runCatching { KartPadGameDataStorage.importZip(resolver, Uri(), files) {} }.exceptionOrNull()
            ?: error("Synthetic input unexpectedly activated")
        expected.forEach { (path, bytes) -> check(path.readBytes().toList() == bytes) }
        check(support.listFiles()!!.none { it.name.startsWith("GameData.import-") || it.name.startsWith("GameData.rollback-") })
        return error to Formatter.safeError(error, "Could not import game data.")
    }

    val bytes = archive()
    val dataStart = 30 + "sys/main.dol".length
    fun brokenStream(error: IOException, failAfter: Int) = object : InputStream() {
        private var position = 0
        private fun fail(): Nothing {
            if (failAfter > dataStart) {
                val staging = support.listFiles()!!.single { it.name.startsWith("GameData.import-") }
                val partial = File(staging, "sys/main.dol").readBytes()
                check(partial.size >= DEFAULT_BUFFER_SIZE) { "Failure preceded a staged payload write" }
                check(partial.toList() == bytes.copyOfRange(dataStart, dataStart + partial.size).toList())
            }
            throw error
        }
        override fun read(): Int {
            if (position >= failAfter) fail()
            return bytes[position++].toInt() and 0xff
        }
        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            if (length == 0) return 0
            if (position >= failAfter) fail()
            val count = minOf(length, failAfter - position)
            bytes.copyInto(buffer, offset, position, position + count)
            position += count
            return count
        }
    }
    // Exercise both local-header reads and cleanup after a partial staged copy.
    for (failAfter in listOf(10, dataStart + 2 * DEFAULT_BUFFER_SIZE + 17)) {
        val full = IOException("write failed", ErrnoException("write", OsConstants.ENOSPC))
        val (fullError, fullMessage) = failure(brokenStream(full, failAfter))
        check(fullError === full) { "Storage error was replaced: $fullError" }
        check(fullMessage.startsWith("Not enough free storage")) { fullMessage }

        val disconnected = IOException("cloud provider disconnected")
        val (providerError, providerMessage) = failure(brokenStream(disconnected, failAfter))
        check(providerError === disconnected)
        check(providerMessage == "Could not import game data.")
    }

    val corrupt = bytes.clone().apply { this[dataStart] = (this[dataStart].toInt() xor 0xff).toByte() }
    for (badZip in listOf(corrupt, bytes.copyOf(dataStart + 3))) {
        val (_, message) = failure(ByteArrayInputStream(badZip))
        check(message.startsWith("The zip is damaged or incomplete")) { message }
    }
    println("PASS: header and partial-payload ENOSPC/provider failures distinguished from CRC/truncation; existing data, saves and config preserved; staging removed")
}
