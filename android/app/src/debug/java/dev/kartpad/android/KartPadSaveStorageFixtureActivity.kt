package dev.kartpad.android

import android.app.Activity
import android.os.Bundle
import android.util.Log
import java.io.File
import java.util.zip.CRC32

/** Debug-only, synthetic validation of save export/stage/apply/backup storage. */
internal class KartPadSaveStorageFixtureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState != null) return
        Thread {
            val root = File(cacheDir, "save-storage-fixture")
            runCatching { runFixture(root) }
                .onSuccess {
                    Log.i(
                        TAG,
                        "A6 save storage passed export=validated restore=staged " +
                            "active=replaced backup=preserved corrupt=rejected",
                    )
                }
                .onFailure { Log.e(TAG, "A6 save storage failed", it) }
            root.deleteRecursively()
            runOnUiThread { finish() }
        }.start()
    }

    private fun runFixture(root: File) {
        check(!root.exists() || root.deleteRecursively()) { "fixture cleanup failed" }
        val original = validSave(0x31)
        val replacement = validSave(0x72)
        val active = KartPadSaveStorage.active(root)
        check(active.parentFile?.mkdirs() == true) { "active save directory unavailable" }
        active.writeBytes(original)

        check(KartPadSaveStorage.readActive(root).contentEquals(original)) {
            "validated export did not return the active save"
        }
        KartPadSaveStorage.writePending(root, replacement)
        check(KartPadSaveStorage.hasPending(root)) { "restore was not staged" }
        check(KartPadSaveStorage.applyPending(root) == null) { "staged restore failed" }
        check(!KartPadSaveStorage.hasPending(root)) { "staged restore was not finalized" }
        check(KartPadSaveStorage.readActive(root).contentEquals(replacement)) {
            "replacement did not become active"
        }

        val backups = File(root, "KartPad/SaveBackups").listFiles()?.toList().orEmpty()
        check(backups.size == 1 && backups.single().readBytes().contentEquals(original)) {
            "prior active save was not retained exactly once"
        }
        val corrupt = replacement.copyOf().also { it[0x100] = (it[0x100].toInt() xor 1).toByte() }
        check(runCatching { KartPadSaveStorage.validate(corrupt) }.isFailure) {
            "checksum-corrupt save was accepted"
        }
    }

    private fun validSave(marker: Int): ByteArray {
        val data = ByteArray(KartPadSaveStorage.SAVE_BYTES)
        "RKSD0006".toByteArray(Charsets.US_ASCII).copyInto(data)
        data[0x100] = marker.toByte()
        val crcOffset = 0x27ffc
        val crc = CRC32().apply { update(data, 0, crcOffset) }.value
        data[crcOffset] = (crc ushr 24).toByte()
        data[crcOffset + 1] = (crc ushr 16).toByte()
        data[crcOffset + 2] = (crc ushr 8).toByte()
        data[crcOffset + 3] = crc.toByte()
        return data
    }

    private companion object {
        const val TAG = "KartPadFixture"
    }
}
