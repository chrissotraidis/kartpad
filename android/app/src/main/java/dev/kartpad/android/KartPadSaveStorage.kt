package dev.kartpad.android

import android.util.AtomicFile
import android.system.Os
import android.system.OsConstants
import java.io.File
import java.util.UUID
import java.util.zip.CRC32

/** Validates and stages exact Mario Kart Wii RKSYS backup/restore operations. */
internal object KartPadSaveStorage {
    const val SAVE_BYTES = 0x2bc000
    private const val CORE_CRC_OFFSET = 0x27ffc
    private val magic = "RKSD0006".toByteArray(Charsets.US_ASCII)

    val profiles = listOf("original", "retro_rewind", "retro_rewind_separate")

    fun title(profile: String): String {
        require(profile in profiles) { "Unknown save profile." }
        return KartPadIdentityStorage.titles.getValue(profile)
    }

    fun active(filesDir: File, profile: String = "original"): File {
        require(profile in profiles) { "Unknown save profile." }
        return File(filesDir, "KartPad/${KartPadIdentityStorage.paths.getValue(profile)}")
    }

    private fun pending(filesDir: File, profile: String): File {
        title(profile)
        // Keep the original filename so pre-upgrade restores retain their target.
        val name = if (profile == "original") "rksys.dat" else "$profile.dat"
        return File(filesDir, "KartPad/PendingSaves/$name")
    }

    fun hasPending(filesDir: File): Boolean = hasPendingGhost(filesDir) || KartPadRatingStorage.hasPending(filesDir) || profiles.any { hasPending(filesDir, it) }

    fun hasPending(filesDir: File, profile: String): Boolean = pending(filesDir, profile).isFile

    fun readActive(filesDir: File, profile: String = "original"): ByteArray {
        val file = active(filesDir, profile)
        require(file.isFile) { "No ${title(profile)} save exists yet." }
        return readExact(file).also(::validate)
    }

    fun writePending(filesDir: File, data: ByteArray, profile: String = "original") {
        require(!hasPendingGhost(filesDir)) { "Apply or cancel the pending ghost import first." }
        require(!KartPadIdentityStorage.hasPending(filesDir)) { "Apply pending identity edits before restoring a save." }
        require(!hasPending(filesDir, profile)) { "Restart to apply this profile's pending restore first." }
        require(!KartPadRatingStorage.hasPending(filesDir)) { "Restart to apply the pending rating restore first." }
        validate(data)
        val file = pending(filesDir, profile)
        check(file.parentFile?.let { it.isDirectory || it.mkdirs() } == true) {
            "Save staging is unavailable."
        }
        writeAtomic(file, data)
    }

    /** Applies a validated restore before SDL starts and retains the prior save. */
    fun applyPending(filesDir: File): String? {
        applyPendingGhost(filesDir)?.let { return it }
        for (profile in profiles) {
            applyPending(filesDir, profile)?.let { return it }
        }
        return KartPadRatingStorage.applyPending(filesDir)
    }

    private fun applyPending(filesDir: File, profile: String): String? {
        val pending = pending(filesDir, profile)
        if (!pending.isFile) return null
        return runCatching {
            check(!KartPadIdentityStorage.hasPending(filesDir))
            val replacement = readExact(pending).also(::validate)
            val active = active(filesDir, profile)
            check(active.parentFile?.let { it.isDirectory || it.mkdirs() } == true) {
                "Save storage is unavailable."
            }
            if (active.isFile) {
                val current = readExact(active).also(::validate)
                val backups = File(filesDir, "KartPad/SaveBackups")
                check(backups.isDirectory || backups.mkdirs()) { "Save backup storage is unavailable." }
                val prefix = if (profile == "original") "rksys" else profile
                val backup = File(backups, "$prefix-${System.currentTimeMillis()}-${UUID.randomUUID()}.dat")
                writeAtomic(backup, current)
            }
            writeAtomic(active, replacement)
            check(pending.delete()) { "The pending save restore could not be finalized." }
            pending.parentFile?.delete()
        }.exceptionOrNull()?.let { "The pending ${title(profile)} save restore could not be applied safely. It remains staged; your existing save and any backups have been retained." }
    }

    private fun ghostPending(files: File) = File(files, "KartPad/PendingGhost.bin")
    fun hasPendingGhost(files: File) = ghostPending(files).isFile
    fun cancelPendingGhost(files: File) { check(!hasPendingGhost(files) || ghostPending(files).delete()) { "Pending ghost could not be cancelled." } }

    fun writePendingGhost(files: File, before: ByteArray, after: ByteArray, license: Int, slot: Int) {
        require(!hasPending(files) && !KartPadIdentityStorage.hasPending(files)) { "Restart to apply the pending data change first." }
        validate(before); validate(after)
        require(license in 0..3 && slot in 0..31) { "Invalid ghost destination." }
        val position = 0x28000 + license * 0xa5000 + 0x50000 + slot * 0x2800
        val identity = 8 + license * 0x8cc0 + 0x28
        val request = java.nio.ByteBuffer.allocate(20 + 0x2800 + 4)
            .putInt(0x4b504731).putInt(license).putInt(slot)
            .put(before, identity, 8).put(after, position, 0x2800).array()
        val crc = CRC32().apply { update(request, 0, request.size - 4) }.value
        java.nio.ByteBuffer.wrap(request).putInt(request.size - 4, crc.toInt())
        val file = ghostPending(files); file.parentFile?.mkdirs(); writeAtomic(file, request)
    }

    private fun applyPendingGhost(files: File): String? {
        val file = ghostPending(files)
        if (!file.isFile) return null
        return runCatching {
            require(!KartPadIdentityStorage.hasPending(files) && !KartPadRatingStorage.hasPending(files) && profiles.none { hasPending(files, it) }) { "Conflicting pending data changes." }
            require(file.length() == (20 + 0x2800 + 4).toLong()) { "Invalid ghost request size." }
            val bytes = file.readBytes(); val request = java.nio.ByteBuffer.wrap(bytes)
            require(request.int == 0x4b504731) { "Invalid ghost request." }
            val license = request.int; val slot = request.int
            require(license in 0..3 && slot in 0..31) { "Invalid ghost destination." }
            require(request.getInt(bytes.size - 4) == CRC32().apply { update(bytes, 0, bytes.size - 4) }.value.toInt()) { "Ghost request checksum mismatch." }
            val current = readActive(files); val next = current.copyOf()
            val identity = 8 + license * 0x8cc0 + 0x28
            require(bytes.copyOfRange(12, 20).contentEquals(current.copyOfRange(identity, identity + 8))) { "The selected license changed." }
            val position = 0x28000 + license * 0xa5000 + 0x50000 + slot * 0x2800
            bytes.copyInto(next, position, 20, 20 + 0x2800)
            val bits = 8 + license * 0x8cc0 + 8
            val view = java.nio.ByteBuffer.wrap(next)
            view.putInt(bits, view.getInt(bits) or (1 shl slot))
            view.putInt(CORE_CRC_OFFSET, CRC32().apply { update(next, 0, CORE_CRC_OFFSET) }.value.toInt())
            validate(next)
            if (!current.contentEquals(next)) {
                val backups = File(files, "KartPad/SaveBackups"); check(backups.isDirectory || backups.mkdirs())
                writeAtomic(File(backups, "rksys-ghost-${System.currentTimeMillis()}-${UUID.randomUUID()}.dat"), current)
                writeAtomic(active(files), next)
            }
            // A retry may find the complete slot after a prior directory-sync failure.
            // Confirm publication before consuming the request even when no rewrite is needed.
            syncDirectory(checkNotNull(active(files).parentFile))
            check(file.delete()) { "Pending ghost could not be finalized." }
        }.exceptionOrNull()?.let { "The ghost import could not be applied safely. Existing progress is retained. Cancel the pending ghost in Original save settings and choose it again." }
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
        val parent = checkNotNull(file.parentFile)
        // Persist newly created staging/backup directories before replacing a save.
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
                "Save publication did not complete."
            }
            syncDirectory(parent)
        } catch (error: Throwable) {
            atomic.failWrite(output)
            throw error
        }
    }

    private fun syncDirectory(file: File) {
        check(file.isDirectory)
        val directory = Os.open(file.path, OsConstants.O_RDONLY, 0)
        try { Os.fsync(directory) } finally { Os.close(directory) }
    }
}
