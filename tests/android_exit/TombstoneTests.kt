package dev.kartpad.android

import java.io.ByteArrayOutputStream

fun testTombstoneSummary() {
    fun varint(value: Long): ByteArray {
        var v = value
        val out = ByteArrayOutputStream()
        do { val b = (v and 127).toInt(); v = v ushr 7; out.write(b or if (v != 0L) 128 else 0) } while(v != 0L)
        return out.toByteArray()
    }
    fun number(id: Int, value: Long) = varint(id.toLong() shl 3) + varint(value)
    fun message(id: Int, data: ByteArray) = varint((id.toLong() shl 3) or 2) + varint(data.size.toLong()) + data
    fun string(id: Int, data: String) = message(id, data.toByteArray())
    val secret = "PRIVATE-IDENTITY-AND-MEMORY"
    val frame = number(1, 0x1234) + string(6,"/private/$secret/libKartPad.so") + string(8,"aabbccddeeff0011")
    val thread = number(1,42) + string(2,secret) + message(4,frame) + message(5,secret.toByteArray())
    val tombstone = number(1,1) + number(6,42) + message(10,number(1,6)) +
        string(14,secret) + message(16,number(1,42) + message(2,thread)) + message(18,secret.toByteArray())
    val report = KartPadTombstoneSummary.summarize(tombstone)
    check(report.getString("availability") == "decoded")
    val decoded = report.getJSONArray("threads").getJSONObject(0)
    check(decoded.getBoolean("crashed"))
    check(decoded.getJSONArray("frames").getJSONObject(0).getString("relative_pc_hex") == "1234")
    check(decoded.getJSONArray("frames").getJSONObject(0).getString("module") == "libKartPad.so")
    check(!report.toString().contains(secret))
    check(KartPadTombstoneSummary.summarize(tombstone + byteArrayOf(0)).getString("availability") == "decode_failed")
    check(KartPadTombstoneSummary.summarize(ByteArray(1024*1024+1)).getString("availability") == "decode_failed")
    for (length in 0 until tombstone.size) {
        // Truncation must never throw or expose raw input; some exact field boundaries are valid protobuf.
        check(!KartPadTombstoneSummary.summarize(tombstone.copyOf(length)).toString().contains(secret))
    }
    var many = number(1,1) + number(6,999) + message(10,number(1,6))
    repeat(80) { many += message(16, number(1,it.toLong()) + message(2,thread)) }
    many += message(16, number(1,999) + message(2,thread))
    val clipped = KartPadTombstoneSummary.summarize(many)
    check(clipped.getJSONArray("threads").length() == 64 && clipped.getInt("threads_omitted") == 17)
    check(clipped.getJSONArray("threads").getJSONObject(0).getBoolean("crashed"))
    val random = kotlin.random.Random(117)
    repeat(1000) { KartPadTombstoneSummary.summarize(random.nextBytes(random.nextInt(512))) }
    println("Native tombstone projection passed: frame identity, privacy, truncation, bounds and malformed input")
}
