package dev.kartpad.android

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import android.util.AtomicFile
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.ZipInputStream

/** Crash-safe storage transaction for user-selected extracted RMCP01 game data. */
internal object KartPadGameDataStorage {
    private const val GAME_DATA = "GameData"
    private const val REMOVAL_MARKER = "RemoveGameDataOnNextLaunch"
    private const val MAX_DEPTH = 64
    private const val MAX_ENTRIES = 100_000
    private const val MAX_BYTES = 8L * 1024L * 1024L * 1024L
    private const val MAIN_DOL_SHA256 =
        "80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"
    private const val STATIC_R_SHA256 =
        "16d9d146112541fefea701ecb5bc1a496f9d50e4a752fbb5b6778e7c6399f67d"
    private const val MODIFIED_GAME_DATA =
        "This game data is modified (for example Wiimmfi-patched or pre-patched). Please use a clean RMCP01 dump."
    private const val DAMAGED_ZIP =
        "The zip is damaged or incomplete. Copy it to the phone again and retry."

    private val requiredPaths = listOf(
        "sys/boot.bin",
        "sys/bi2.bin",
        "sys/apploader.img",
        "sys/fst.bin",
        "sys/main.dol",
        "files/rel/StaticR.rel",
    )

    data class ImportResult(val files: Int, val bytes: Long)

    fun root(filesDir: File): File = File(filesDir, "KartPad")
    fun installed(filesDir: File): File = File(root(filesDir), GAME_DATA)
    fun removalScheduled(filesDir: File): Boolean = File(root(filesDir), REMOVAL_MARKER).isFile

    fun validationError(filesDir: File): String? = localValidationError(installed(filesDir))

    /** True on a fresh install: nothing has been imported yet, so there is nothing to diagnose. */
    fun notImported(filesDir: File): Boolean = !installed(filesDir).exists()

    /** Repairs durable runtime configuration for a validated retained import. */
    fun ensureRuntimePath(filesDir: File) {
        localValidationError(installed(filesDir))?.let { throw IllegalArgumentException(it) }
        ensureRelativeDvdRoot(root(filesDir))
    }

    fun scheduleRemoval(filesDir: File) {
        val support = root(filesDir)
        check(support.isDirectory || support.mkdirs()) { "Game-data storage is unavailable." }
        val marker = AtomicFile(File(support, REMOVAL_MARKER))
        val output = marker.startWrite()
        try {
            output.write("remove-on-next-launch\n".toByteArray(Charsets.UTF_8))
            marker.finishWrite(output)
        } catch (error: Throwable) {
            marker.failWrite(output)
            throw error
        }
    }

    fun cancelRemoval(filesDir: File): Boolean =
        !removalScheduled(filesDir) || File(root(filesDir), REMOVAL_MARKER).delete()

    /** Called by the isolated chooser before a new SDL runtime can start. */
    fun applyScheduledRemoval(filesDir: File): String? {
        if (!removalScheduled(filesDir)) return null
        val support = root(filesDir)
        support.listFiles().orEmpty().filter {
            it.name == GAME_DATA || it.name.startsWith("GameData.import-") ||
                it.name.startsWith("GameData.rollback-")
        }.forEach { entry ->
            if (!entry.deleteRecursively()) return "Stored game data could not be removed."
        }
        if (!File(support, REMOVAL_MARKER).delete()) {
            return "Game-data removal could not be completed."
        }
        return null
    }

    fun importExtractedTree(
        resolver: ContentResolver,
        tree: Uri,
        filesDir: File,
        progress: (String) -> Unit,
    ): ImportResult {
        val support = root(filesDir)
        check(support.isDirectory || support.mkdirs()) { "Game-data storage is unavailable." }
        recoverInterruptedImport(support)
        val navigator = TreeNavigator(resolver, tree)
        progress("Validating the selected extracted disc…")
        val selectedRoot = navigator.resolveExtractedRoot()
            ?: throw IllegalArgumentException(
                "Choose an extracted Mario Kart Wii DATA folder containing files/ and sys/.",
            )
        validateTree(navigator, selectedRoot)

        val staging = File(support, "GameData.import-${UUID.randomUUID()}")
        check(staging.mkdir()) { "The game-data staging folder could not be created." }
        return try {
            progress("Copying extracted game data…")
            val counter = CopyCounter()
            copyTree(navigator, selectedRoot, staging, 0, counter, progress)
            localValidationError(staging)?.let { throw IllegalArgumentException(it) }
            ensureRelativeDvdRoot(support)
            activate(support, staging)
            File(support, REMOVAL_MARKER).delete()
            ImportResult(counter.entries, counter.bytes)
        } catch (error: Throwable) {
            staging.deleteRecursively()
            throw error
        }
    }

    /**
     * Imports one .zip of an extracted disc: files/ and sys/ at the top, or inside
     * DATA/ or the folder Dolphin made. A zip moves through cloud drives and
     * messaging apps as a single file, and a cut-off one fails here instead of
     * leaving game files missing. Read as a stream: the picked document can't be
     * reopened for random access.
     */
    fun importZip(
        resolver: ContentResolver,
        zipUri: Uri,
        filesDir: File,
        progress: (String) -> Unit,
    ): ImportResult {
        val support = root(filesDir)
        check(support.isDirectory || support.mkdirs()) { "Game-data storage is unavailable." }
        recoverInterruptedImport(support)
        progress("Opening the zip…")
        val staging = File(support, "GameData.import-${UUID.randomUUID()}")
        check(staging.mkdir()) { "The game-data staging folder could not be created." }
        try {
            val counter = CopyCounter()
            var gameRoot: File? = null
            val input = resolver.openInputStream(zipUri)
                ?: throw IllegalArgumentException("The selected zip could not be opened.")
            try {
                ZipInputStream(input.buffered()).use { zip ->
                    while (true) {
                        val entry = zip.nextEntry ?: break
                        val parts = entry.name.trimEnd('/').split('/')
                        require(parts.size <= MAX_DEPTH && parts.all {
                            it.isNotBlank() && it != "." && it != ".." &&
                                '\\' !in it && '\u0000' !in it
                        }) { "The zip contains an unsafe file name." }
                        // Dolphin's other partitions and macOS metadata aren't game data.
                        val gameStart = parts.indexOfFirst { it == "files" || it == "sys" }
                        val before = if (gameStart < 0) parts else parts.subList(0, gameStart)
                        if (before.any { it == "UPDATE" || it == "CHANNEL" || it == "__MACOSX" }) continue
                        counter.entries += 1
                        require(counter.entries <= MAX_ENTRIES) { "The zip contains too many files." }
                        val output = File(staging, parts.joinToString("/"))
                        if (entry.isDirectory) {
                            check(output.isDirectory || output.mkdirs()) { "A game-data directory could not be created." }
                            continue
                        }
                        output.parentFile?.let { parent ->
                            check(parent.isDirectory || parent.mkdirs()) { "A game-data directory could not be created." }
                        }
                        FileOutputStream(output).use { stream ->
                            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                            while (true) {
                                val count = zip.read(buffer)
                                if (count < 0) break
                                stream.write(buffer, 0, count)
                                counter.bytes += count
                                require(counter.bytes <= MAX_BYTES) { "The zip exceeds KartPad's import limit." }
                            }
                        }
                        if (parts.size >= 2 && parts.takeLast(2) == listOf("sys", "main.dol")) {
                            gameRoot = output.parentFile?.parentFile
                        }
                        if (counter.entries % 64 == 0) {
                            progress("Copying game data from the zip… ${counter.entries} items")
                        }
                    }
                }
            } catch (error: IOException) {
                android.util.Log.w("KartPadGameData", "Zip import failed", error)
                throw IllegalArgumentException(DAMAGED_ZIP)
            }
            val root = gameRoot ?: throw IllegalArgumentException(
                "This zip doesn't contain Mario Kart Wii game data. Zip the folder Dolphin's Extract Entire Disc made.",
            )
            localValidationError(root)?.let { throw IllegalArgumentException(it) }
            ensureRelativeDvdRoot(support)
            activate(support, root)
            File(support, REMOVAL_MARKER).delete()
            return ImportResult(counter.entries, counter.bytes)
        } finally {
            staging.deleteRecursively()
        }
    }
    fun importDiscImage(
        resolver: ContentResolver,
        image: Uri,
        filesDir: File,
        progress: (String) -> Unit,
    ): ImportResult {
        check(BuildConfig.DISC_IMAGE_IMPORT) {
            "Disc-image import is unavailable in this build."
        }
        val support = root(filesDir)
        check(support.isDirectory || support.mkdirs()) { "Game-data storage is unavailable." }
        recoverInterruptedImport(support)
        val staging = File(support, "GameData.import-${UUID.randomUUID()}")
        check(staging.mkdir()) { "The game-data staging folder could not be created." }
        return try {
            progress("Extracting the selected Wii disc image…")
            KartPadDiscImageImporter.extract(resolver, image, staging, filesDir)
            progress("Validating extracted game data…")
            localValidationError(staging)?.let { throw IllegalArgumentException(it) }
            val counter = countLocalTree(staging)
            ensureRelativeDvdRoot(support)
            activate(support, staging)
            File(support, REMOVAL_MARKER).delete()
            ImportResult(counter.entries, counter.bytes)
        } catch (error: Throwable) {
            staging.deleteRecursively()
            throw error
        }
    }

    private fun countLocalTree(root: File): CopyCounter {
        val counter = CopyCounter()
        root.walkTopDown().drop(1).forEach { entry ->
            counter.entries += 1
            require(counter.entries <= MAX_ENTRIES) { "The disc contains too many files." }
            if (entry.isFile) {
                counter.bytes += entry.length()
                require(counter.bytes <= MAX_BYTES) { "The disc exceeds KartPad's import limit." }
            }
        }
        return counter
    }

    private fun validateTree(navigator: TreeNavigator, rootId: String) {
        val nodes = requiredPaths.associateWith { path ->
            navigator.resolve(rootId, path.split('/'))
                ?: throw IllegalArgumentException("The extracted game data is incomplete (missing $path).")
        }
        val boot = navigator.readBounded(nodes.getValue("sys/boot.bin"), 0x21)
        require(boot.size >= 0x20) { "The selected sys/boot.bin is truncated." }
        require(boot.copyOfRange(0, 6).contentEquals("RMCP01".toByteArray()) &&
            boot[6] == 0.toByte() && boot[7] == 0.toByte()
        ) { "KartPad currently supports RMCP01 (PAL), disc 0, revision 0 only." }
        val magic = ((boot[0x18].toInt() and 0xff) shl 24) or
            ((boot[0x19].toInt() and 0xff) shl 16) or
            ((boot[0x1a].toInt() and 0xff) shl 8) or (boot[0x1b].toInt() and 0xff)
        require(magic == 0x5d1c9ea3) {
            "The selected folder does not contain a valid extracted Wii disc header."
        }
        require(navigator.sha256(nodes.getValue("sys/main.dol")) == MAIN_DOL_SHA256) {
            MODIFIED_GAME_DATA
        }
        require(navigator.sha256(nodes.getValue("files/rel/StaticR.rel")) == STATIC_R_SHA256) {
            MODIFIED_GAME_DATA
        }
    }

    private fun localValidationError(root: File): String? {
        requiredPaths.forEach { path ->
            if (!File(root, path).isFile) return "The extracted game data is incomplete (missing $path)."
        }
        val boot = runCatching {
            File(root, "sys/boot.bin").inputStream().use { input ->
                val buffer = ByteArray(0x21)
                var count = 0
                while (count < buffer.size) {
                    val read = input.read(buffer, count, buffer.size - count)
                    if (read < 0) break
                    count += read
                }
                buffer.copyOf(count)
            }
        }.getOrElse { return "KartPad could not read sys/boot.bin." }
        if (boot.size < 0x20) return "The selected sys/boot.bin is truncated."
        if (!boot.copyOfRange(0, 6).contentEquals("RMCP01".toByteArray()) ||
            boot[6] != 0.toByte() || boot[7] != 0.toByte()
        ) return "KartPad currently supports RMCP01 (PAL), disc 0, revision 0 only."
        val magic = ((boot[0x18].toInt() and 0xff) shl 24) or
            ((boot[0x19].toInt() and 0xff) shl 16) or
            ((boot[0x1a].toInt() and 0xff) shl 8) or (boot[0x1b].toInt() and 0xff)
        if (magic != 0x5d1c9ea3) {
            return "The selected folder does not contain a valid extracted Wii disc header."
        }
        val hash = runCatching { sha256(File(root, "sys/main.dol")) }
            .getOrElse { return "KartPad could not hash sys/main.dol." }
        if (hash != MAIN_DOL_SHA256) {
            return MODIFIED_GAME_DATA
        }
        val relHash = runCatching { sha256(File(root, "files/rel/StaticR.rel")) }
            .getOrElse { return "KartPad could not hash files/rel/StaticR.rel." }
        if (relHash != STATIC_R_SHA256) {
            return MODIFIED_GAME_DATA
        }
        return incompleteFilesError(root)
    }

    /**
     * Every file the disc's own table (sys/fst.bin) lists must be present at its full size. The
     * game checks the same rule when it starts (#370); checking here too means a copy that didn't
     * finish is caught at import, and never shows as "Ready to play".
     */
    internal fun incompleteFilesError(root: File): String? {
        val damaged = "The game data's file table (sys/fst.bin) is damaged. Import your game data again."
        val fst = runCatching { File(root, "sys/fst.bin").readBytes() }
            .getOrElse { return "KartPad could not read sys/fst.bin." }
        fun be32(at: Int): Long = ((fst[at].toLong() and 0xff) shl 24) or ((fst[at + 1].toLong() and 0xff) shl 16) or
            ((fst[at + 2].toLong() and 0xff) shl 8) or (fst[at + 3].toLong() and 0xff)
        if (fst.size < 12) return damaged
        val count = be32(8)
        if (count < 1 || count * 12 > fst.size) return damaged
        val names = count.toInt() * 12
        // A directory entry stores the index just past its last child.
        val directories = ArrayDeque<Pair<Long, String>>().apply { addLast(count to "") }
        var listed = 0
        var incomplete = 0
        var example: String? = null
        for (index in 1 until count.toInt()) {
            while (directories.size > 1 && index >= directories.last().first) directories.removeLast()
            val word = be32(index * 12)
            val nameStart = names + (word and 0xffffff).toInt()
            var nameEnd = nameStart
            while (nameEnd < fst.size && fst[nameEnd] != 0.toByte()) nameEnd++
            if (nameStart >= fst.size || nameEnd == nameStart) return damaged
            val name = String(fst, nameStart, nameEnd - nameStart, Charsets.ISO_8859_1)
            if (name == "." || name == ".." || '/' in name) return damaged
            val path = directories.last().second + name
            val size = be32(index * 12 + 8)
            if ((word ushr 24) != 0L) {
                directories.addLast(size to "$path/")
            } else {
                listed += 1
                val file = File(root, "files/$path")
                if (!file.isFile || file.length() < size) {
                    incomplete += 1
                    if (example == null) example = path
                }
            }
        }
        if (incomplete == 0) return null
        return "The game data is incomplete: $incomplete of $listed game files are missing or cut short, " +
            "for example files/$example. A copy probably didn't finish. Copy the complete folder (or zip) " +
            "to this phone again, then import it again."
    }

    private fun copyTree(
        navigator: TreeNavigator,
        parentId: String,
        destination: File,
        depth: Int,
        counter: CopyCounter,
        progress: (String) -> Unit,
    ) {
        require(depth <= MAX_DEPTH) { "The selected folder is nested too deeply." }
        navigator.children(parentId).forEach { node ->
            require(node.name.isNotBlank() && node.name != "." && node.name != ".." &&
                '/' !in node.name && '\\' !in node.name && '\u0000' !in node.name
            ) { "The selected folder contains an unsafe file name." }
            counter.entries += 1
            require(counter.entries <= MAX_ENTRIES) { "The selected folder contains too many files." }
            val output = File(destination, node.name)
            if (node.directory) {
                check(output.mkdir()) { "A game-data directory could not be created." }
                copyTree(navigator, node.id, output, depth + 1, counter, progress)
            } else {
                navigator.open(node).use { input ->
                    FileOutputStream(output).use { stream ->
                        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            stream.write(buffer, 0, count)
                            counter.bytes += count
                            require(counter.bytes <= MAX_BYTES) {
                                "The selected folder exceeds KartPad's import limit."
                            }
                        }
                    }
                }
            }
            if (counter.entries % 64 == 0) {
                progress("Copying extracted game data… ${counter.entries} items")
            }
        }
    }

    private fun activate(support: File, staging: File) {
        val current = File(support, GAME_DATA)
        val rollback = File(support, "GameData.rollback-${UUID.randomUUID()}")
        val movedExisting = current.exists() && current.renameTo(rollback)
        if (current.exists() && !movedExisting) {
            throw IllegalStateException("The existing game data could not be prepared for replacement.")
        }
        if (!staging.renameTo(current)) {
            if (movedExisting && !current.exists()) rollback.renameTo(current)
            throw IllegalStateException("The imported game data could not be activated.")
        }
        if (movedExisting) rollback.deleteRecursively()
        support.listFiles().orEmpty().filter { it.name.startsWith("GameData.rollback-") }
            .forEach { it.deleteRecursively() }
    }

    private fun recoverInterruptedImport(support: File) {
        support.listFiles().orEmpty().filter { it.name.startsWith("GameData.import-") }
            .forEach { it.deleteRecursively() }
        val current = File(support, GAME_DATA)
        val rollbacks = support.listFiles().orEmpty()
            .filter { it.name.startsWith("GameData.rollback-") }.sortedBy { it.name }
        if (!current.exists() && rollbacks.size == 1) rollbacks.single().renameTo(current)
        if (current.exists()) rollbacks.forEach { it.deleteRecursively() }
    }

    private fun ensureRelativeDvdRoot(support: File) {
        val configFile = File(support, "Config.toml")
        var config = if (configFile.isFile) configFile.readText() else ""
        val installedDvdLine = Regex(
            "(?m)^[\\t ]*dvd_root[\\t ]*=[\\t ]*\"GameData\"[\\t ]*(?:#.*)?$",
        )
        if (installedDvdLine.containsMatchIn(config)) return
        val dvdLine = Regex("(?m)^\\s*#?\\s*dvd_root\\s*=.*$")
        config = config.replace(dvdLine, "")
        val paths = Regex("(?m)^\\s*\\[paths]\\s*$").find(config)
        config = if (paths != null) {
            config.substring(0, paths.range.last + 1) + "\ndvd_root = \"GameData\"" +
                config.substring(paths.range.last + 1)
        } else {
            config.trimEnd() + "\n\n[paths]\ndvd_root = \"GameData\"\n"
        }
        val atomic = AtomicFile(configFile)
        val output = atomic.startWrite()
        try {
            output.write(config.toByteArray(Charsets.UTF_8))
            atomic.finishWrite(output)
        } catch (error: Throwable) {
            atomic.failWrite(output)
            throw error
        }
    }

    private fun sha256(file: File): String = file.inputStream().use { input ->
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            digest.update(buffer, 0, count)
        }
        digest.digest().joinToString("") { "%02x".format(it) }
    }

    private class CopyCounter(var entries: Int = 0, var bytes: Long = 0)

    private data class TreeNode(
        val id: String,
        val name: String,
        val mime: String,
    ) {
        val directory: Boolean get() = mime == DocumentsContract.Document.MIME_TYPE_DIR
    }

    private class TreeNavigator(private val resolver: ContentResolver, private val tree: Uri) {
        private val treeRoot = DocumentsContract.getTreeDocumentId(tree)

        fun resolveExtractedRoot(): String? {
            if (looksLikeExtractedRoot(treeRoot)) return treeRoot
            for (name in listOf("DATA", "GameData")) {
                val child = children(treeRoot).firstOrNull { it.directory && it.name == name }
                if (child != null && looksLikeExtractedRoot(child.id)) return child.id
            }
            return null
        }

        fun resolve(start: String, segments: List<String>): TreeNode? {
            var current = TreeNode(start, "", DocumentsContract.Document.MIME_TYPE_DIR)
            segments.forEach { name ->
                current = children(current.id).firstOrNull { it.name == name } ?: return null
            }
            return current
        }

        fun children(parentId: String): List<TreeNode> {
            val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
            val columns = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            )
            val result = mutableListOf<TreeNode>()
            resolver.query(uri, columns, null, null, null)?.use { cursor ->
                while (cursor.moveToNext()) {
                    result += TreeNode(cursor.getString(0), cursor.getString(1), cursor.getString(2))
                }
            } ?: throw IllegalArgumentException("The selected folder could not be read.")
            return result
        }

        fun open(node: TreeNode) = resolver.openInputStream(
            DocumentsContract.buildDocumentUriUsingTree(tree, node.id),
        ) ?: throw IllegalArgumentException("A selected game-data file could not be opened.")

        fun readBounded(node: TreeNode, limit: Int): ByteArray = open(node).use { input ->
            val buffer = ByteArray(limit)
            var count = 0
            while (count < limit) {
                val read = input.read(buffer, count, limit - count)
                if (read < 0) break
                count += read
            }
            buffer.copyOf(count)
        }

        fun sha256(node: TreeNode): String = open(node).use { input ->
            val digest = MessageDigest.getInstance("SHA-256")
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
            digest.digest().joinToString("") { "%02x".format(it) }
        }

        private fun looksLikeExtractedRoot(id: String): Boolean {
            val names = children(id).filter { it.directory }.map { it.name }.toSet()
            return "files" in names && "sys" in names
        }
    }
}
