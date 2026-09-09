package android.content
class Context(val filesDir: java.io.File) { val contentResolver = Resolver() }
class Resolver {
    fun openOutputStream(uri: android.net.Uri, mode: String): java.io.OutputStream? {
        check(mode == "w")
        return uri.file.outputStream()
    }
}
