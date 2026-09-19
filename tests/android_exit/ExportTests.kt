package dev.kartpad.android
import android.content.Context
import android.app.ActivityManager
import android.os.Build
import android.net.Uri
import java.io.File
import java.nio.file.Files
import java.util.zip.ZipFile
import org.json.JSONObject
object KartPadReportContext { fun snapshot(context: Context, profile: String?) = JSONObject().put("fixture",true) }
fun testDiagnosticExport() {
 val root = Files.createTempDirectory("kartpad-export-").toFile()
 try {
  Build.VERSION.SDK_INT=31
  val context=Context(ActivityManager(),root)
  val text=File(root,"report.txt"); val zip=File(root,"report.zip")
  // Early native failure: no session directory must still export OS evidence.
  KartPadDiagnosticExport.writeText(context,Uri(text.path),null)
  check(text.readText().contains("no runtime session"))
  check(text.readText().contains("process-exits.json"))
  KartPadDiagnosticExport.write(context,Uri(zip.path))
  ZipFile(zip).use { check(it.getEntry("process-exits.json")!=null); check(it.getEntry("OS-exits/manifest.json")!=null) }
  val logs=File(root,"KartPad/Logs/base_123_pid42");logs.mkdirs()
  File(logs,"console.log").writeText("BUILD-HEADER\n"+"x".repeat(300000)+"\nRECENT-TAIL")
  File(logs.parentFile,"android-health.log").writeText("z".repeat(300000)+"\nHEALTH-PID42")
  File(logs,"mem1.bin").writeText("PRIVATE-MEMORY")
  File(logs,"save.dat").writeText("PRIVATE-SAVE")
  val private=File(root,"private.txt");private.writeText("PRIVATE-SYMLINK")
  Files.createSymbolicLink(File(logs,"crash_link.txt").toPath(),private.toPath())
  KartPadDiagnosticExport.writeText(context,Uri(text.path),logs.name)
  val report=text.readText()
  check(report.contains("BUILD-HEADER") && report.contains("RECENT-TAIL") && report.contains("middle omitted"))
  check(!report.contains("PRIVATE-"))
  check(report.contains("HEALTH-PID42"))
  check(!report.contains("z".repeat(262145)))
  check(runCatching { KartPadDiagnosticExport.writeText(context,Uri(text.path),"../private.txt") }.isFailure)
  KartPadDiagnosticExport.write(context,Uri(zip.path),logs.name)
  ZipFile(zip).use { archive -> check(archive.entries().asSequence().none { it.name.contains("mem1") || it.name.contains("save.dat") || it.name.contains("crash_link") }) }
   val health=File(logs.parentFile,"android-health.log");health.delete()
  Files.createSymbolicLink(health.toPath(),private.toPath())
  KartPadDiagnosticExport.writeText(context,Uri(text.path),logs.name)
  check(!text.readText().contains("PRIVATE-SYMLINK"))
 } finally { root.deleteRecursively() }
 println("Diagnostic export passed: no-session OS evidence, bounded header/tail, private file and symlink exclusion")
}
