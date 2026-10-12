package dev.kartpad.android

import android.system.Os
import android.system.OsConstants
import android.util.AtomicFile
import java.io.File

/** Checked completion for private save, identity and Mii transactions. */
internal object KartPadAtomicFile {
    fun write(file: File, data: ByteArray) {
        val parent = checkNotNull(file.parentFile)
        check(parent.isDirectory || parent.mkdirs()) { "Storage directory is unavailable." }
        // Persist newly created staging/backup directories before replacing a file.
        syncDirectory(checkNotNull(parent.parentFile))
        val atomic = AtomicFile(file)
        val output = atomic.startWrite()
        try {
            output.write(data)
            // Android may only log sync/rename failures from finishWrite.
            Os.fsync(output.fd)
            atomic.finishWrite(output)
            check(!File(file.path + ".new").exists() && !File(file.path + ".bak").exists() &&
                file.isFile && file.length() == data.size.toLong() && file.readBytes().contentEquals(data)) {
                "File publication did not complete."
            }
            syncDirectory(parent)
        } catch (error: Throwable) {
            atomic.failWrite(output)
            throw error
        }
    }

    fun syncDirectory(file: File) {
        check(file.isDirectory)
        val directory = Os.open(file.path, OsConstants.O_RDONLY, 0)
        try { Os.fsync(directory) } finally { Os.close(directory) }
    }
}
