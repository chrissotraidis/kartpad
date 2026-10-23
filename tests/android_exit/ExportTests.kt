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
 testSessionProfiles()
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

private fun testSessionProfiles() {
 val root = Files.createTempDirectory("kartpad-session-profile-").toFile()
 try {
  val context = Context(ActivityManager(), root)
  fun session(id: String, contents: String, modified: Long): File {
   val directory = File(root, "KartPad/Logs/$id").apply { mkdirs() }
   return File(directory, "console.log").apply { writeText(contents); check(setLastModified(modified)) }
  }
  val retroMarker = "[runtime] Selected translated function profile 'retro_rewind'"
  val oldConsole = session("base_123_pid42", "OLD-BUILD\n$retroMarker\r\n", 1000)
  // Neither the newer session nor the root health history describes the old run.
  session("retro_rewind_456_pid43", "[runtime] Selected translated function profile 'base'\n", 2000)
  File(oldConsole.parentFile.parentFile, "android-health.log").writeText("{\"profile\":\"base\"}")
  session("retro_rewind_missing", "OLD-BUILD\n", 1)
  session("base_unknown", "[runtime] Selected translated function profile 'other'\n", 1)
  session("base_late", "x".repeat(16 * 1024) + "\n$retroMarker\n", 1)
  // A line cut by the header boundary is not an authoritative profile record,
  // even if its closing quote happens to land on the last retained byte.
  session("base_truncated", "\n".repeat(16 * 1024 - retroMarker.length) + retroMarker + "\nTAIL", 1)
  val linked = File(oldConsole.parentFile.parentFile, "linked").apply { mkdirs() }
  Files.createSymbolicLink(File(linked, "console.log").toPath(), oldConsole.toPath())
  val sessions = KartPadDiagnosticExport.sessions(context)
  check(sessions.first().id == "retro_rewind_456_pid43")
  check(sessions.first().profileLabel == "Original Mario Kart Wii")
  val historical = sessions.single { it.id == "base_123_pid42" }
  check(historical.profile == "retro_rewind" && historical.profileLabel == "Retro Rewind")
  check(sessions.filter { it.modified == 1L }.all { it.profile == null && it.profileLabel == "Profile unavailable" })
  check(sessions.none { it.id == "linked" })

  val text = File(root, "profile.txt")
  KartPadDiagnosticExport.writeText(context, Uri(text.path), historical.id)
  check(text.readText().contains("Selected session: base_123_pid42;"))
  check(text.readText().contains("Selected session profile: Retro Rewind"))
  val zip = File(root, "profile.zip")
  KartPadDiagnosticExport.write(context, Uri(zip.path), historical.id)
  ZipFile(zip).use { archive ->
   val readme = archive.getInputStream(archive.getEntry("README.txt")).bufferedReader().readText()
   check(readme.contains("Selected session profile: Retro Rewind"))
   check(archive.getEntry("Logs/base_123_pid42/console.log") != null)
   check(archive.getEntry("Logs/retro_rewind_456_pid43/console.log") == null)
  }
  KartPadDiagnosticExport.writeText(context, Uri(text.path), "retro_rewind_missing")
  check(text.readText().contains("Selected session profile: Profile unavailable"))
 } finally { root.deleteRecursively() }
 println("Session profiles passed: selected startup header, mixed history, bounded/unknown records and unchanged storage IDs")
}
