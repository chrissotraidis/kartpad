package dev.kartpad.android

import org.json.JSONObject
import org.json.JSONArray
import java.io.File
import java.security.MessageDigest
import java.util.UUID

/** Stage one intent, then apply to the latest save at cold launch, with recoverable backups. */
internal object KartPadIdentityStorage {
    val paths = linkedMapOf(
        "original" to "NAND/title/00010004/524d4350/data/rksys.dat",
        "retro_rewind" to "RetroRewind/riivolution/save/RetroWFC/RMCP/rksys.dat",
        "retro_rewind_separate" to "RetroRewind/riivolution/save/RetroWFC2/RMCP/rksys.dat",
        "mii" to "NAND/shared2/menu/FaceLib/RFL_DB.dat",
    )
    val titles = mapOf("original" to "Original Mario Kart Wii", "retro_rewind" to "Retro Rewind",
        "retro_rewind_separate" to "Retro Rewind (Separate Save)", "mii" to "Mii")
    private fun root(files: File) = File(files, "KartPad")
    private fun journal(files: File) = File(root(files), "PendingAndroidIdentity.json")
    private fun pointer(files: File) = File(root(files), "PendingAndroidIdentityTransaction")
    private fun target(files: File, profile: String) = File(root(files), paths.getValue(profile))
    private fun readTarget(files: File, profile: String): ByteArray {
        val file = target(files, profile)
        require(file.length() == if (profile == "mii") 779968L else KartPadSaveStorage.SAVE_BYTES.toLong()) {
            "Identity data has an unexpected size."
        }
        return file.readBytes()
    }
    private fun write(file: File, bytes: ByteArray) = KartPadAtomicFile.write(file, bytes)
    private fun hash(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes)
    fun hasPending(files: File) = journal(files).isFile || pointer(files).isFile
    data class Record(val profile: String, val slot: Int, val name: String, val createId: String, val missingLinkedMii: Boolean = false)
    fun records(files: File, miis: Boolean): List<Record> {
        val linkedIds = if (!miis && target(files, "mii").isFile)
            nativeRecords(readTarget(files, "mii"), true).toList().chunked(3).map { it[2] }.toSet()
        else emptySet()
        return paths.keys.filter { (it == "mii") == miis && target(files, it).isFile }
            .flatMap { profile ->
                nativeRecords(readTarget(files, profile), miis).toList().chunked(3).map {
                    Record(profile, it[0].toInt(), it[1], it[2], !miis && it[2] !in linkedIds)
                }
            }
    }
    fun stage(files: File, record: Record, delete: Boolean, name: String) {
        require(!hasPending(files)) { "Apply the pending identity change by fully closing and reopening KartPad before editing again." }
        require(!KartPadSaveStorage.hasPending(files) && !KartPadMiiStorage.hasPending(files)) {
            "Apply the pending save or Mii import first."
        }
        require(!delete || record.profile != "mii") { "Use the appearance manager for unused Miis." }
        val request = JSONObject().put("profile", record.profile).put("slot", record.slot)
            .put("createId", record.createId).put("delete", delete).put("name", name)
        // Validate immediately, but never stage an old whole-save snapshot.
        replacements(files, request)
        write(journal(files), request.toString().toByteArray())
    }
    fun stageLicenseMii(files: File, record: Record, mii: Record) {
        require(record.profile != "mii" && mii.profile == "mii") { "Choose a license and an existing Mii." }
        require(!hasPending(files) && !KartPadSaveStorage.hasPending(files) && !KartPadMiiStorage.hasPending(files)) {
            "Fully close and reopen KartPad to apply pending changes first."
        }
        val request = JSONObject().put("profile", record.profile).put("slot", record.slot)
            .put("createId", record.createId).put("delete", false).put("name", "")
            .put("miiSlot", mii.slot).put("miiCreateId", mii.createId)
        replacements(files, request)
        write(journal(files), request.toString().toByteArray())
    }
    private fun replacements(files: File, request: JSONObject): Map<String, ByteArray> {
        val profile = request.getString("profile")
        require(paths.containsKey(profile)) { "Unknown identity profile." }
        val id = request.getString("createId")
        val slot = request.getInt("slot")
        val name = request.getString("name").toByteArray(Charsets.UTF_16BE)
        val delete = request.getBoolean("delete")
        if (request.has("miiSlot")) {
            require(profile != "mii" && !delete) { "Invalid license Mii change." }
            val selected = records(files, true).firstOrNull {
                it.slot == request.getInt("miiSlot") && it.createId == request.getString("miiCreateId")
            } ?: error("The selected Mii changed. Reopen Player Identity and choose it again.")
            val selectedId = selected.createId.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
            return mapOf(profile to nativeEdit(readTarget(files, profile), 4, slot, id,
                selectedId + selected.name.toByteArray(Charsets.UTF_16BE)))
        }
        val result = linkedMapOf(profile to nativeEdit(readTarget(files, profile),
            if (profile == "mii") 2 else if (delete) 1 else 0, slot, id, name))
        if (profile == "mii") paths.keys.filter { it != "mii" && target(files, it).isFile }.forEach {
            result[it] = nativeEdit(readTarget(files, it), 3, slot, id, name)
        }
        else if (!delete && target(files, "mii").isFile) {
            // Match Apple's license rename: keep the selected license and its Mii
            // in sync, without directly rewriting other profiles' saves.
            val database = readTarget(files, "mii")
            val matching = nativeRecords(database, true).toList().chunked(3)
                .firstOrNull { it[2] == id }
            if (matching != null) result["mii"] = nativeEdit(database, 2, matching[0].toInt(), id, name)
        }
        return result
    }
    /** Called before SDL starts. Interrupted multi-file edits finish before guest writes resume. */
    fun applyPending(files: File): String? = runCatching {
        if (!hasPending(files)) return null
        if (!pointer(files).isFile) {
            require(journal(files).length() in 1..4096) { "Invalid pending identity request." }
            val changes = replacements(files, JSONObject(journal(files).readText()))
            val name = UUID.randomUUID().toString()
            val backup = File(root(files), "IdentityBackups/$name")
            val profiles = JSONArray()
            changes.forEach { (profile, bytes) ->
                write(File(backup, "$profile.before"), readTarget(files, profile))
                write(File(backup, "$profile.after"), bytes)
                profiles.put(profile)
            }
            write(File(backup, "profiles.json"), profiles.toString().toByteArray())
            write(pointer(files), name.toByteArray())
        }
        val name = pointer(files).readText()
        require(runCatching { UUID.fromString(name).toString() == name }.getOrDefault(false))
        val backup = File(root(files), "IdentityBackups/$name")
        val profiles = JSONArray(File(backup, "profiles.json").readText())
        val writes = (0 until profiles.length()).associate { index ->
            val profile = profiles.getString(index)
            require(paths.containsKey(profile))
            val before = File(backup, "$profile.before").readBytes()
            val after = File(backup, "$profile.after").readBytes()
            val current = readTarget(files, profile)
            require(hash(current).contentEquals(hash(before)) || hash(current).contentEquals(hash(after))) {
                "Identity data changed during recovery; backups were preserved."
            }
            if (profile == "mii") require(KartPadMiiStorage.isValidDatabase(after))
            else KartPadSaveStorage.validate(after)
            profile to after
        }
        writes.forEach { (profile, bytes) -> write(target(files, profile), bytes) }
        if (journal(files).exists()) check(journal(files).delete())
        check(pointer(files).delete()) // Keep both snapshots as private recovery backups.
        null
    }.getOrElse { "Pending identity changes could not be applied safely. Existing backups are retained." }

    private fun consoleRecovery(files: File) = File(root(files), "PendingConsoleIdentityRecovery.json")
    private fun consoleSettings(files: File) = File(root(files), "NAND/title/00000001/00000002/data/setting.txt")
    private fun legacyConsole(files: File) = File(root(files), "ConsoleIdentity.txt")
    private fun digest(bytes: ByteArray) = hash(bytes).joinToString("") { "%02x".format(it) }

    /** Explicit recovery for the upstream candidates that generated a new console serial. */
    fun stageConsoleRecovery(files: File) {
        require(!hasPending(files) && !KartPadSaveStorage.hasPending(files) && !KartPadMiiStorage.hasPending(files)) {
            "Apply pending save or identity changes first."
        }
        val replacement = recoveredConsoleSettings(files)
        val current = consoleSettings(files).readBytes()
        require(!replacement.contentEquals(current)) { "The previous console identity is already active." }
        write(consoleRecovery(files), JSONObject()
            .put("settings", digest(current)).put("legacy", digest(legacyConsole(files).readBytes()))
            .put("transaction", UUID.randomUUID().toString()).toString().toByteArray())
    }

    private fun recoveredConsoleSettings(files: File): ByteArray {
        require(File(root(files), "NAND/.mkw_recompiled_managed_nand").isFile) { "This is not a managed KartPad NAND." }
        val legacy = legacyConsole(files)
        require(legacy.length() == 17L) { "Previous console identity is missing or invalid." }
        val line = legacy.readText().trimEnd('\n')
        require(Regex("serial=[0-9]{9}").matches(line) && line != "serial=000000000") { "Previous console identity is invalid." }
        val current = consoleSettings(files)
        require(current.length() == 256L) { "Current console settings are missing or invalid." }
        val bytes = current.readBytes()
        var key = 0x73b5dbfa
        val decoded = StringBuilder()
        for (byte in bytes) {
            if (byte == 0.toByte()) break
            decoded.append(((byte.toInt() and 255) xor (key and 255)).toChar())
            key = Integer.rotateLeft(key, 1)
        }
        val currentSerial = Regex("(?:^|[\r\n])SERNO=([0-9]{9})(?:[\r\n]|$)").find(decoded)?.groupValues?.get(1)
            ?: error("Current console settings have no valid serial.")
        require(nativeConsoleSettings(currentSerial).contentEquals(bytes)) {
            "These settings differ from the generated candidate identity. Automatic recovery was stopped."
        }
        return nativeConsoleSettings(line.substring(7))
    }

    /** No saves are edited; settings and save backups are retained for recovery. */
    fun applyConsoleRecovery(files: File): String? = runCatching {
        val requestFile = consoleRecovery(files)
        if (!requestFile.isFile) return null
        require(requestFile.length() in 1..4096)
        val request = JSONObject(requestFile.readText())
        val id = request.getString("transaction")
        require(UUID.fromString(id).toString() == id)
        require(digest(legacyConsole(files).readBytes()) == request.getString("legacy")) { "Previous console identity changed; recovery stopped." }
        val settings = consoleSettings(files)
        val replacement = recoveredConsoleSettings(files)
        val current = settings.readBytes()
        val backup = File(root(files), "IdentityBackups/console-$id")
        if (!current.contentEquals(replacement)) {
            require(digest(current) == request.getString("settings")) { "Console settings changed; recovery stopped." }
            write(File(backup, "settings.before"), current)
            write(File(backup, "settings.after"), replacement)
            write(File(backup, "ConsoleIdentity.txt"), legacyConsole(files).readBytes())
            val states = paths.filter { target(files, it.key).isFile }.mapValues { readTarget(files, it.key) }
            states.forEach { (profile, bytes) -> write(File(backup, "$profile.before"), bytes) }
            write(settings, replacement)
            require(settings.readBytes().contentEquals(replacement)) { "Console settings readback failed." }
            states.forEach { (profile, bytes) -> require(readTarget(files, profile).contentEquals(bytes)) { "Profile changed during identity recovery." } }
        } else {
            require(File(backup, "settings.before").isFile && File(backup, "settings.after").readBytes().contentEquals(replacement))
        }
        write(File(backup, "verified.json"), JSONObject().put("restoredPreviousIdentity", true)
            .put("saveFilesUnchanged", true).toString().toByteArray())
        check(requestFile.delete())
        println("KartPadIdentity: Previous console identity restored; saved profiles unchanged; recovery backups retained")
        null
    }.getOrElse { it.message ?: "Console identity recovery failed; backups were retained." }

    private external fun nativeConsoleSettings(serial: String): ByteArray

    private external fun nativeRecords(data: ByteArray, mii: Boolean): Array<String>
    private external fun nativeEdit(data: ByteArray, operation: Int, slot: Int, createId: String, name: ByteArray): ByteArray
}
