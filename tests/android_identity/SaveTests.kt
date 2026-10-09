package dev.kartpad.android

import android.util.AtomicFile
import java.io.File
import java.nio.file.Files
import java.util.zip.CRC32

/** Exercises real save storage on synthetic files, including interrupted writes. */
fun testSaveProfiles(fixtures: File) {
    testSavePublicationFailures(fixtures)
    val root = Files.createTempDirectory("kartpad-save-profiles-").toFile()
    val sample = File(fixtures, "save.dat").readBytes()
    fun save(marker: Int) = sample.copyOf().apply saveBytes@{
        this[0x100] = marker.toByte()
        val crc = CRC32().apply { update(this@saveBytes, 0, 0x27ffc) }.value
        repeat(4) { this[0x27ffc + it] = (crc shr (24 - it * 8)).toByte() }
    }
    fun seed(profile: String, bytes: ByteArray) {
        KartPadSaveStorage.active(root, profile).apply { parentFile.mkdirs(); writeBytes(bytes) }
    }
    fun snapshots() = KartPadSaveStorage.profiles.associateWith { KartPadSaveStorage.readActive(root, it) }
    fun backups() = File(root, "KartPad/SaveBackups").listFiles().orEmpty().toList()
    try {
        val mii = File(root, "KartPad/${KartPadIdentityStorage.paths.getValue("mii")}")
        mii.parentFile.mkdirs()
        File(fixtures, "mii.dat").copyTo(mii)
        val originalMii = mii.readBytes()
        KartPadSaveStorage.profiles.forEachIndexed { index, profile -> seed(profile, save(index)) }
        for ((index, profile) in KartPadSaveStorage.profiles.withIndex()) {
            val before = snapshots()
            val oldBackups = backups().toSet()
            val replacement = save(20 + index)
            KartPadSaveStorage.writePending(root, replacement, profile)
            check(KartPadSaveStorage.hasPending(root))
            check(KartPadSaveStorage.hasPending(root, profile))
            check(runCatching { KartPadSaveStorage.writePending(root, save(90), profile) }.isFailure)
            check(snapshots().all { (key, bytes) -> bytes.contentEquals(before.getValue(key)) })
            // Identity edits must see restores for every profile, including Retro.
            val record = KartPadIdentityStorage.records(root, false).first()
            check(runCatching { KartPadIdentityStorage.stage(root, record, false, "Blocked") }.isFailure)
            check(KartPadSaveStorage.applyPending(root) == null)
            check(!KartPadSaveStorage.hasPending(root))
            check(KartPadSaveStorage.readActive(root, profile).contentEquals(replacement))
            for (other in KartPadSaveStorage.profiles - profile)
                check(KartPadSaveStorage.readActive(root, other).contentEquals(before.getValue(other)))
            val newBackup = (backups().toSet() - oldBackups).single()
            check(newBackup.readBytes().contentEquals(before.getValue(profile)))
            check(mii.readBytes().contentEquals(originalMii))
        }
        val before = snapshots()
        for (invalid in listOf(sample.copyOf(10), sample + byteArrayOf(0),
            sample.copyOf().apply { this[0] = 0 }, sample.copyOf().apply { this[0x100] = 99 })) {
            check(runCatching { KartPadSaveStorage.writePending(root, invalid, "retro_rewind") }.isFailure)
            check(!KartPadSaveStorage.hasPending(root))
        }
        for (invalidProfile in listOf("mii", "../original", "base", "")) {
            check(runCatching { KartPadSaveStorage.active(root, invalidProfile) }.isFailure)
            check(runCatching { KartPadSaveStorage.writePending(root, sample, invalidProfile) }.isFailure)
        }
        // A pre-upgrade pending file must still apply to Original only.
        File(root, "KartPad/PendingSaves/rksys.dat").apply { parentFile.mkdirs(); writeBytes(save(40)) }
        check(KartPadSaveStorage.applyPending(root) == null)
        check(KartPadSaveStorage.readActive(root).contentEquals(save(40)))
        check(KartPadSaveStorage.readActive(root, "retro_rewind").contentEquals(before.getValue("retro_rewind")))
        val record = KartPadIdentityStorage.records(root, false).first()
        KartPadIdentityStorage.stage(root, record, false, "Racer")
        check(runCatching { KartPadSaveStorage.writePending(root, sample, "retro_rewind") }.isFailure)
        check(KartPadIdentityStorage.applyPending(root) == null)
        // Failed publication retains the old target, staged replacement and backup.
        val oldRetro = KartPadSaveStorage.readActive(root, "retro_rewind")
        KartPadSaveStorage.writePending(root, save(50), "retro_rewind")
        AtomicFile.failSuffix = "/RetroWFC/RMCP/rksys.dat"
        check(KartPadSaveStorage.applyPending(root) != null)
        check(KartPadSaveStorage.hasPending(root, "retro_rewind"))
        check(KartPadSaveStorage.readActive(root, "retro_rewind").contentEquals(oldRetro))
        check(backups().any { it.readBytes().contentEquals(oldRetro) })
        AtomicFile.failSuffix = null
        check(KartPadSaveStorage.applyPending(root) == null)
        check(KartPadSaveStorage.readActive(root, "retro_rewind").contentEquals(save(50)))
        // First import into a profile with no existing save is supported.
        check(KartPadSaveStorage.active(root, "retro_rewind_separate").delete())
        KartPadSaveStorage.writePending(root, save(60), "retro_rewind_separate")
        check(KartPadSaveStorage.applyPending(root) == null)
        check(KartPadSaveStorage.readActive(root, "retro_rewind_separate").contentEquals(save(60)))
        // Corruption after staging must stop application and preserve every target.
        val beforeCorrupt = snapshots()
        KartPadSaveStorage.writePending(root, save(70), "retro_rewind")
        val pending = File(root, "KartPad/PendingSaves/retro_rewind.dat")
        pending.writeBytes(byteArrayOf(1, 2, 3))
        check(KartPadSaveStorage.applyPending(root) != null)
        check(KartPadSaveStorage.hasPending(root))
        check(snapshots().all { (key, bytes) -> bytes.contentEquals(beforeCorrupt.getValue(key)) })
        pending.writeBytes(save(70))
        KartPadSaveStorage.writePending(root, save(71), "retro_rewind_separate")
        check(KartPadSaveStorage.applyPending(root) == null)
        check(!KartPadSaveStorage.hasPending(root))
        check(KartPadSaveStorage.readActive(root, "retro_rewind").contentEquals(save(70)))
        check(KartPadSaveStorage.readActive(root, "retro_rewind_separate").contentEquals(save(71)))
        // A pending ghost patches only its slot against the latest progress.
        seed("original", save(80))
        val ghostBefore = KartPadSaveStorage.readActive(root)
        val ghostAfter = ghostBefore.copyOf().apply { this[0x78000] = 42 }
        KartPadSaveStorage.writePendingGhost(root, ghostBefore, ghostAfter, 0, 0)
        check(runCatching { KartPadSaveStorage.writePending(root, save(81)) }.isFailure)
        seed("original", save(82))
        check(KartPadSaveStorage.applyPending(root) == null)
        val ghostApplied = KartPadSaveStorage.readActive(root)
        check(ghostApplied[0x100] == 82.toByte() && ghostApplied[0x78000] == 42.toByte())
        check(backups().any { it.readBytes().contentEquals(save(82)) })
        KartPadSaveStorage.writePendingGhost(root, ghostApplied, ghostApplied, 0, 0)
        val ghostRequest = File(root, "KartPad/PendingGhost.bin")
        ghostRequest.writeBytes(ghostRequest.readBytes().apply { this[30] = (this[30].toInt() xor 1).toByte() })
        check(KartPadSaveStorage.applyPending(root) != null)
        check(KartPadSaveStorage.readActive(root).contentEquals(ghostApplied))
        KartPadSaveStorage.cancelPendingGhost(root)
        check(!KartPadSaveStorage.hasPendingGhost(root))
        println("Android save profiles passed: all three targets, isolated export/restore, backups, legacy pending, invalid inputs, identity conflicts, interrupted publication, first import")
    } finally {
        AtomicFile.failSuffix = null
        root.deleteRecursively()
    }
}

/** A logged AtomicFile failure must never count as a published save or backup. */
private fun testSavePublicationFailures(fixtures: File) {
    val sample = File(fixtures, "save.dat").readBytes()
    fun marked(marker: Int) = sample.copyOf().apply bytes@{
        this[0x100] = marker.toByte()
        val crc = CRC32().apply { update(this@bytes, 0, 0x27ffc) }.value
        repeat(4) { this[0x27ffc + it] = (crc shr (24 - it * 8)).toByte() }
    }
    for (ghost in listOf(true, false)) for (fault in listOf("backup", "publish", "stage", "stage-sync", "publish-sync", "backup-directory-sync", "publish-directory-sync")) {
        val root = Files.createTempDirectory("kartpad-save-publication-").toFile()
        val before = marked(91)
        val replacement = if (ghost) before.copyOf().apply { this[0x78000] = 42 } else marked(92)
        val active = KartPadSaveStorage.active(root)
        val pending = File(root, if (ghost) "KartPad/PendingGhost.bin" else "KartPad/PendingSaves/rksys.dat")
        fun stage() {
            if (ghost) KartPadSaveStorage.writePendingGhost(root, before, replacement, 0, 0)
            else KartPadSaveStorage.writePending(root, replacement)
        }
        try {
            active.parentFile.mkdirs(); active.writeBytes(before)
            val other = KartPadSaveStorage.active(root, "retro_rewind")
            other.parentFile.mkdirs(); other.writeBytes(marked(93))
            if (fault.startsWith("stage")) {
                if (fault == "stage") AtomicFile.silentFailSuffix = pending.path
                else android.system.Os.failSyncSuffix = pending.path
                check(runCatching { stage() }.isFailure) { "$ghost/$fault: failed staging reported success" }
                check(!pending.exists())
                check(active.readBytes().contentEquals(before))
                AtomicFile.silentFailSuffix = null; android.system.Os.failSyncSuffix = null
                stage()
            } else {
                stage()
                val staged = pending.readBytes()
                if (fault == "backup") AtomicFile.silentBackupOnly = true
                if (fault == "publish") AtomicFile.silentFailSuffix = active.path
                if (fault == "publish-sync") android.system.Os.failSyncSuffix = active.path
                if (fault == "backup-directory-sync") android.system.Os.failSyncSuffix = "/SaveBackups"
                if (fault == "publish-directory-sync") android.system.Os.failSyncSuffix = active.parentFile.path
                check(KartPadSaveStorage.applyPending(root) != null) { "$ghost/$fault: failed apply reported success" }
                check(pending.readBytes().contentEquals(staged)) { "$ghost/$fault: pending request lost" }
                if (fault == "publish-directory-sync") {
                    // Rename succeeded but its directory barrier failed. Keep blocking on retry,
                    // including a ghost slot that already contains the desired bytes.
                    KartPadSaveStorage.validate(active.readBytes())
                    check(KartPadSaveStorage.applyPending(root) != null)
                    check(pending.readBytes().contentEquals(staged))
                    check(File(root, "KartPad/SaveBackups").listFiles().orEmpty().any { it.readBytes().contentEquals(before) })
                } else check(active.readBytes().contentEquals(before)) { "$ghost/$fault: existing progress replaced" }
                AtomicFile.silentBackupOnly = false; AtomicFile.silentFailSuffix = null; android.system.Os.failSyncSuffix = null
            }
            check(KartPadSaveStorage.applyPending(root) == null) { "$ghost/$fault: retry failed" }
            check(!pending.exists())
            val after = KartPadSaveStorage.readActive(root)
            if (ghost) check(after[0x100] == 91.toByte() && after[0x78000] == 42.toByte())
            else check(after.contentEquals(replacement))
            check(other.readBytes().contentEquals(marked(93)))
            check(File(root, "KartPad/SaveBackups").listFiles().orEmpty().any { it.readBytes().contentEquals(before) })
        } finally {
            AtomicFile.silentBackupOnly = false; AtomicFile.silentFailSuffix = null; android.system.Os.failSyncSuffix = null
            root.deleteRecursively()
        }
    }
    println("Save/ghost publication passed: silent staging, backup and replacement failures; checked sync; exact progress/request preservation and successful retry")
}
