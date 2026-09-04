package dev.kartpad.android;

public final class RetroRewindSpacePreflightTestMain {
    private RetroRewindSpacePreflightTestMain() {}

    public static void main(String[] args) {
        long archive = 1_000;
        long expanded = 2_000;
        long reserve = RetroRewindSpacePreflight.RESERVE_BYTES;

        var sharedReady = RetroRewindSpacePreflight.evaluate(
                archive + expanded + reserve, 0, true, archive, expanded);
        expect(sharedReady.isReady(), "exact shared-store capacity was rejected");
        expect(sharedReady.requiredFilesBytes == archive + expanded + reserve,
                "shared-store requirement is incorrect");
        expect(sharedReady.requiredCacheBytes == 0,
                "shared-store cache requirement should be folded into files");

        expectError(
                RetroRewindSpacePreflight.evaluate(
                        archive + expanded + reserve - 1, Long.MAX_VALUE,
                        true, archive, expanded),
                RetroRewindSpacePreflight.Error.INSUFFICIENT_SHARED_STORE);

        var separateReady = RetroRewindSpacePreflight.evaluate(
                expanded + reserve, archive + reserve, false, archive, expanded);
        expect(separateReady.isReady(), "exact separate-store capacity was rejected");
        expect(separateReady.requiredFilesBytes == expanded + reserve,
                "files-store requirement is incorrect");
        expect(separateReady.requiredCacheBytes == archive + reserve,
                "cache-store requirement is incorrect");

        expectError(
                RetroRewindSpacePreflight.evaluate(
                        expanded + reserve - 1, Long.MAX_VALUE,
                        false, archive, expanded),
                RetroRewindSpacePreflight.Error.INSUFFICIENT_FILES_STORE);
        expectError(
                RetroRewindSpacePreflight.evaluate(
                        Long.MAX_VALUE, archive + reserve - 1,
                        false, archive, expanded),
                RetroRewindSpacePreflight.Error.INSUFFICIENT_CACHE_STORE);

        expectError(
                RetroRewindSpacePreflight.evaluate(
                        Long.MAX_VALUE, Long.MAX_VALUE, true,
                        Long.MAX_VALUE, 1),
                RetroRewindSpacePreflight.Error.INVALID_REQUIREMENT);
        expectError(
                RetroRewindSpacePreflight.evaluate(
                        -1, 0, true, archive, expanded),
                RetroRewindSpacePreflight.Error.INVALID_REQUIREMENT);
        expectError(
                RetroRewindSpacePreflight.probeFailed(),
                RetroRewindSpacePreflight.Error.PROBE_FAILED);

        var production = RetroRewindSpacePreflight.evaluate(
                Long.MAX_VALUE, Long.MAX_VALUE, true,
                RetroRewindRelease.ARCHIVE_BYTES,
                RetroRewindRelease.MAXIMUM_EXPANDED_BYTES);
        expect(production.isReady(), "production requirements overflowed");
        expect(production.requiredFilesBytes == 4_327_477_355L,
                "production shared-store requirement drifted");
    }

    private static void expectError(
            RetroRewindSpacePreflight.Result result,
            RetroRewindSpacePreflight.Error expected) {
        expect(!result.isReady() && result.error == expected,
                "expected " + expected + ", got " + result.error);
    }

    private static void expect(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
