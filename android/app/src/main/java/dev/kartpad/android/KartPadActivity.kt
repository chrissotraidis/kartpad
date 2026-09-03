package dev.kartpad.android

import android.os.Bundle
import android.util.Log
import android.view.ViewGroup
import org.libsdl.app.SDLActivity

class KartPadActivity : SDLActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val overlay = KartPadOverlayView(this)
        mLayout.addView(
            overlay,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
        mLayout.bringChildToFront(overlay)
        Log.i(TAG, "A0 SDLActivity shell created")
    }

    companion object {
        private const val TAG = "KartPadFixture"
    }
}
