package dev.kartpad.android

import android.system.Os
import android.util.AtomicFile
import java.io.File
import java.nio.file.Files

/** Exercise lost-write errors without changing the native identity edit semantics. */
fun testIdentityMiiPublication(fixtures: File) {
    val failures = mutableListOf<String>()
    var cases = 0
    fun runCase(name: String, body: (File) -> Unit) {
        val root = Files.createTempDirectory("kartpad-identity-publication-").toFile()
        try {
            body(root)
        } catch (e: Exception) {
            failures += "$name: ${e.message}"
        } finally {
            AtomicFile.silentFailSuffix = null
            Os.failSyncSuffix = null
            root.deleteRecursively()
            cases++
        }
    }
    for (fault in listOf("mii", "original", "journal", "before", "after", "manifest", "pointer", "file-sync", "directory-sync")) {
        runCase("identity/$fault") { root ->
            fun target(profile: String) = File(root, "KartPad/${KartPadIdentityStorage.paths.getValue(profile)}")
            for (profile in KartPadIdentityStorage.paths.keys) {
                target(profile).parentFile.mkdirs()
                File(fixtures, if (profile == "mii") "mii.dat" else "save.dat").copyTo(target(profile))
            }
            val before = KartPadIdentityStorage.paths.keys.associateWith { target(it).readBytes() }
            fun record(profile: String) = KartPadIdentityStorage.records(root, profile == "mii").first { it.profile == profile }
            val player = record("original")
            if (fault == "journal") {
                AtomicFile.silentFailSuffix = "/PendingAndroidIdentity.json"
                check(runCatching { KartPadIdentityStorage.stage(root, player, false, "Racer") }.isFailure) { "failed staging reported success" }
                check(!KartPadIdentityStorage.hasPending(root))
                check(before.all { (key, bytes) -> target(key).readBytes().contentEquals(bytes) })
                AtomicFile.silentFailSuffix = null
            }
            KartPadIdentityStorage.stage(root, player, false, "Racer")
            if (fault != "journal") {
                AtomicFile.silentFailSuffix = when (fault) {
                    "mii" -> target("mii").path
                    "original" -> target("original").path
                    "before" -> "/original.before"
                    "after" -> "/original.after"
                    "manifest" -> "/profiles.json"
                    "pointer" -> "/PendingAndroidIdentityTransaction"
                    else -> null
                }
                if (fault == "file-sync") Os.failSyncSuffix = target("mii").path
                if (fault == "directory-sync") Os.failSyncSuffix = target("mii").parentFile.path
                val error = KartPadIdentityStorage.applyPending(root)
                check(error != null) { "reported success; original=${record("original").name}, mii=${record("mii").name}, pending=${KartPadIdentityStorage.hasPending(root)}" }
                check(KartPadIdentityStorage.hasPending(root))
                if (fault in listOf("before", "after", "manifest", "pointer"))
                    check(before.all { (key, bytes) -> target(key).readBytes().contentEquals(bytes) })
                check(KartPadIdentityStorage.applyPending(root) != null) { "persistent fault bypassed on retry" }
                AtomicFile.silentFailSuffix = null; Os.failSyncSuffix = null
            }
            check(KartPadIdentityStorage.applyPending(root) == null)
            check(!KartPadIdentityStorage.hasPending(root))
            check(record("original").name == "Racer" && record("mii").name == "Racer")
            for (profile in listOf("retro_rewind", "retro_rewind_separate"))
                check(target(profile).readBytes().contentEquals(before.getValue(profile)))
            val backups = File(root, "KartPad/IdentityBackups").walkTopDown().filter { it.isFile }.toList()
            for (profile in listOf("original", "mii")) check(backups.any {
                it.name == "$profile.before" && it.readBytes().contentEquals(before.getValue(profile))
            })
        }
    }
    val prior = File(fixtures, "mii.dat").readBytes()
    val replacement = prior.copyOf().apply {
        this[0x24] = (this[0x24].toInt() xor 1).toByte()
        var crc = 0
        for (index in 0 until 0x1f1de) {
            crc = crc xor ((this[index].toInt() and 255) shl 8)
            repeat(8) { crc = if (crc and 0x8000 != 0) (crc shl 1) xor 0x1021 else crc shl 1 }
            crc = crc and 0xffff
        }
        this[0x1f1de] = (crc shr 8).toByte(); this[0x1f1df] = crc.toByte()
    }
    for (fault in listOf("target", "pending", "file-sync", "backup-sync", "directory-sync")) {
        runCase("mii/$fault") { root ->
            val active = File(root, "KartPad/${KartPadIdentityStorage.paths.getValue("mii")}")
            active.parentFile.mkdirs(); active.writeBytes(prior)
            val pending = File(root, "KartPad/PendingRFL_DB.dat")
            if (fault == "pending") {
                AtomicFile.silentFailSuffix = pending.path
                check(runCatching { KartPadMiiStorage.writePending(root, replacement) }.isFailure) { "failed staging reported success" }
                check(!pending.exists() && active.readBytes().contentEquals(prior))
                AtomicFile.silentFailSuffix = null
            }
            KartPadMiiStorage.writePending(root, replacement)
            if (fault != "pending") {
                if (fault == "target") AtomicFile.silentFailSuffix = active.path
                if (fault == "file-sync") Os.failSyncSuffix = active.path
                if (fault == "backup-sync") Os.failSyncSuffix = "/MiiBackups"
                if (fault == "directory-sync") Os.failSyncSuffix = active.parentFile.path
                check(KartPadMiiStorage.applyPending(root) != null) { "failed apply reported success; pending=${pending.exists()}, oldDatabase=${active.readBytes().contentEquals(prior)}" }
                check(pending.readBytes().contentEquals(replacement))
                if (fault != "directory-sync") check(active.readBytes().contentEquals(prior))
                check(KartPadMiiStorage.applyPending(root) != null)
                AtomicFile.silentFailSuffix = null; Os.failSyncSuffix = null
            }
            check(KartPadMiiStorage.applyPending(root) == null)
            check(!pending.exists() && active.readBytes().contentEquals(replacement))
            check(File(root, "KartPad/MiiBackups").listFiles().orEmpty().any { it.readBytes().contentEquals(prior) })
        }
    }
    check(failures.isEmpty()) { failures.joinToString("\n") }
    println("Identity/Mii publication passed: $cases fault cases, retained requests, linked-name recovery, original backups and untouched profiles")
}
