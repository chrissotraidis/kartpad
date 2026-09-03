package dev.kartpad.android

import android.content.Context
import android.graphics.Canvas
import android.view.View

/** Transparent project-owned layer; gameplay controls arrive only after A0/A1 gates. */
class KartPadOverlayView(context: Context) : View(context) {
    init {
        setWillNotDraw(false)
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
    }
}
