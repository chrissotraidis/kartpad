package dev.kartpad.android

import android.system.ErrnoException
import android.system.Os
import java.io.File

/** Reads Android filesystem identity/capacity and delegates policy to the pure evaluator. */
internal object RetroRewindSpaceProbe {
    fun check(filesDirectory: File, cacheDirectory: File): RetroRewindSpacePreflight.Result =
        try {
            val sameStore =
                Os.stat(filesDirectory.absolutePath).st_dev ==
                    Os.stat(cacheDirectory.absolutePath).st_dev
            RetroRewindSpacePreflight.evaluate(
                filesDirectory.usableSpace,
                cacheDirectory.usableSpace,
                sameStore,
                RetroRewindRelease.ARCHIVE_BYTES,
                RetroRewindRelease.MAXIMUM_EXPANDED_BYTES,
                RetroRewindArchiveDownload.reusableBytes(cacheDirectory.toPath()),
            )
        } catch (_: ErrnoException) {
            RetroRewindSpacePreflight.probeFailed()
        }
}
