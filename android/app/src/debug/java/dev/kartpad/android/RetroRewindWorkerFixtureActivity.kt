package dev.kartpad.android

import android.app.Activity
import android.os.Bundle
import android.util.Log

/** Debug-only non-SDL owner for proving installer work across UI recreation. */
internal class RetroRewindWorkerFixtureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (BuildConfig.GAME_RUNTIME) {
            finish()
            return
        }
        if (intent.getBooleanExtra(EXTRA_INIT_ONLY, false)) {
            Log.i(LOG_TAG, "A3 worker initializer activity created")
            return
        }
        if (intent.getBooleanExtra(EXTRA_RESUME_PROCESS_DEATH, false)) {
            if (savedInstanceState == null) {
                val id = RetroRewindInstallWork.enqueueDebugFixture(
                    this,
                    steps = 60,
                    delayMillis = 500,
                    resumeProcessDeath = true,
                )
                Log.i(LOG_TAG, "A3 durable worker restart fixture enqueued id=$id")
            }
            return
        }
        val id = RetroRewindInstallWork.enqueueDebugFixture(
            this,
            steps = 40,
            delayMillis = 250,
        )
        if (savedInstanceState == null) {
            Log.i(LOG_TAG, "A3 worker activity-recreation fixture enqueued id=$id")
            window.decorView.postDelayed(
                {
                    Log.i(LOG_TAG, "A3 worker activity recreation requested")
                    recreate()
                },
                1_000,
            )
        } else {
            Log.i(LOG_TAG, "A3 worker activity recreation observed; KEEP reenqueued")
        }
    }

    companion object {
        private const val LOG_TAG = "KartPadFixture"
        const val EXTRA_RESUME_PROCESS_DEATH =
            "dev.kartpad.android.TEST_RETRO_REWIND_WORKER_RESTART"
        const val EXTRA_INIT_ONLY =
            "dev.kartpad.android.TEST_RETRO_REWIND_WORKER_INIT_ONLY"
    }
}
