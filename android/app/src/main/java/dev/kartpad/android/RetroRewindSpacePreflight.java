package dev.kartpad.android;

/** Pure free-space accounting for the Android Retro Rewind installer. */
final class RetroRewindSpacePreflight {
    static final long RESERVE_BYTES = 256L * 1024L * 1024L;

    enum Error {
        NONE,
        INVALID_REQUIREMENT,
        INSUFFICIENT_SHARED_STORE,
        INSUFFICIENT_FILES_STORE,
        INSUFFICIENT_CACHE_STORE,
        PROBE_FAILED,
    }

    static final class Result {
        final Error error;
        final long requiredFilesBytes;
        final long requiredCacheBytes;
        final long availableFilesBytes;
        final long availableCacheBytes;

        Result(
                Error error,
                long requiredFilesBytes,
                long requiredCacheBytes,
                long availableFilesBytes,
                long availableCacheBytes) {
            this.error = error;
            this.requiredFilesBytes = requiredFilesBytes;
            this.requiredCacheBytes = requiredCacheBytes;
            this.availableFilesBytes = availableFilesBytes;
            this.availableCacheBytes = availableCacheBytes;
        }

        boolean isReady() {
            return error == Error.NONE;
        }
    }

    private RetroRewindSpacePreflight() {}

    static Result evaluate(
            long availableFilesBytes,
            long availableCacheBytes,
            boolean sameStore,
            long archiveBytes,
            long maximumExpandedBytes) {
        return evaluate(
                availableFilesBytes,
                availableCacheBytes,
                sameStore,
                archiveBytes,
                maximumExpandedBytes,
                0);
    }

    static Result evaluate(
            long availableFilesBytes,
            long availableCacheBytes,
            boolean sameStore,
            long archiveBytes,
            long maximumExpandedBytes,
            long reusableArchiveBytes) {
        if (availableFilesBytes < 0 || availableCacheBytes < 0 ||
                archiveBytes < 0 || maximumExpandedBytes < 0 ||
                reusableArchiveBytes < 0 || reusableArchiveBytes > archiveBytes) {
            return result(Error.INVALID_REQUIREMENT, 0, 0,
                    availableFilesBytes, availableCacheBytes);
        }

        long remainingArchiveBytes = archiveBytes - reusableArchiveBytes;

        if (sameStore) {
            long required = checkedAdd(remainingArchiveBytes, maximumExpandedBytes);
            required = checkedAdd(required, RESERVE_BYTES);
            if (required < 0) {
                return result(Error.INVALID_REQUIREMENT, 0, 0,
                        availableFilesBytes, availableCacheBytes);
            }
            Error error = availableFilesBytes >= required
                    ? Error.NONE : Error.INSUFFICIENT_SHARED_STORE;
            return result(error, required, 0,
                    availableFilesBytes, availableCacheBytes);
        }

        long requiredFiles = checkedAdd(maximumExpandedBytes, RESERVE_BYTES);
        long requiredCache = checkedAdd(remainingArchiveBytes, RESERVE_BYTES);
        if (requiredFiles < 0 || requiredCache < 0) {
            return result(Error.INVALID_REQUIREMENT, 0, 0,
                    availableFilesBytes, availableCacheBytes);
        }
        if (availableFilesBytes < requiredFiles) {
            return result(Error.INSUFFICIENT_FILES_STORE, requiredFiles, requiredCache,
                    availableFilesBytes, availableCacheBytes);
        }
        if (availableCacheBytes < requiredCache) {
            return result(Error.INSUFFICIENT_CACHE_STORE, requiredFiles, requiredCache,
                    availableFilesBytes, availableCacheBytes);
        }
        return result(Error.NONE, requiredFiles, requiredCache,
                availableFilesBytes, availableCacheBytes);
    }

    static Result probeFailed() {
        return result(Error.PROBE_FAILED, 0, 0, 0, 0);
    }

    private static long checkedAdd(long left, long right) {
        if (left < 0 || right < 0 || left > Long.MAX_VALUE - right) {
            return -1;
        }
        return left + right;
    }

    private static Result result(
            Error error,
            long requiredFilesBytes,
            long requiredCacheBytes,
            long availableFilesBytes,
            long availableCacheBytes) {
        return new Result(error, requiredFilesBytes, requiredCacheBytes,
                availableFilesBytes, availableCacheBytes);
    }
}
