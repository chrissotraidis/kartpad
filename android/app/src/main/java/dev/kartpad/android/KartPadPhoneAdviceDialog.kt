package dev.kartpad.android

import android.app.Activity
import android.app.AlertDialog
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.GLES20

/**
 * Speed & Graphics → Recommended for This Phone. Reads the GPU name and the system driver's
 * version through OpenGL ES (what the driver reports even while a custom Vulkan driver is chosen),
 * then shows KartPadPhoneAdvice for it.
 */
internal object KartPadPhoneAdviceDialog {
    @Volatile private var cached: KartPadPhoneAdvice.Gpu? = null
    private var probeThread: Thread? = null

    /** Starts reading the GPU in the background, so the menu row doesn't wait for it. */
    @Synchronized
    fun warmUp(): Thread = probeThread ?: Thread({ cached = runCatching(::probe).getOrNull() }, "KartPadGpuProbe")
        .also { probeThread = it; it.start() }

    /** The GPU, read once per process on a short-lived thread with its own EGL context. */
    fun gpu(): KartPadPhoneAdvice.Gpu? {
        warmUp().join(2000)
        return cached
    }

    private fun probe(): KartPadPhoneAdvice.Gpu? {
        val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display == EGL14.EGL_NO_DISPLAY) return null
        val version = IntArray(2)
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) return null
        val configs = arrayOfNulls<EGLConfig>(1)
        val count = IntArray(1)
        val attributes = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_NONE,
        )
        if (!EGL14.eglChooseConfig(display, attributes, 0, configs, 0, 1, count, 0) || count[0] < 1) return null
        val config = configs[0] ?: return null
        val context = EGL14.eglCreateContext(display, config, EGL14.EGL_NO_CONTEXT,
            intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
        if (context == EGL14.EGL_NO_CONTEXT) return null
        val surface = EGL14.eglCreatePbufferSurface(display, config,
            intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0)
        try {
            if (surface == EGL14.EGL_NO_SURFACE || !EGL14.eglMakeCurrent(display, surface, surface, context)) return null
            val renderer = GLES20.glGetString(GLES20.GL_RENDERER) ?: return null
            return KartPadPhoneAdvice.Gpu(renderer, GLES20.glGetString(GLES20.GL_VERSION).orEmpty())
        } finally {
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface)
            EGL14.eglDestroyContext(display, context)
            // No eglTerminate: the default display is shared with the rest of the process.
        }
    }

    fun advice(activity: Activity): KartPadPhoneAdvice.Advice =
        KartPadPhoneAdvice.advise(gpu(), KartPadGpuDriverSettings.selectedName(activity))

    /** The row's one-line detail, e.g. "Adreno 750 · Qualcomm driver 512.762". */
    fun menuDetail(activity: Activity): String = advice(activity).gpuLabel

    fun show(activity: Activity, openGpuDriver: () -> Unit) {
        val advice = advice(activity)
        val message = buildString {
            append(advice.gpuLabel).append("\n\n").append(advice.summary)
            advice.points.forEach { append("\n\n• ").append(it) }
        }
        val dialog = AlertDialog.Builder(activity)
            .setTitle("Recommended for This Phone")
            .setMessage(message)
            .setNegativeButton("Close", null)
        if (advice.action == KartPadPhoneAdvice.Action.GET_DRIVER) {
            dialog.setPositiveButton("Get a Driver…") { _, _ -> openGpuDriver() }
        }
        dialog.show()
    }

    /**
     * Shows the advice once per install when it says to get a driver (Qualcomm's 512.762 driver,
     * #104) and the player hasn't chosen one, so they don't have to find this page themselves.
     */
    fun showOnceIfDriverNeeded(activity: Activity, openGpuDriver: () -> Unit) {
        val preferences = activity.getSharedPreferences("kartpad_phone_advice", Activity.MODE_PRIVATE)
        if (preferences.getBoolean(OFFERED_DRIVER, false) || KartPadGpuDriverSettings.selectedName(activity) != null) return
        if (advice(activity).action != KartPadPhoneAdvice.Action.GET_DRIVER) return
        preferences.edit().putBoolean(OFFERED_DRIVER, true).apply()
        show(activity, openGpuDriver)
    }

    private const val OFFERED_DRIVER = "offered_driver"
}
