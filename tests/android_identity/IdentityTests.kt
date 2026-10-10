package dev.kartpad.android

import java.io.File
import java.nio.file.Files
import java.util.zip.CRC32
import android.util.AtomicFile

// Bind the production activity's JNI import/list methods without starting a UI.
private class KartPadActivity {
    external fun nativeImportMii(database: ByteArray, mii: ByteArray): ByteArray
    external fun nativeListMiis(database: ByteArray): Array<String>
}

private fun testExportedMiiImport(fixtures: File) {
    val root = Files.createTempDirectory("kartpad-mii-import-test-").toFile()
    try {
        val database = File(root, "KartPad/NAND/shared2/menu/FaceLib/RFL_DB.dat")
        database.parentFile.mkdirs()
        val original = File(fixtures, "mii.dat").readBytes()
        database.writeBytes(original)
        val exported = original.copyOfRange(4, 78).apply {
            this[0] = (this[0].toInt() or 0x80).toByte() // RFL padding0
            this[0x1b] = 2 // A distinct synthetic creation ID.
        }
        val activity = KartPadActivity()
        val imported = activity.nativeImportMii(KartPadMiiStorage.readWorking(root), exported)
        check(activity.nativeListMiis(imported).size == 6) // Two three-field records.
        check(imported.copyOfRange(78, 152).contentEquals(exported))
        KartPadMiiStorage.writePending(root, imported)
        check(database.readBytes().contentEquals(original))
        check(KartPadMiiStorage.hasPending(root))
        check(KartPadMiiStorage.applyPending(root) == null)
        check(!KartPadMiiStorage.hasPending(root))
        check(database.readBytes().contentEquals(imported))
        val backup = File(root, "KartPad/MiiBackups").listFiles()!!.single()
        check(backup.readBytes().contentEquals(original))
        for (invalid in listOf(exported.copyOf(73), exported.copyOf().apply { this[0x16] = 128.toByte() })) {
            val error = runCatching { activity.nativeImportMii(imported, invalid) }.exceptionOrNull()
            check(error is IllegalArgumentException)
            check(database.readBytes().contentEquals(imported))
            check(!KartPadMiiStorage.hasPending(root))
        }
        println("Android Mii import passed: padding bit, JNI list/import, staged apply, original backup, invalid-file rejection")
    } finally {
        root.deleteRecursively() // Only this test's newly-created synthetic directory.
    }
}

private fun testConsoleIdentityRecovery(fixtures: File) {
    val root = createTempDir(prefix = "kartpad-console-recovery-")
    try {
        val app = File(root, "KartPad").apply { mkdirs() }
        File(app, "NAND").mkdirs()
        File(app, "NAND/.mkw_recompiled_managed_nand").writeText("version=1\n")
        val legacy = File(app, "ConsoleIdentity.txt").apply { writeText("serial=123456789\n") }
        val encoder = KartPadIdentityStorage::class.java.getDeclaredMethod("nativeConsoleSettings", String::class.java).apply { isAccessible = true }
        fun encode(s: String) = encoder.invoke(KartPadIdentityStorage, s) as ByteArray
        val wrong = encode("987654321")
        val right = encode("123456789")
        val settings = File(app, "NAND/title/00000001/00000002/data/setting.txt").apply { parentFile.mkdirs(); writeBytes(wrong) }
        val save = File(app, KartPadIdentityStorage.paths.getValue("original")).apply { parentFile.mkdirs() }
        // No native edit is requested: arbitrary full-length save bytes must survive exactly.
        val progress = ByteArray(KartPadSaveStorage.SAVE_BYTES) { (it % 251).toByte() }
        save.writeBytes(progress)
        KartPadIdentityStorage.stageConsoleRecovery(root)
        check(settings.readBytes().contentEquals(wrong))
        AtomicFile.silentFailSuffix = "/original.before"
        check(KartPadIdentityStorage.applyConsoleRecovery(root) != null) { "console/backup: failed backup reported success" }
        check(settings.readBytes().contentEquals(wrong) && save.readBytes().contentEquals(progress))
        check(File(app, "PendingConsoleIdentityRecovery.json").isFile)
        AtomicFile.silentFailSuffix = "/verified.json"
        check(KartPadIdentityStorage.applyConsoleRecovery(root) != null) { "console/completion: failed marker reported success" }
        check(settings.readBytes().contentEquals(right) && save.readBytes().contentEquals(progress))
        check(File(app, "PendingConsoleIdentityRecovery.json").isFile)
        AtomicFile.silentFailSuffix = null
        check(KartPadIdentityStorage.applyConsoleRecovery(root) == null)
        check(settings.readBytes().contentEquals(right))
        check(save.readBytes().contentEquals(progress))
        check(legacy.readText() == "serial=123456789\n")
        val backup = File(app, "IdentityBackups").listFiles()!!.single()
        check(File(backup, "settings.before").readBytes().contentEquals(wrong))
        check(File(backup, "original.before").readBytes().contentEquals(progress))
        check(File(backup, "verified.json").isFile)
        check(KartPadIdentityStorage.applyConsoleRecovery(root) == null)
        check(runCatching { KartPadIdentityStorage.stageConsoleRecovery(root) }.isFailure)
        settings.writeBytes(wrong)
        KartPadIdentityStorage.stageConsoleRecovery(root)
        settings.writeBytes(encode("222222222"))
        check(KartPadIdentityStorage.applyConsoleRecovery(root) != null)
        check(settings.readBytes().contentEquals(encode("222222222")))
        settings.writeBytes(wrong.copyOf().apply { this[200] = 1 })
        check(runCatching { KartPadIdentityStorage.stageConsoleRecovery(root) }.isFailure)
        println("Console recovery passed: registered serial, backup, exact save preservation, idempotence and changed-settings rejection")
    } finally { AtomicFile.silentFailSuffix = null; root.deleteRecursively() }
}

fun main(args: Array<String>) {
    testRatingCompanion()
    testRatingStorage()
    System.load(args[0])
    testConsoleIdentityRecovery(File(args[1]))
    val fixtures = File(args[1])
    testIdentityMiiPublication(fixtures)
    testExportedMiiImport(fixtures)
    testSaveProfiles(fixtures)
    val root = Files.createTempDirectory("kartpad-identity-test-").toFile()
    fun path(profile: String) = File(root, "KartPad/${KartPadIdentityStorage.paths.getValue(profile)}")
    for (profile in KartPadIdentityStorage.paths.keys) {
        path(profile).parentFile.mkdirs()
        File(fixtures, if (profile == "mii") "mii.dat" else "save.dat").copyTo(path(profile))
    }
    fun record(profile: String) = KartPadIdentityStorage.records(root, profile == "mii").first { it.profile == profile }
    fun crc(bytes: ByteArray) {
        val crc = CRC32().apply { update(bytes, 0, 0x27ffc) }.value
        repeat(4) { bytes[0x27ffc + it] = (crc shr (24 - it * 8)).toByte() }
    }
    val original = path("original").readBytes()
    KartPadIdentityStorage.stage(root, record("original"), false, "Racer")
    check(path("original").readBytes().contentEquals(original))
    check(runCatching { KartPadIdentityStorage.stage(root, record("original"), false, "Other") }.isFailure)
    val latest = original.copyOf().apply { this[8 + 0x90] = 0x44; crc(this) }
    path("original").writeBytes(latest)
    // A newer appearance edit must survive a previously scheduled license rename.
    val latestMii = path("mii").readBytes().apply {
        this[4 + 0x20] = (this[4 + 0x20].toInt() xor 1).toByte()
        var crc = 0
        for (index in 0 until 0x1f1de) {
            crc = crc xor ((this[index].toInt() and 255) shl 8)
            repeat(8) { crc = if (crc and 0x8000 != 0) (crc shl 1) xor 0x1021 else crc shl 1 }
            crc = crc and 0xffff
        }
        this[0x1f1de] = (crc shr 8).toByte()
        this[0x1f1df] = crc.toByte()
    }
    path("mii").writeBytes(latestMii)
    AtomicFile.failSuffix = "/FaceLib/RFL_DB.dat"
    check(KartPadIdentityStorage.applyPending(root) != null)
    check(KartPadIdentityStorage.hasPending(root))
    check(record("original").name == "Racer")
    check(path("mii").readBytes().contentEquals(latestMii))
    AtomicFile.failSuffix = null
    check(KartPadIdentityStorage.applyPending(root) == null)
    check(record("original").name == "Racer")
    check(record("mii").name == "Racer")
    val renamedMii = path("mii").readBytes()
    for (i in latestMii.indices) if (i !in 6 until 26 && i !in 0x1f1de..0x1f1df)
        check(latestMii[i] == renamedMii[i])
    val renamed = path("original").readBytes()
    for (i in latest.indices) if (i !in (8 + 0x14) until (8 + 0x14 + 20) && i !in 0x27ffc..0x27fff)
        check(latest[i] == renamed[i])
    check(record("retro_rewind").name == "Player")
    check(path("retro_rewind").readBytes().contentEquals(original))
    check(path("retro_rewind_separate").readBytes().contentEquals(original))
    KartPadIdentityStorage.stage(root, record("mii"), false, "Both")
    AtomicFile.failSuffix = "/data/rksys.dat"
    check(KartPadIdentityStorage.applyPending(root) != null)
    check(KartPadIdentityStorage.hasPending(root))
    AtomicFile.failSuffix = null
    check(KartPadIdentityStorage.applyPending(root) == null)
    check(KartPadIdentityStorage.records(root, false).all { it.name == "Both" })
    check(record("mii").name == "Both")
    val beforeDelete = path("original").readBytes()
    val miiBeforeDelete = path("mii").readBytes()
    KartPadIdentityStorage.stage(root, record("original"), true, "")
    check(KartPadIdentityStorage.applyPending(root) == null)
    check(KartPadIdentityStorage.records(root, false).count { it.profile == "original" } == 1)
    val deleted = path("original").readBytes()
    check(path("mii").readBytes().contentEquals(miiBeforeDelete))
    check(beforeDelete.copyOfRange(8 + 0x8cc0, 8 + 2 * 0x8cc0)
        .contentEquals(deleted.copyOfRange(8 + 0x8cc0, 8 + 2 * 0x8cc0)))
    check(runCatching { KartPadIdentityStorage.stage(root, record("mii"), false, "01234567890") }.isFailure)
    check(!KartPadIdentityStorage.hasPending(root))
    check(File(root, "KartPad/IdentityBackups").listFiles()!!.size == 3)
    // Missing linked Mii must be selected explicitly; only target identity + CRC may change.
    val orphan = original.copyOf().apply { this[8 + 0x28] = (this[8 + 0x28].toInt() xor 1).toByte(); crc(this) }
    path("original").writeBytes(orphan)
    val missing = record("original")
    check(missing.missingLinkedMii)
    val selectedMii = record("mii")
    check(runCatching { KartPadIdentityStorage.stageLicenseMii(root, missing,
        selectedMii.copy(createId = missing.createId)) }.isFailure)
    check(!KartPadIdentityStorage.hasPending(root))
    val otherSave = path("retro_rewind").readBytes()
    val databaseBefore = path("mii").readBytes()
    KartPadIdentityStorage.stageLicenseMii(root, missing, selectedMii)
    check(path("mii").delete())
    check(KartPadIdentityStorage.applyPending(root) != null)
    check(KartPadIdentityStorage.hasPending(root))
    check(path("original").readBytes().contentEquals(orphan))
    path("mii").writeBytes(databaseBefore)
    orphan[8 + 0x90] = 0x37; crc(orphan)
    path("original").writeBytes(orphan)
    check(KartPadIdentityStorage.applyPending(root) == null)
    val repaired = path("original").readBytes()
    check(!record("original").missingLinkedMii && record("original").name == selectedMii.name)
    for (i in orphan.indices) if (i !in 28 until 56 && i !in 0x27ffc..0x27fff) check(orphan[i] == repaired[i])
    check(path("mii").readBytes().contentEquals(databaseBefore))
    check(path("retro_rewind").readBytes().contentEquals(otherSave))
    println("Android identity passed: JNI semantics, latest-progress preservation, license/Mii rename parity, profile and delete isolation, linked profiles, interrupted transaction recovery, backups, invalid names")
    root.deleteRecursively() // Only this test's newly-created synthetic directory.
}
