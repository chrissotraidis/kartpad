package dev.kartpad.android

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.util.UUID

/** Stable entry point for the one durable Retro Rewind installation. */
internal object RetroRewindInstallWork {
    const val UNIQUE_NAME = "kartpad-retro-rewind-install"
    const val TAG = "kartpad-retro-rewind-install"
    const val KEY_TOKEN = "install_token"
    const val KEY_PHASE = "phase"
    const val KEY_COMPLETED_BYTES = "completed_bytes"
    const val KEY_TOTAL_BYTES = "total_bytes"
    const val KEY_ERROR = "error"
    const val KEY_DEBUG_FIXTURE = "debug_fixture"
    const val KEY_DEBUG_FIXTURE_STEPS = "debug_fixture_steps"
    const val KEY_DEBUG_FIXTURE_DELAY_MILLIS = "debug_fixture_delay_millis"

    fun enqueue(context: Context) {
        val token = UUID.randomUUID().toString()
        val request = OneTimeWorkRequestBuilder<RetroRewindInstallWorker>()
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .setInputData(workDataOf(KEY_TOKEN to token))
            .addTag(TAG)
            .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
            UNIQUE_NAME,
            ExistingWorkPolicy.KEEP,
            request,
        )
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context.applicationContext).cancelUniqueWork(UNIQUE_NAME)
    }

    fun enqueueDebugFixture(
        context: Context,
        steps: Int = 3,
        delayMillis: Long = 250,
    ): UUID {
        check(BuildConfig.DEBUG && !BuildConfig.GAME_RUNTIME)
        check(steps in 1..120)
        check(delayMillis in 1..5_000)
        val request = OneTimeWorkRequestBuilder<RetroRewindInstallWorker>()
            .setInputData(
                workDataOf(
                    KEY_TOKEN to "debug-fixture",
                    KEY_DEBUG_FIXTURE to true,
                    KEY_DEBUG_FIXTURE_STEPS to steps,
                    KEY_DEBUG_FIXTURE_DELAY_MILLIS to delayMillis,
                ),
            )
            .addTag(TAG)
            .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
            UNIQUE_NAME,
            ExistingWorkPolicy.KEEP,
            request,
        )
        return request.id
    }
}
