package android.util

import java.io.File
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/** Host test stand-in for Android's AtomicFile; permits a bounded publication fault. */
class AtomicFile(private val file: File) {
    val baseFile: File get() = file
    fun openRead(): java.io.FileInputStream {
        if (readFailSuffix?.let { file.path.endsWith(it) } == true) throw java.io.IOException("injected read failure")
        return file.inputStream()
    }
    private val temporary = File(file.path + ".new")
    fun startWrite(): FileOutputStream = FileOutputStream(temporary).also {
        android.system.Os.register(it.fd, file.path)
    }
    fun finishWrite(stream: FileOutputStream) {
        if (silentSyncFailureSuffix?.let { file.path.endsWith(it) } != true) stream.fd.sync()
        stream.close()
        if (failSuffix != null && file.path.endsWith(failSuffix!!)) throw java.io.IOException("injected")
        // Android's real finishWrite logs rename failures instead of throwing.
        if ((silentFailSuffix != null && file.path.endsWith(silentFailSuffix!!)) ||
            (silentBackupOnly && file.parentFile.name == "SaveBackups")) return
        Files.move(temporary.toPath(), file.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
    }
    fun failWrite(stream: FileOutputStream) { stream.close(); temporary.delete() }
    companion object { var failSuffix: String? = null; var silentFailSuffix: String? = null; var silentBackupOnly = false; var silentSyncFailureSuffix: String? = null; var readFailSuffix: String? = null }
}
