package dev.kartpad.android;

/** Pure retry/failure policy for the durable Retro Rewind install worker. */
final class RetroRewindInstallWorkPolicy {
    enum Action {
        CONTINUE,
        RETRY,
        FAILURE,
        CANCELLED,
    }

    private RetroRewindInstallWorkPolicy() {}

    static Action afterDownload(RetroRewindArchiveDownload.Error error) {
        if (error == RetroRewindArchiveDownload.Error.NONE) {
            return Action.CONTINUE;
        }
        if (error == RetroRewindArchiveDownload.Error.CANCELLED) {
            return Action.CANCELLED;
        }
        if (error == RetroRewindArchiveDownload.Error.NETWORK_FAILURE) {
            return Action.RETRY;
        }
        return Action.FAILURE;
    }

    static Action afterInstall(RetroRewindInstallPipeline.Result result) {
        if (result.isInstalled()) {
            return Action.CONTINUE;
        }
        if (result.extractionError == RetroRewindArchiveExtractor.Error.CANCELLED) {
            return Action.CANCELLED;
        }
        return Action.FAILURE;
    }
}
