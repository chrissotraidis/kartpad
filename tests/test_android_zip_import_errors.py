"""Exercise the real ZIP transaction and UI error formatter with synthetic input."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "android/app/src/main/java/dev/kartpad/android"


class ZipImportErrorTests(unittest.TestCase):
    def test_corruption_storage_and_provider_failures_preserve_installed_data(self):
        cache = Path.home() / ".gradle/caches/modules-2/files-2.1"

        def jar(relative):
            return next((p for p in (cache / relative).glob("*/*.jar")
                         if not p.name.endswith(("-sources.jar", "-javadoc.jar"))), None)

        dependencies = [jar(p) for p in (
            "org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.21",
            "org.jetbrains.kotlin/kotlin-stdlib/2.2.21",
            "org.jetbrains/annotations/13.0",
            "org.jetbrains.kotlin/kotlin-reflect/2.2.0",
            "org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0",
        )]
        java = shutil.which("java")
        if not java or not all(dependencies):
            self.skipTest("Requires Java and the project's cached Kotlin compiler")
        with tempfile.TemporaryDirectory(prefix="kartpad-zip-errors-") as temporary:
            work = Path(temporary)
            stubs = {
                "ContentResolver.kt": '''package android.content
abstract class ContentResolver {
 abstract fun openInputStream(uri: android.net.Uri): java.io.InputStream?
 fun query(uri: android.net.Uri, columns: Array<String>, selection: String?, args: Array<String>?, sort: String?): Cursor? = error("unused")
}
class Cursor: java.io.Closeable { fun moveToNext()=false; fun getString(index:Int)=""; override fun close(){} }
''',
                "Uri.kt": "package android.net\nclass Uri\n",
                "DocumentsContract.kt": '''package android.provider
object DocumentsContract {
 object Document { const val MIME_TYPE_DIR="dir"; const val COLUMN_DOCUMENT_ID="id"; const val COLUMN_DISPLAY_NAME="name"; const val COLUMN_MIME_TYPE="mime" }
 fun getTreeDocumentId(uri:android.net.Uri)=""
 fun buildChildDocumentsUriUsingTree(uri:android.net.Uri, id:String)=uri
 fun buildDocumentUriUsingTree(uri:android.net.Uri, id:String)=uri
}
''',
                "Storage.kt": '''package android.util
object Log { fun w(tag:String, message:String, error:Throwable)=0 }
class AtomicFile(val baseFile:java.io.File) {
 fun startWrite()=java.io.FileOutputStream(baseFile)
 fun finishWrite(stream:java.io.FileOutputStream){stream.close()}
 fun failWrite(stream:java.io.FileOutputStream){stream.close()}
}
''',
                "Errno.kt": '''package android.system
class ErrnoException(val functionName:String, val errno:Int): Exception("$functionName failed: errno $errno")
object OsConstants { const val ENOSPC=28 }
''',
                "Unused.kt": '''package dev.kartpad.android
object BuildConfig { const val DISC_IMAGE_IMPORT=false }
object KartPadDiscImageImporter {
 fun extract(resolver:android.content.ContentResolver, uri:android.net.Uri, staging:java.io.File, files:java.io.File):Unit=error("unused")
}
''',
            }
            for name, contents in stubs.items():
                (work / name).write_text(contents)
            # Compile the actual formatter as well; no copied error-classification logic.
            activity = (SOURCE / "KartPadGameDataActivity.kt").read_text()
            formatter = activity[activity.index("    private fun safeError("):activity.index("    companion object {")]
            (work / "Formatter.kt").write_text(
                "package dev.kartpad.android\nobject Formatter {\n" +
                formatter.replace("private fun safeError", "fun safeError") + "}\n")
            storage = Path(os.environ.get("KARTPAD_ZIP_TEST_SOURCE", SOURCE / "KartPadGameDataStorage.kt"))
            result = subprocess.run([
                java, "-cp", os.pathsep.join(map(str, dependencies)),
                "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler", "-no-stdlib", "-no-reflect",
                "-jvm-target", "17", "-classpath", str(dependencies[1]),
                "-d", str(work / "tests.jar"), str(storage),
                str(ROOT / "tests/android_import/ZipImportErrors.kt"),
                *map(str, work.glob("*.kt")),
            ], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            result = subprocess.run([
                java, "-cp", os.pathsep.join(map(str, [work / "tests.jar", dependencies[1]])),
                "dev.kartpad.android.ZipImportErrorsKt", str(work / "fixtures"),
            ], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
