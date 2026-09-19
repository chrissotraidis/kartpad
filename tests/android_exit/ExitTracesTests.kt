package dev.kartpad.android
import android.app.*
import android.content.Context
import android.os.Build
import java.io.*
import java.util.zip.*
import org.json.JSONObject
fun testPrivateExitTraces() {
 testTombstoneSummary()
 val manager=ActivityManager();val context=Context(manager)
 fun export(): Map<String,ByteArray> {
  val out=ByteArrayOutputStream();ZipOutputStream(out).use { KartPadExitTraces.write(context,it) }
  val entries=mutableMapOf<String,ByteArray>()
  ZipInputStream(ByteArrayInputStream(out.toByteArray())).use { zip -> while(true){val e=zip.nextEntry?:break;entries[e.name]=zip.readBytes()} }
  return entries
 }
 Build.VERSION.SDK_INT=28
 check(export().size==1 && manager.calls==0)
 Build.VERSION.SDK_INT=31
 var closed=false
 manager.exits=listOf(ApplicationExitInfo(5, timestamp=3, trace={object:ByteArrayInputStream(byteArrayOf(1,2,3)){override fun close(){closed=true;super.close()}}}),ApplicationExitInfo(6,timestamp=2,trace={null}),ApplicationExitInfo(6,timestamp=1,trace={ByteArrayInputStream(ByteArray(1024*1024+1))}))
 val files=export();check(closed && files.size==2)
 val rows=JSONObject(files.getValue("OS-exits/manifest.json").decodeToString()).getJSONArray("traces")
 check(rows.getJSONObject(0).getString("availability")=="included")
 check(rows.getJSONObject(1).getString("availability")=="not_retained")
 check(rows.getJSONObject(2).getString("availability")=="too_large")
 manager.exits=listOf(ApplicationExitInfo(6,trace={throw IOException("private") }))
 check(JSONObject(export().getValue("OS-exits/manifest.json").decodeToString()).getJSONArray("traces").getJSONObject(0).getString("availability")=="unavailable")
 check(runCatching { ZipOutputStream(object:OutputStream(){override fun write(b:Int){throw IOException("output failed")}}).use { KartPadExitTraces.write(context,it) } }.isFailure)
 println("Private OS trace export passed: bounds, null retention, close, read and output failures")
}
