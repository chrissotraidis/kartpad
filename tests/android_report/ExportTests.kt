package dev.kartpad.android

import android.content.Context
import android.net.Uri
import java.io.File
import java.nio.file.Files
import java.util.zip.ZipFile

fun main() {
    val root = Files.createTempDirectory("kartpad-report-export-").toFile()
    try {
        val files = File(root, "files").apply { mkdirs() }
        val logs = File(files, "KartPad/Logs/session").apply { mkdirs() }
        val privateSave = File(files, "KartPad/NAND/private.txt").apply {
            parentFile.mkdirs(); writeText("PRIVATE_NAND_MUST_NOT_EXPORT")
        }
        Files.createSymbolicLink(File(logs, "linked-save.txt").toPath(), privateSave.toPath())
        File(logs, "memory.bin").writeText("PRIVATE_MEMORY_MUST_NOT_EXPORT")
        for (i in 0..12) File(logs, "sample-$i.log").apply {
            writeText("sample-$i"); setLastModified(100000L + i)
        }
        val large = File(logs, "large.log")
        large.outputStream().use { out ->
            out.write("OLD_PREFIX_NOT_IN_TAIL".toByteArray())
            val chunk = ByteArray(1024 * 1024) { 'x'.code.toByte() }
            repeat(5) { out.write(chunk) }
        }
        large.setLastModified(200000)
        val zipFile = File(root, "export.zip")
        KartPadDiagnosticExport.write(Context(files), Uri(zipFile))
        ZipFile(zipFile).use { zip ->
            val entries = zip.entries().asSequence().toList()
            check(entries.size == 15) // 12 bounded logs and 3 metadata entries
            check(entries.none { "linked-save" in it.name || "memory.bin" in it.name || "NAND" in it.name })
            check(zip.getEntry("Logs/session/sample-0.log") == null)
            check(zip.getEntry("Logs/session/sample-1.log") == null)
            check(zip.getEntry("Logs/session/large.log").size == 4L * 1024 * 1024)
            for (entry in entries) {
                val text = zip.getInputStream(entry).bufferedReader().readText()
                check(!text.contains("PRIVATE_NAND") && !text.contains("PRIVATE_MEMORY") && !text.contains("OLD_PREFIX"))
            }
        }
        val emptyFiles = File(root, "empty").apply { mkdirs() }
        KartPadDiagnosticExport.write(Context(emptyFiles), Uri(zipFile))
        ZipFile(zipFile).use { check(it.size() == 3) }
        println("PASS: bounded private export, symlink/save exclusion, tail limit and empty logs")
    } finally { root.deleteRecursively() }
}
