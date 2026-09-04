package dev.kartpad.android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ForegroundInfo
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import java.io.InputStream
import java.nio.file.Files
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

/** Durable, unique foreground worker for the production Retro Rewind install. */
internal class RetroRewindInstallWorker(
    appContext: Context,
    parameters: WorkerParameters,
) : CoroutineWorker(appContext, parameters) {
    override suspend fun getForegroundInfo(): ForegroundInfo = foregroundInfo("Preparing installation…")

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val token = inputData.getString(RetroRewindInstallWork.KEY_TOKEN)
            ?: return@withContext failure("missing-token")
        setForeground(foregroundInfo("Preparing installation…"))
        if (inputData.getBoolean(RetroRewindInstallWork.KEY_DEBUG_FIXTURE, false)) {
            if (!BuildConfig.DEBUG || BuildConfig.GAME_RUNTIME) {
                return@withContext failure("fixture-disabled")
            }
            return@withContext runDebugFixture()
        }
        try {
            RetroRewindInstallStorage.recover(applicationContext.filesDir)
        } catch (_: Exception) {
            return@withContext failure("recovery")
        }

        setPhase("space", 0, 0)
        val space = RetroRewindSpaceProbe.check(
            applicationContext.filesDir,
            applicationContext.cacheDir,
        )
        if (!space.isReady) {
            return@withContext failure("space-${space.error.name.lowercase()}")
        }

        setForeground(foregroundInfo("Downloading Retro Rewind…"))
        setPhase("download", 0, RetroRewindRelease.ARCHIVE_BYTES)
        var lastDownloadPercent = -1L
        val download = RetroRewindArchiveDownload.downloadRelease(
            applicationContext.cacheDir.toPath(),
            { isStopped },
            { completed, total ->
                val percent = if (total == 0L) 0L else completed * 100L / total
                if (percent != lastDownloadPercent) {
                    lastDownloadPercent = percent
                    setProgressAsync(progressData("download", completed, total))
                    setForegroundAsync(
                        foregroundInfo("Downloading Retro Rewind…", completed, total),
                    )
                }
            },
        )
        when (RetroRewindInstallWorkPolicy.afterDownload(download.error)) {
            RetroRewindInstallWorkPolicy.Action.RETRY -> return@withContext Result.retry()
            RetroRewindInstallWorkPolicy.Action.FAILURE ->
                return@withContext failure("download-${download.error.name.lowercase()}")
            RetroRewindInstallWorkPolicy.Action.CANCELLED ->
                return@withContext failure("cancelled")
            RetroRewindInstallWorkPolicy.Action.CONTINUE -> Unit
        }

        setForeground(foregroundInfo("Installing Retro Rewind…"))
        setPhase("extract", 0, 0)
        var lastExtractPercent = -1L
        val install = RetroRewindInstallPipeline.install(
            applicationContext.filesDir,
            RetroRewindArchiveDownload.archivePath(applicationContext.cacheDir.toPath()),
            token,
            { isStopped },
            { completed, total ->
                val percent = if (total == 0L) 0L else completed * 100L / total
                if (percent != lastExtractPercent) {
                    lastExtractPercent = percent
                    setProgressAsync(progressData("extract", completed, total))
                    setForegroundAsync(
                        foregroundInfo("Installing Retro Rewind…", completed, total),
                    )
                }
            },
        )
        when (RetroRewindInstallWorkPolicy.afterInstall(install)) {
            RetroRewindInstallWorkPolicy.Action.CONTINUE -> Unit
            RetroRewindInstallWorkPolicy.Action.CANCELLED ->
                return@withContext failure("cancelled")
            else -> return@withContext failure("install-${install.error.name.lowercase()}")
        }

        try {
            Files.deleteIfExists(
                RetroRewindArchiveDownload.archivePath(applicationContext.cacheDir.toPath()),
            )
        } catch (_: Exception) {
            // A verified cache file is safe to reuse or remove on a later launch.
        }
        setPhase("installed", 1, 1)
        Result.success(progressData("installed", 1, 1))
    }

    private suspend fun setPhase(phase: String, completed: Long, total: Long) {
        setProgress(progressData(phase, completed, total))
    }

    private suspend fun runDebugFixture(): Result {
        if (inputData.getBoolean(
                RetroRewindInstallWork.KEY_DEBUG_RESUME_PROCESS_DEATH,
                false,
            )
        ) {
            return runDebugResumeProcessDeathFixture()
        }
        val steps = inputData.getInt(RetroRewindInstallWork.KEY_DEBUG_FIXTURE_STEPS, 3)
        val delayMillis = inputData.getLong(
            RetroRewindInstallWork.KEY_DEBUG_FIXTURE_DELAY_MILLIS,
            250,
        )
        if (steps !in 1..120 || delayMillis !in 1..5_000) {
            return failure("invalid-fixture-input")
        }
        Log.i(
            LOG_TAG,
            "A3 durable worker fixture started id=$id attempt=$runAttemptCount steps=$steps",
        )
        for (step in 1L..steps.toLong()) {
            if (isStopped) return failure("cancelled")
            setPhase("fixture", step, steps.toLong())
            delay(delayMillis)
        }
        Log.i(LOG_TAG, "A3 durable worker fixture completed id=$id attempt=$runAttemptCount")
        return Result.success(progressData("installed", 1, 1))
    }

    private suspend fun runDebugResumeProcessDeathFixture(): Result {
        val content = DEBUG_RESUME_CONTENT.toByteArray(Charsets.UTF_8)
        val partial = applicationContext.cacheDir.toPath().resolve(
            RetroRewindInstallWork.DEBUG_RESUME_PARTIAL,
        )
        val prefix = try {
            RetroRewindArchiveDownload.preparePartial(
                partial,
                content.size.toLong(),
                DEBUG_RESUME_SHA256,
            )
        } catch (_: Exception) {
            return failure("fixture-storage")
        }
        Log.i(
            LOG_TAG,
            "A3 durable resume fixture started id=$id attempt=$runAttemptCount prefix=$prefix",
        )
        var checkpointLogged = false
        val result = RetroRewindArchiveDownload.transferResuming(
            SlowFixtureInputStream(content, prefix.toInt()),
            partial,
            content.size.toLong(),
            DEBUG_RESUME_SHA256,
            prefix,
            { isStopped },
            { completed, total ->
                setProgressAsync(progressData("fixture-resume", completed, total))
                if (!checkpointLogged && completed >= DEBUG_RESUME_CHECKPOINT) {
                    checkpointLogged = true
                    Log.i(
                        LOG_TAG,
                        "A3 durable resume fixture checkpoint id=$id bytes=$completed",
                    )
                }
            },
        )
        if (result != RetroRewindArchiveDownload.Error.NONE) {
            return failure("fixture-${result.name.lowercase()}")
        }
        Files.deleteIfExists(partial)
        Log.i(
            LOG_TAG,
            "A3 durable resume fixture completed id=$id attempt=$runAttemptCount",
        )
        return Result.success(progressData("installed", 1, 1))
    }

    private fun failure(error: String): Result = Result.failure(
        workDataOf(
            RetroRewindInstallWork.KEY_PHASE to "failed",
            RetroRewindInstallWork.KEY_ERROR to error,
        ),
    )

    private fun foregroundInfo(
        message: String,
        completed: Long = 0,
        total: Long = 0,
    ): ForegroundInfo {
        val notifications = applicationContext.getSystemService(NotificationManager::class.java)
        notifications.createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL,
                "Game data installation",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        val notificationBuilder = Notification.Builder(applicationContext, NOTIFICATION_CHANNEL)
            .setSmallIcon(R.drawable.ic_kartpad)
            .setContentTitle("KartPad")
            .setContentText(message)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        if (total > 0 && completed in 0..total) {
            notificationBuilder.setProgress(
                PROGRESS_MAX,
                (completed * PROGRESS_MAX / total).toInt(),
                false,
            )
        } else {
            notificationBuilder.setProgress(0, 0, true)
        }
        val notification = notificationBuilder.build()
        return if (Build.VERSION.SDK_INT >= 29) {
            ForegroundInfo(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            ForegroundInfo(NOTIFICATION_ID, notification)
        }
    }

    private fun progressData(phase: String, completed: Long, total: Long) = workDataOf(
        RetroRewindInstallWork.KEY_PHASE to phase,
        RetroRewindInstallWork.KEY_COMPLETED_BYTES to completed,
        RetroRewindInstallWork.KEY_TOTAL_BYTES to total,
    )

    companion object {
        private const val NOTIFICATION_CHANNEL = "kartpad-game-data-install"
        private const val NOTIFICATION_ID = 0x4b50
        private const val PROGRESS_MAX = 100
        private const val LOG_TAG = "KartPadFixture"
        private const val DEBUG_RESUME_CONTENT =
            "durable-resume-fixture-durable-resume-fixture-" +
                "durable-resume-fixture-durable-resume-fixture-"
        private const val DEBUG_RESUME_SHA256 =
            "4eba5a46f29cdb266bf45bfe41d037dfcbe7cfe9d785f12e59af84ea4ecd3e34"
        private const val DEBUG_RESUME_CHECKPOINT = 4L
    }

    private class SlowFixtureInputStream(
        private val content: ByteArray,
        private var offset: Int,
    ) : InputStream() {
        override fun read(): Int {
            if (offset >= content.size) return -1
            if (!sleep()) return -1
            return content[offset++].toInt() and 0xff
        }

        override fun read(output: ByteArray, outputOffset: Int, length: Int): Int {
            if (offset >= content.size) return -1
            if (length == 0) return 0
            if (!sleep()) return -1
            output[outputOffset] = content[offset++]
            return 1
        }

        private fun sleep(): Boolean = try {
            Thread.sleep(250)
            true
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
    }
}
