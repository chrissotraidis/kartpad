package dev.kartpad.android

import android.content.Context
import android.util.Log
import java.io.File

/** Installs immutable public runtime support files into versioned app-private storage. */
internal object KartPadRuntimeResources {
    private const val TAG = "KartPadResources"
    private const val VERSION = "a2-v1"

    private val files = listOf(
        "dsp/dsp_coef.bin",
        "pipeline/initial_pipeline_cache.db",
        "wii/README.md",
        "wii/shared2/wc24/misc.bin",
        "wii/shared2/wc24/nwc24dl.bin",
        "wii/shared2/wc24/nwc24fl.bin",
        "wii/shared2/wc24/nwc24fls.bin",
        "wii/shared2/wc24/nwc24msg.cbk",
        "wii/shared2/wc24/nwc24msg.cfg",
        "wii/shared2/wc24/mbox/Readme.txt",
        "wii/shared2/wc24/mbox/wc24recv.ctl",
        "wii/shared2/wc24/mbox/wc24recv.mbx",
        "wii/shared2/wc24/mbox/wc24send.ctl",
        "wii/shared2/wc24/mbox/wc24send.mbx",
    )

    fun install(context: Context) {
        val parent = File(context.filesDir, "KartPad/RuntimeResources")
        val destination = File(parent, VERSION)
        if (files.all { File(destination, it).isFile }) {
            return
        }

        val staging = File(parent, ".$VERSION-staging")
        check(!staging.exists() || staging.deleteRecursively()) {
            "Unable to clear stale runtime-resource staging directory"
        }
        check(staging.mkdirs()) { "Unable to create runtime-resource staging directory" }

        files.forEach { relativePath ->
            val output = File(staging, relativePath)
            val outputParent = checkNotNull(output.parentFile)
            check(outputParent.isDirectory || outputParent.mkdirs()) {
                "Unable to create runtime-resource directory for $relativePath"
            }
            context.assets.open(relativePath).use { input ->
                output.outputStream().use { stream -> input.copyTo(stream) }
            }
        }

        check(!destination.exists() || destination.deleteRecursively()) {
            "Unable to replace incomplete runtime resources"
        }
        check(staging.renameTo(destination)) {
            "Unable to activate runtime resources"
        }
        Log.i(TAG, "Installed runtime resources version=$VERSION files=${files.size}")
    }
}
