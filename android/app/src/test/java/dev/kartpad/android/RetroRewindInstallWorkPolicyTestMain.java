package dev.kartpad.android;

public final class RetroRewindInstallWorkPolicyTestMain {
    private RetroRewindInstallWorkPolicyTestMain() {}

    public static void main(String[] args) {
        expectDownload(RetroRewindArchiveDownload.Error.NONE,
                RetroRewindInstallWorkPolicy.Action.CONTINUE);
        expectDownload(RetroRewindArchiveDownload.Error.NETWORK_FAILURE,
                RetroRewindInstallWorkPolicy.Action.RETRY);
        expectDownload(RetroRewindArchiveDownload.Error.HTTP_FAILURE,
                RetroRewindInstallWorkPolicy.Action.FAILURE);
        expectDownload(RetroRewindArchiveDownload.Error.CANCELLED,
                RetroRewindInstallWorkPolicy.Action.CANCELLED);
        expectDownload(RetroRewindArchiveDownload.Error.HASH_MISMATCH,
                RetroRewindInstallWorkPolicy.Action.FAILURE);
        expectDownload(RetroRewindArchiveDownload.Error.SIZE_MISMATCH,
                RetroRewindInstallWorkPolicy.Action.FAILURE);

        expectInstall(
                new RetroRewindInstallPipeline.Result(
                        RetroRewindInstallPipeline.Error.NONE,
                        RetroRewindArchiveExtractor.Error.NONE,
                        RetroRewindInstallValidator.Error.NONE),
                RetroRewindInstallWorkPolicy.Action.CONTINUE);
        expectInstall(
                new RetroRewindInstallPipeline.Result(
                        RetroRewindInstallPipeline.Error.EXTRACTION_FAILURE,
                        RetroRewindArchiveExtractor.Error.CANCELLED,
                        null),
                RetroRewindInstallWorkPolicy.Action.CANCELLED);
        expectInstall(
                new RetroRewindInstallPipeline.Result(
                        RetroRewindInstallPipeline.Error.CONTENT_INVALID,
                        RetroRewindArchiveExtractor.Error.NONE,
                        RetroRewindInstallValidator.Error.HASH_MISMATCH),
                RetroRewindInstallWorkPolicy.Action.FAILURE);
        System.out.println("Android Retro Rewind worker policy passed.");
    }

    private static void expectDownload(
            RetroRewindArchiveDownload.Error error,
            RetroRewindInstallWorkPolicy.Action expected) {
        expect(RetroRewindInstallWorkPolicy.afterDownload(error) == expected,
                "unexpected download action for " + error);
    }

    private static void expectInstall(
            RetroRewindInstallPipeline.Result result,
            RetroRewindInstallWorkPolicy.Action expected) {
        expect(RetroRewindInstallWorkPolicy.afterInstall(result) == expected,
                "unexpected install action for " + result.error);
    }

    private static void expect(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
