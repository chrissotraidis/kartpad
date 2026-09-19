package android.app

class ApplicationExitInfo(
    val reason: Int, val processStateSummary: ByteArray? = null,
    val pss: Long = 0, val rss: Long = 0,
    val timestamp: Long = 1234567890, val status: Int = 0, val importance: Int = 100, val trace: (() -> java.io.InputStream?)? = null
) {
    val pid: Int = 42
    val description: String get() = error("Private description must not be read")
    val traceInputStream: java.io.InputStream? get() = trace?.invoke() ?: if (trace == null) error("Private trace must not be read") else null
    companion object {
        const val REASON_EXIT_SELF=1; const val REASON_SIGNALED=2
        const val REASON_LOW_MEMORY=3; const val REASON_CRASH=4
        const val REASON_CRASH_NATIVE=5; const val REASON_ANR=6
        const val REASON_INITIALIZATION_FAILURE=7; const val REASON_PERMISSION_CHANGE=8
        const val REASON_EXCESSIVE_RESOURCE_USAGE=9; const val REASON_USER_REQUESTED=10
        const val REASON_USER_STOPPED=11; const val REASON_DEPENDENCY_DIED=12
        const val REASON_OTHER=13
    }
}

class ActivityManager {
    var exits = emptyList<ApplicationExitInfo>()
    var deny = false
    var marked: ByteArray? = null
    var calls = 0
    fun setProcessStateSummary(state: ByteArray) {
        if (deny) throw SecurityException("private error detail")
        marked = state
    }
    fun getHistoricalProcessExitReasons(name: String, pid: Int, max: Int): List<ApplicationExitInfo> {
        calls++
        check(name == "dev.kartpad.android" && pid == 0 && max == 8)
        if (deny) throw SecurityException("private error detail")
        return exits
    }
}
