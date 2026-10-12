package dev.kartpad.android;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.stream.Stream;

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

    static Result extractRelease(Path archive, Path stagingDirectory,
            Cancellation cancellation, Progress progress) throws IOException {
        Result base = extract(archive, stagingDirectory, cancellation, progress);
        if (!base.isComplete() || RetroRewindRelease.UPDATE_BYTES == 0) return base;
        Path patchStage = Files.createDirectory(stagingDirectory.resolve(".update"));
        Result update = extractBounded(RetroRewindArchiveDownload.updatePath(archive.getParent()),
                patchStage, cancellation, progress, RetroRewindRelease.UPDATE_MAXIMUM_EXPANDED_BYTES);
        if (!update.isComplete()) return update;
        try {
            mergeUpdate(patchStage.resolve(RetroRewindRelease.ROOT),
                    stagingDirectory.resolve(RetroRewindRelease.ROOT), cancellation);
        } catch (IOException failure) {
            if (cancellation.isCancelled()) return new Result(Error.CANCELLED, new long[3]);
            throw failure;
        }
        Files.delete(patchStage);
        return update;
    }

    // Both trees are private staging outputs from the bounded native extractor.
    // Never merge into the active installation: final validation/activation owns that step.
    static void mergeUpdate(Path source, Path target, Cancellation cancellation) throws IOException {
        try (Stream<Path> entries = Files.list(source)) {
            for (Path entry : (Iterable<Path>) entries::iterator) {
                if (cancellation.isCancelled()) throw new IOException("Update cancelled");
                Path output = target.resolve(entry.getFileName());
                if (Files.isDirectory(entry, LinkOption.NOFOLLOW_LINKS)) {
                    if (!Files.exists(output, LinkOption.NOFOLLOW_LINKS)) Files.createDirectory(output);
                    if (!Files.isDirectory(output, LinkOption.NOFOLLOW_LINKS))
                        throw new IOException("Update directory conflicts with a file");
                    mergeUpdate(entry, output, cancellation);
                } else {
                    if (!Files.isRegularFile(entry, LinkOption.NOFOLLOW_LINKS) ||
                            (Files.exists(output, LinkOption.NOFOLLOW_LINKS) &&
                             !Files.isRegularFile(output, LinkOption.NOFOLLOW_LINKS)))
                        throw new IOException("Update entry is not a regular file");
                    Files.move(entry, output, StandardCopyOption.REPLACE_EXISTING);
                }
            }
        }
        Files.delete(source);
    }

    static Result extract(
            Path archive,
            Path stagingDirectory,
            Cancellation cancellation,
            Progress progress) throws IOException {
        return extractBounded(archive, stagingDirectory, cancellation, progress,
                RetroRewindRelease.MAXIMUM_EXPANDED_BYTES);
    }

    private static Result extractBounded(Path archive, Path stagingDirectory,
            Cancellation cancellation, Progress progress, long maximumBytes) throws IOException {
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
                maximumBytes,
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
