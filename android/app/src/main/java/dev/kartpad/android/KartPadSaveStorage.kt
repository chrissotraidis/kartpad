package dev.kartpad.android

import android.util.AtomicFile
import java.io.File
import java.util.UUID
import java.util.zip.CRC32

/** Validates and stages exact Mario Kart Wii RKSYS backup/restore operations. */
internal object KartPadSaveStorage {
    const val SAVE_BYTES = 0x2bc000
    private const val CORE_CRC_OFFSET = 0x27ffc
    private val magic = "RKSD0006".toByteArray(Charsets.US_ASCII)

    fun active(filesDir: File): File = File(
        filesDir,
        "KartPad/NAND/title/00010004/524d4350/data/rksys.dat",
    )

    private fun pending(filesDir: File): File = File(filesDir, "KartPad/PendingSaves/rksys.dat")

    fun hasPending(filesDir: File): Boolean = pending(filesDir).isFile

    fun readActive(filesDir: File): ByteArray {
        val file = active(filesDir)
        require(file.isFile) { "No Mario Kart Wii save exists yet." }
        return readExact(file).also(::validate)
    }

    fun writePending(filesDir: File, data: ByteArray) {
        validate(data)
        val file = pending(filesDir)
        check(file.parentFile?.let { it.isDirectory || it.mkdirs() } == true) {
            "Save staging is unavailable."
        }
        writeAtomic(file, data)
    }

    /** Applies a validated restore before SDL starts and retains the prior save. */
    fun applyPending(filesDir: File): String? {
        val pending = pending(filesDir)
        if (!pending.isFile) return null
        return runCatching {
            val replacement = readExact(pending).also(::validate)
            val active = active(filesDir)
            check(active.parentFile?.let { it.isDirectory || it.mkdirs() } == true) {
                "Save storage is unavailable."
            }
            if (active.isFile) {
                val current = readExact(active).also(::validate)
                val backups = File(filesDir, "KartPad/SaveBackups")
                check(backups.isDirectory || backups.mkdirs()) { "Save backup storage is unavailable." }
                val backup = File(backups, "rksys-${System.currentTimeMillis()}-${UUID.randomUUID()}.dat")
                writeAtomic(backup, current)
            }
            writeAtomic(active, replacement)
            check(pending.delete()) { "The pending save restore could not be finalized." }
            pending.parentFile?.delete()
        }.exceptionOrNull()?.let { "A pending save restore could not be applied safely." }
    }

    fun validate(data: ByteArray) {
        require(data.size == SAVE_BYTES) { "A Mario Kart Wii save must be exactly $SAVE_BYTES bytes." }
        require(data.copyOfRange(0, magic.size).contentEquals(magic)) {
            "The selected file is not a supported Mario Kart Wii RKSYS save."
        }
        val stored = ((data[CORE_CRC_OFFSET].toLong() and 0xff) shl 24) or
            ((data[CORE_CRC_OFFSET + 1].toLong() and 0xff) shl 16) or
            ((data[CORE_CRC_OFFSET + 2].toLong() and 0xff) shl 8) or
            (data[CORE_CRC_OFFSET + 3].toLong() and 0xff)
        val crc = CRC32().apply { update(data, 0, CORE_CRC_OFFSET) }.value
        require(stored == crc) { "The selected Mario Kart Wii save has an invalid checksum." }
    }

    private fun readExact(file: File): ByteArray {
        require(file.length() == SAVE_BYTES.toLong()) {
            "A Mario Kart Wii save must be exactly $SAVE_BYTES bytes."
        }
        return file.readBytes()
    }

    private fun writeAtomic(file: File, data: ByteArray) {
        val atomic = AtomicFile(file)
        val output = atomic.startWrite()
        try {
            output.write(data)
            atomic.finishWrite(output)
        } catch (error: Throwable) {
            atomic.failWrite(output)
            throw error
        }
    }
}
