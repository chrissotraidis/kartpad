package dev.kartpad.android

import android.util.AtomicFile
import java.io.File

/** App-private staging and crash-safe startup application for Mii database edits. */
internal object KartPadMiiStorage {
    private const val DATABASE_SIZE = 779_968
    private const val CRC_OFFSET = 0x1F1DE
    private const val SUPPORT_ROOT = "KartPad"
    private const val DATABASE = "NAND/shared2/menu/FaceLib/RFL_DB.dat"
    private const val PENDING = "PendingRFL_DB.dat"

    fun readWorking(filesDir: File): ByteArray {
        val pending = pendingFile(filesDir)
        val source = if (pending.isFile) pending else databaseFile(filesDir)
        require(source.isFile) {
            "No Mii database exists yet. Start Mario Kart Wii once, then try again."
        }
        return runCatching { source.readBytes() }.getOrElse {
            throw IllegalStateException("The Mii database could not be read.")
        }
    }

    fun hasPending(filesDir: File): Boolean = pendingFile(filesDir).isFile

    fun writePending(filesDir: File, database: ByteArray) {
        require(isValidDatabase(database)) { "The updated Mii database is invalid." }
        val file = pendingFile(filesDir)
        file.parentFile?.mkdirs()
        val atomic = AtomicFile(file)
        val stream = atomic.startWrite()
        try {
            stream.write(database)
            atomic.finishWrite(stream)
        } catch (error: Throwable) {
            atomic.failWrite(stream)
            throw error
        }
    }

    /** Applies a previously validated edit before SDL starts and retains a backup. */
    fun applyPending(filesDir: File): String? {
        val pending = pendingFile(filesDir)
        if (!pending.isFile) return null
        val data = runCatching { pending.readBytes() }.getOrElse {
            return "The pending Mii database could not be read."
        }
        if (!isValidDatabase(data)) {
            return "The pending Mii database failed validation and was not applied."
        }
        return runCatching {
            val database = databaseFile(filesDir)
            database.parentFile?.mkdirs()
            if (database.isFile) {
                val backups = File(filesDir, "$SUPPORT_ROOT/MiiBackups")
                backups.mkdirs()
                val backup = File(backups, "RFL_DB-${System.currentTimeMillis()}.dat")
                database.copyTo(backup, overwrite = false)
            }
            val atomic = AtomicFile(database)
            val stream = atomic.startWrite()
            try {
                stream.write(data)
                atomic.finishWrite(stream)
            } catch (error: Throwable) {
                atomic.failWrite(stream)
                throw error
            }
            check(pending.delete()) { "Pending Mii database could not be removed." }
            null
        }.getOrElse { "Pending Mii changes could not be applied safely." }
    }

    internal fun isValidDatabase(database: ByteArray): Boolean {
        if (database.size != DATABASE_SIZE ||
            database[0] != 'R'.code.toByte() ||
            database[1] != 'N'.code.toByte() ||
            database[2] != 'O'.code.toByte() ||
            database[3] != 'D'.code.toByte()
        ) {
            return false
        }
        var crc = 0
        for (index in 0 until CRC_OFFSET) {
            crc = crc xor ((database[index].toInt() and 0xff) shl 8)
            repeat(8) {
                crc = if ((crc and 0x8000) != 0) {
                    ((crc shl 1) xor 0x1021) and 0xffff
                } else {
                    (crc shl 1) and 0xffff
                }
            }
        }
        val stored = ((database[CRC_OFFSET].toInt() and 0xff) shl 8) or
            (database[CRC_OFFSET + 1].toInt() and 0xff)
        return stored == crc
    }

    private fun databaseFile(filesDir: File) = File(filesDir, "$SUPPORT_ROOT/$DATABASE")
    private fun pendingFile(filesDir: File) = File(filesDir, "$SUPPORT_ROOT/$PENDING")
}
