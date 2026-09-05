package dev.kartpad.android

import android.content.ContentResolver
import android.net.Uri
import java.io.File

/** Narrow JNI boundary for the pinned Dolphin DiscIO source build. */
internal object KartPadDiscImageImporter {
    init {
        System.loadLibrary("kartpad_discio")
    }

    fun extract(resolver: ContentResolver, image: Uri, destination: File) {
        resolver.openFileDescriptor(image, "r")?.use { descriptor ->
            nativeExtract(descriptor.fd, destination.absolutePath)?.let {
                throw IllegalArgumentException(it)
            }
        } ?: throw IllegalArgumentException("The selected disc image could not be opened.")
    }

    private external fun nativeExtract(fd: Int, destination: String): String?
}
