package dev.kartpad.android

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import android.util.AtomicFile
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID

/** Crash-safe storage transaction for user-selected extracted RMCP01 game data. */
internal object KartPadGameDataStorage {
    private const val GAME_DATA = "GameData"
    private const val REMOVAL_MARKER = "RemoveGameDataOnNextLaunch"
    private const val MAX_DEPTH = 64
    private const val MAX_ENTRIES = 100_000
    private const val MAX_BYTES = 8L * 1024L * 1024L * 1024L
    private const val MAIN_DOL_SHA256 =
        "80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"

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
            KartPadDiscImageImporter.extract(resolver, image, staging)
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
            "sys/main.dol does not match the supported RMCP01 revision 0 profile."
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
            return "sys/main.dol does not match the supported RMCP01 revision 0 profile."
        }
        return null
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
