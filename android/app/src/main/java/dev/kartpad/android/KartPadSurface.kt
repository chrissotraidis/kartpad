package dev.kartpad.android

import android.content.Context
import android.view.SurfaceHolder
import org.libsdl.app.SDLSurface

/** Holds Aurora's native surface lock across SDL's Java/native mutations. */
internal class KartPadSurface(context: Context) : SDLSurface(context) {
    private external fun nativeBeginSurfaceMutation()
    private external fun nativeEndSurfaceMutation(ready: Boolean)

    override fun surfaceCreated(holder: SurfaceHolder) {
        nativeBeginSurfaceMutation()
        try {
            super.surfaceCreated(holder)
        } finally {
            nativeEndSurfaceMutation(true)
        }
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        nativeBeginSurfaceMutation()
        try {
            super.surfaceChanged(holder, format, width, height)
        } finally {
            nativeEndSurfaceMutation(true)
        }
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        nativeBeginSurfaceMutation()
        try {
            super.surfaceDestroyed(holder)
        } finally {
            nativeEndSurfaceMutation(false)
        }
    }
}
