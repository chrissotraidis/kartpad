package dev.kartpad.android

import android.app.Application
import android.content.Context
import android.system.Os

/** Native workers can load the runtime before an SDL activity exists. */
class KartPadApplication : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        Os.setenv("KARTPAD_ANDROID_FILES_DIR", base.filesDir.absolutePath, true)
        Os.setenv("KARTPAD_ANDROID_CACHE_DIR", base.cacheDir.absolutePath, true)
    }
}
