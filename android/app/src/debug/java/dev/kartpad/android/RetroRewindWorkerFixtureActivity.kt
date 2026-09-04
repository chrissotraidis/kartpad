package dev.kartpad.android

import android.app.Activity
import android.os.Bundle
import android.util.Log
import androidx.work.WorkManager
import java.nio.file.Files
import java.nio.file.LinkOption

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
        if (intent.getBooleanExtra(EXTRA_VERSION_CHECK, false)) {
            if (savedInstanceState == null) {
                Thread {
                    val result = RetroRewindVersionCheck.checkRelease { false }
                    if (result.isReady) {
                        Log.i(
                            LOG_TAG,
                            "A3 Android official version check latest=${result.latestVersion} " +
                                "update_required=${result.updateRequired}",
                        )
                    } else {
                        Log.e(
                            LOG_TAG,
                            "A3 Android official version check failed error=${result.error}",
                        )
                    }
                }.start()
            }
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
        if (intent.getBooleanExtra(EXTRA_CANCEL, false)) {
            if (savedInstanceState == null) {
                runCancellationFixture()
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

    private fun runCancellationFixture() {
        val id = RetroRewindInstallWork.enqueueDebugFixture(
            this,
            steps = 60,
            delayMillis = 500,
            resumeProcessDeath = true,
        )
        Log.i(LOG_TAG, "A3 worker cancellation fixture enqueued id=$id")
        window.decorView.postDelayed(
            {
                RetroRewindInstallWork.cancel(this)
                Log.i(LOG_TAG, "A3 worker cancellation requested id=$id")
                val appContext = applicationContext
                Thread {
                    try {
                        val workManager = WorkManager.getInstance(appContext)
                        repeat(60) {
                            val info = workManager.getWorkInfoById(id).get()
                            if (info != null && info.state.isFinished) {
                                val partial = appContext.cacheDir.toPath().resolve(
                                    RetroRewindInstallWork.DEBUG_RESUME_PARTIAL,
                                )
                                val bytes = if (Files.isRegularFile(
                                        partial,
                                        LinkOption.NOFOLLOW_LINKS,
                                    )
                                ) {
                                    Files.size(partial)
                                } else {
                                    -1
                                }
                                Log.i(
                                    LOG_TAG,
                                    "A3 worker cancellation observed id=$id " +
                                        "state=${info.state} partial=$bytes",
                                )
                                Files.deleteIfExists(partial)
                                return@Thread
                            }
                            Thread.sleep(100)
                        }
                        Log.e(LOG_TAG, "A3 worker cancellation observation timed out id=$id")
                    } catch (error: Exception) {
                        Log.e(LOG_TAG, "A3 worker cancellation observation failed id=$id", error)
                    }
                }.start()
            },
            2_000,
        )
    }

    companion object {
        private const val LOG_TAG = "KartPadFixture"
        const val EXTRA_RESUME_PROCESS_DEATH =
            "dev.kartpad.android.TEST_RETRO_REWIND_WORKER_RESTART"
        const val EXTRA_INIT_ONLY =
            "dev.kartpad.android.TEST_RETRO_REWIND_WORKER_INIT_ONLY"
        const val EXTRA_CANCEL =
            "dev.kartpad.android.TEST_RETRO_REWIND_WORKER_CANCEL"
        const val EXTRA_VERSION_CHECK =
            "dev.kartpad.android.TEST_RETRO_REWIND_VERSION_CHECK"
    }
}
