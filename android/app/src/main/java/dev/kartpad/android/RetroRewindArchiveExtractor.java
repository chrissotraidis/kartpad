package dev.kartpad.android;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;

/** Android owner for bounded native Retro Rewind ZIP extraction. */
final class RetroRewindArchiveExtractor {
    private static final int MAXIMUM_ENTRIES = 10_000;

    /**
     * Loads the JNI owner only when extraction is actually requested.
     *
     * Keeping this lazy lets host-side policy tests use the Java result types,
     * while ensuring a cold WorkManager process does not depend on an SDL
     * Activity having loaded the library first.
     */
    private static final class NativeLibrary {
        static {
            System.loadLibrary("main");
        }

        private NativeLibrary() {}

        static void ensureLoaded() {}
    }

    interface Cancellation {
        boolean isCancelled();
    }

    interface Progress {
        void onProgress(long extractedBytes, long totalBytes);
    }

    enum Error {
        NONE,
        CANCELLED,
        INVALID_ARGUMENT,
        OPEN_FAILED,
        MALFORMED_ARCHIVE,
        UNSUPPORTED_ENTRY,
        DUPLICATE_ENTRY,
        LIMIT_EXCEEDED,
        MISSING_ROOT,
        IO_FAILURE,
    }

    static final class Result {
        final Error error;
        final long selectedEntries;
        final long selectedBytes;
        final long extractedBytes;

        Result(Error error, long[] counts) {
            this.error = error;
            selectedEntries = counts[0];
            selectedBytes = counts[1];
            extractedBytes = counts[2];
        }

        boolean isComplete() {
            return error == Error.NONE;
        }
    }

    private RetroRewindArchiveExtractor() {}

    static Result extract(
            Path archive,
            Path stagingDirectory,
            Cancellation cancellation,
            Progress progress) throws IOException {
        if (!Files.isRegularFile(archive, LinkOption.NOFOLLOW_LINKS) ||
                !Files.isDirectory(stagingDirectory, LinkOption.NOFOLLOW_LINKS) ||
                cancellation == null || progress == null) {
            throw new IOException("Retro Rewind extraction input is invalid");
        }
        Path root = stagingDirectory.resolve(RetroRewindRelease.ROOT);
        if (Files.exists(root, LinkOption.NOFOLLOW_LINKS)) {
            throw new IOException("Retro Rewind extraction destination is not empty");
        }

        NativeLibrary.ensureLoaded();
        long[] counts = new long[3];
        int code = nativeExtract(
                archive.toAbsolutePath().toString(),
                stagingDirectory.toAbsolutePath().toString(),
                RetroRewindRelease.ROOT,
                MAXIMUM_ENTRIES,
                RetroRewindRelease.MAXIMUM_EXPANDED_BYTES,
                cancellation,
                progress,
                counts);
        Error[] errors = Error.values();
        Error error = code >= 0 && code < errors.length
                ? errors[code] : Error.IO_FAILURE;
        return new Result(error, counts);
    }

    private static native int nativeExtract(
            String archivePath,
            String stagingDirectory,
            String expectedRoot,
            int maximumEntries,
            long maximumExpandedBytes,
            Cancellation cancellation,
            Progress progress,
            long[] counts);
}
