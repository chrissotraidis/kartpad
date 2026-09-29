package dev.kartpad.android

import android.content.ContentResolver
import android.net.Uri
import java.io.File

/** Narrow JNI boundary for the pinned Dolphin DiscIO source build. */
internal object KartPadDiscImageImporter {
    init {
        System.loadLibrary("kartpad_discio")
    }

    fun extract(resolver: ContentResolver, image: Uri, destination: File, filesDir: File) {
        val key = KartPadCommonKey.read(KartPadCommonKey.file(filesDir))
            ?: throw IllegalArgumentException(
                "KartPad needs your own Wii common key (common-key.bin) to read a disc image. " +
                    "An extracted game data folder needs no key.",
            )
        val descriptor = resolver.openFileDescriptor(image, "r")
            ?: throw IllegalArgumentException("The selected disc image could not be opened.")
        descriptor.use {
            nativeExtract(it.fd, destination.absolutePath, key)?.let {
                throw IllegalArgumentException(it)
            }
        }
    }

    private external fun nativeExtract(fd: Int, destination: String, commonKey: ByteArray): String?
}

/** The player's own 16-byte Wii common key. KartPad never ships console keys. */
internal object KartPadCommonKey {
    const val FILE_NAME = "common-key.bin"
    private const val SIZE = 16

    fun file(filesDir: File) = File(filesDir, FILE_NAME)

    fun isInstalled(filesDir: File) = read(file(filesDir)) != null

    fun read(file: File): ByteArray? =
        runCatching { file.readBytes() }.getOrNull()?.takeIf { it.size == SIZE }

    /** Copies a chosen key file into private storage after checking its size. */
    fun install(resolver: ContentResolver, source: Uri, filesDir: File) {
        val bytes = resolver.openInputStream(source)?.use { it.readNBytesCompat(SIZE + 1) }
            ?: throw IllegalArgumentException("The selected key file could not be opened.")
        require(bytes.size == SIZE) {
            "common-key.bin must be exactly 16 bytes. The selected file is not a Wii common key."
        }
        val target = file(filesDir)
        val staging = File(filesDir, "$FILE_NAME.tmp")
        staging.writeBytes(bytes)
        require(staging.renameTo(target)) { "The key could not be saved." }
    }

    private fun java.io.InputStream.readNBytesCompat(limit: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(limit)
        while (out.size() < limit) {
            val read = read(buffer, 0, limit - out.size())
            if (read < 0) break
            out.write(buffer, 0, read)
        }
        return out.toByteArray()
    }
}
