package android.content
import android.app.ActivityManager
class Context(val manager: ActivityManager?, val filesDir: java.io.File = java.io.File("unused-host-files")) {
    val contentResolver = ContentResolver()
    val packageName = "dev.kartpad.android"
    fun <T> getSystemService(type: Class<T>): T? = type.cast(manager)
}

class ContentResolver { fun openOutputStream(uri: android.net.Uri, mode: String): java.io.OutputStream? = java.io.File(uri.path).outputStream() }
