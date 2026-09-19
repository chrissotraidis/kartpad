package dev.kartpad.android

import org.json.JSONArray
import org.json.JSONObject

/** Allowlisted projection of Android's tombstone protobuf, never its memory/log/FD payloads.
 * Field numbers: AOSP debuggerd/proto/tombstone.proto, blob 9deeeec9e185f79747acf5fb6a7e71586eb7da16.
 * Parsing is bounded and fail-closed. Unknown fields are skipped for forward compatibility.
 */
internal object KartPadTombstoneSummary {
    private data class Field(val number: Int, val value: Long = 0, val bytes: ByteArray? = null)
    private fun fields(data: ByteArray): List<Field> {
        require(data.size <= 1024 * 1024)
        var offset = 0
        fun varint(): Long {
            var value = 0L
            for (shift in 0..63 step 7) {
                require(offset < data.size)
                val b = data[offset++].toInt() and 255
                require(shift != 63 || b <= 1)
                value = value or ((b and 127).toLong() shl shift)
                if (b and 128 == 0) return value
            }
            error("invalid varint")
        }
        val result = ArrayList<Field>()
        while (offset < data.size) {
            require(result.size < 16384)
            val key = varint()
            require(key > 0 && key ushr 3 <= 536870911)
            val number = (key ushr 3).toInt()
            require(number != 0)
            when ((key and 7).toInt()) {
                0 -> result.add(Field(number, varint()))
                1, 5 -> {
                    val size = if (key and 7 == 1L) 8 else 4
                    require(size <= data.size - offset)
                    offset += size
                    result.add(Field(number))
                }
                2 -> {
                    val size = varint()
                    require(size >= 0 && size <= data.size - offset)
                    result.add(Field(number, bytes = data.copyOfRange(offset, offset + size.toInt())))
                    offset += size.toInt()
                }
                else -> error("unsupported wire type")
            }
        }
        return result
    }
    private fun List<Field>.number(id: Int) = firstOrNull { it.number == id && it.bytes == null }?.value ?: 0L
    private fun List<Field>.message(id: Int) = firstOrNull { it.number == id }?.bytes?.let(::fields).orEmpty()
    private fun List<Field>.text(id: Int) = firstOrNull { it.number == id }?.bytes?.decodeToString().orEmpty()
    fun summarize(bytes: ByteArray): JSONObject = try {
        val root = fields(bytes)
        val signal = root.message(10)
        // Require a recognizable native report; arbitrary protobuf must not look like a valid crash.
        require(signal.number(1) in 1..64 && root.any { it.number == 16 && it.bytes != null })
        val result = JSONObject().put("availability", "decoded")
            .put("schema", 1).put("architecture", root.number(1))
            .put("signal", signal.number(1)).put("signal_code", signal.number(3).toInt())
            .put("crashed_tid", root.number(6)).put("process_uptime_seconds", root.number(20))
        val threads = JSONArray()
        val threadFields = root.filter { it.number == 16 && it.bytes != null }
        // Android can retain more than 64 renderer/driver threads. Never let
        // map order discard the thread that actually crashed.
        val orderedThreads = threadFields.sortedByDescending { fields(requireNotNull(it.bytes)).number(1) == root.number(6) }
        for (entry in orderedThreads.take(64)) {
            val map = fields(requireNotNull(entry.bytes))
            val thread = map.message(2)
            val tid = map.number(1)
            val frames = JSONArray()
            val frameFields = thread.filter { it.number == 4 && it.bytes != null }
            for (frameField in frameFields.take(256)) {
                val frame = fields(requireNotNull(frameField.bytes))
                // Basenames and hex build IDs are enough to match exact retained symbols.
                val module = frame.text(6).substringAfterLast('/').substringAfterLast('!')
                    .takeIf { it.length <= 160 && Regex("[A-Za-z0-9_.+-]+").matches(it) } ?: "unavailable"
                val buildId = frame.text(8).takeIf { Regex("[a-fA-F0-9]{8,128}").matches(it) } ?: "unavailable"
                frames.put(JSONObject().put("module", module).put("build_id", buildId)
                    .put("relative_pc_hex", java.lang.Long.toUnsignedString(frame.number(1), 16)))
            }
            threads.put(JSONObject().put("tid", tid).put("crashed", tid == root.number(6))
                .put("frames", frames).put("frames_omitted", maxOf(0, frameFields.size - 256)))
        }
        result.put("threads", threads).put("threads_omitted", maxOf(0, threadFields.size - 64))
            .put("privacy", "Only signal, thread numbers, library basenames, relative PCs and build IDs; no memory, paths, log buffers, identities or abort text.")
    } catch (_: RuntimeException) {
        JSONObject().put("availability", "decode_failed").put("schema", 1)
    }
}
