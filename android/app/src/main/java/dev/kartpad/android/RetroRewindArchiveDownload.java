package dev.kartpad.android;

import java.io.BufferedInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Downloads and verifies the one profile-pinned Retro Rewind archive. */
final class RetroRewindArchiveDownload {
    private static final int BUFFER_BYTES = 1024 * 1024;
    private static final int MAXIMUM_REDIRECTS = 5;
    private static final int CONNECT_TIMEOUT_MILLIS = 30_000;
    private static final int READ_TIMEOUT_MILLIS = 30_000;
    private static final Pattern CONTENT_RANGE = Pattern.compile(
            "bytes ([0-9]+)-([0-9]+)/([0-9]+)");

    interface Cancellation {
        boolean isCancelled();
    }

    interface Progress {
        void onProgress(long downloadedBytes, long totalBytes);
    }

    enum Error {
        NONE,
        CANCELLED,
        INVALID_CACHE,
        INSECURE_REDIRECT,
        TOO_MANY_REDIRECTS,
        HTTP_FAILURE,
        NETWORK_FAILURE,
        SIZE_MISMATCH,
        HASH_MISMATCH,
        STORAGE_FAILURE,
    }

    static final class Result {
        final Error error;
        final boolean reusedExisting;

        Result(Error error, boolean reusedExisting) {
            this.error = error;
            this.reusedExisting = reusedExisting;
        }

        boolean isReady() {
            return error == Error.NONE;
        }
    }

    private RetroRewindArchiveDownload() {}

    static Result downloadRelease(Path cacheDirectory, Cancellation cancellation) {
        return downloadRelease(cacheDirectory, cancellation, (downloaded, total) -> {});
    }

    static Result downloadRelease(
            Path cacheDirectory, Cancellation cancellation, Progress progress) {
        if (!isRealDirectory(cacheDirectory)) {
            return result(Error.INVALID_CACHE, false);
        }

        Path archive = archivePath(cacheDirectory);
        if (verifyFile(archive, RetroRewindRelease.ARCHIVE_BYTES,
                RetroRewindRelease.ARCHIVE_SHA256) == Error.NONE) {
            deletePartial(partialPath(cacheDirectory));
            return result(Error.NONE, true);
        }

        Path partial = partialPath(cacheDirectory);
        long existingBytes;
        try {
            existingBytes = preparePartial(partial, RetroRewindRelease.ARCHIVE_BYTES,
                    RetroRewindRelease.ARCHIVE_SHA256);
        } catch (IOException exception) {
            return result(Error.STORAGE_FAILURE, false);
        }

        if (existingBytes == RetroRewindRelease.ARCHIVE_BYTES) {
            try {
                Files.move(partial, archive, StandardCopyOption.ATOMIC_MOVE,
                        StandardCopyOption.REPLACE_EXISTING);
                return result(Error.NONE, true);
            } catch (IOException exception) {
                return result(Error.STORAGE_FAILURE, false);
            }
        }

        Result transfer = downloadPinned(partial, existingBytes, cancellation, progress);
        if (!transfer.isReady()) {
            if (transfer.error != Error.CANCELLED &&
                    transfer.error != Error.NETWORK_FAILURE &&
                    transfer.error != Error.STORAGE_FAILURE) {
                deletePartial(partial);
            }
            return transfer;
        }
        try {
            if (verifyFile(partial, RetroRewindRelease.ARCHIVE_BYTES,
                    RetroRewindRelease.ARCHIVE_SHA256) != Error.NONE) {
                deletePartial(partial);
                return result(Error.HASH_MISMATCH, false);
            }
            try {
                Files.move(partial, archive, StandardCopyOption.ATOMIC_MOVE,
                        StandardCopyOption.REPLACE_EXISTING);
                return result(Error.NONE, false);
            } catch (IOException exception) {
                return result(Error.STORAGE_FAILURE, false);
            }
        } catch (RuntimeException exception) {
            deletePartial(partial);
            return result(Error.STORAGE_FAILURE, false);
        }
    }

    static Path archivePath(Path cacheDirectory) {
        return cacheDirectory.resolve(
                "RetroRewind-" + RetroRewindRelease.VERSION + ".zip");
    }

    static Path partialPath(Path cacheDirectory) {
        return cacheDirectory.resolve(
                ".RetroRewind-" + RetroRewindRelease.VERSION + ".part");
    }

    /** Bytes already occupying the cache that the next transfer can reuse or replace in place. */
    static long reusableBytes(Path cacheDirectory) {
        Path archive = archivePath(cacheDirectory);
        if (verifyFile(archive, RetroRewindRelease.ARCHIVE_BYTES,
                RetroRewindRelease.ARCHIVE_SHA256) == Error.NONE) {
            return RetroRewindRelease.ARCHIVE_BYTES;
        }
        Path partial = partialPath(cacheDirectory);
        try {
            if (!Files.isRegularFile(partial, LinkOption.NOFOLLOW_LINKS)) {
                return 0;
            }
            long bytes = Files.size(partial);
            return bytes >= 0 && bytes <= RetroRewindRelease.ARCHIVE_BYTES ? bytes : 0;
        } catch (IOException | SecurityException exception) {
            return 0;
        }
    }

    private static Result downloadPinned(
            Path partial, long resumeOffset, Cancellation cancellation, Progress progress) {
        URL initial;
        try {
            initial = new URL(RetroRewindRelease.ARCHIVE_URL);
        } catch (IOException exception) {
            return result(Error.NETWORK_FAILURE, false);
        }
        return downloadFrom(initial, partial, resumeOffset,
                RetroRewindRelease.ARCHIVE_BYTES, RetroRewindRelease.ARCHIVE_SHA256,
                cancellation, progress);
    }

    static Result downloadFrom(
            URL initial,
            Path partial,
            long resumeOffset,
            long expectedBytes,
            String expectedSha256,
            Cancellation cancellation,
            Progress progress) {
        if (resumeOffset < 0 || resumeOffset > expectedBytes ||
                cancellation == null || progress == null) {
            return result(Error.STORAGE_FAILURE, false);
        }
        URL current = initial;
        for (int redirects = 0; redirects <= MAXIMUM_REDIRECTS; redirects++) {
            if (current == null || !"https".equalsIgnoreCase(current.getProtocol())) {
                return result(Error.INSECURE_REDIRECT, false);
            }

            HttpURLConnection connection = null;
            try {
                connection = (HttpURLConnection) current.openConnection();
                connection.setInstanceFollowRedirects(false);
                connection.setConnectTimeout(CONNECT_TIMEOUT_MILLIS);
                connection.setReadTimeout(READ_TIMEOUT_MILLIS);
                connection.setRequestProperty("Accept-Encoding", "identity");
                if (resumeOffset > 0) {
                    connection.setRequestProperty("Range", "bytes=" + resumeOffset + "-");
                }
                int response = connection.getResponseCode();
                if (isRedirect(response)) {
                    if (redirects == MAXIMUM_REDIRECTS) {
                        return result(Error.TOO_MANY_REDIRECTS, false);
                    }
                    String location = connection.getHeaderField("Location");
                    if (location == null || location.isEmpty()) {
                        return result(Error.HTTP_FAILURE, false);
                    }
                    current = new URL(current, location);
                    continue;
                }
                long transferOffset;
                if (response == HttpURLConnection.HTTP_OK) {
                    transferOffset = 0;
                } else if (response == HttpURLConnection.HTTP_PARTIAL && resumeOffset > 0 &&
                        isCompleteContentRange(connection.getHeaderField("Content-Range"),
                                resumeOffset, expectedBytes)) {
                    transferOffset = resumeOffset;
                } else {
                    return result(Error.HTTP_FAILURE, false);
                }
                String encoding = connection.getContentEncoding();
                if (encoding != null && !"identity".equalsIgnoreCase(encoding)) {
                    return result(Error.HTTP_FAILURE, false);
                }
                long declaredBytes = connection.getContentLengthLong();
                long expectedResponseBytes = expectedBytes - transferOffset;
                if (declaredBytes >= 0 && declaredBytes != expectedResponseBytes) {
                    return result(Error.SIZE_MISMATCH, false);
                }
                try (InputStream input = new BufferedInputStream(connection.getInputStream())) {
                    Error error = transferResuming(input, partial,
                            expectedBytes, expectedSha256, transferOffset,
                            cancellation, progress);
                    return result(error, false);
                }
            } catch (IOException exception) {
                return result(Error.NETWORK_FAILURE, false);
            } finally {
                if (connection != null) {
                    connection.disconnect();
                }
            }
        }
        return result(Error.TOO_MANY_REDIRECTS, false);
    }

    static Error transfer(
            InputStream input,
            Path partial,
            long expectedBytes,
            String expectedSha256,
            Cancellation cancellation) {
        return transfer(input, partial, expectedBytes, expectedSha256,
                cancellation, (downloaded, total) -> {});
    }

    static Error transfer(
            InputStream input,
            Path partial,
            long expectedBytes,
            String expectedSha256,
            Cancellation cancellation,
            Progress progress) {
        return transferResuming(input, partial, expectedBytes, expectedSha256, 0,
                cancellation, progress);
    }

    static Error transferResuming(
            InputStream input,
            Path partial,
            long expectedBytes,
            String expectedSha256,
            long resumeOffset,
            Cancellation cancellation,
            Progress progress) {
        byte[] expectedDigest = decodeSha256(expectedSha256);
        if (expectedBytes < 0 || expectedDigest == null || cancellation == null ||
                progress == null || resumeOffset < 0 || resumeOffset > expectedBytes) {
            return Error.STORAGE_FAILURE;
        }

        MessageDigest digest;
        try {
            digest = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException exception) {
            return Error.STORAGE_FAILURE;
        }

        long total = 0;
        byte[] buffer = new byte[BUFFER_BYTES];
        try {
            if (!Files.isRegularFile(partial, LinkOption.NOFOLLOW_LINKS) ||
                    (resumeOffset > 0 && Files.size(partial) != resumeOffset)) {
                return Error.STORAGE_FAILURE;
            }
            if (resumeOffset > 0) {
                try (InputStream prefix = Files.newInputStream(partial)) {
                    while (total < resumeOffset) {
                        if (cancellation.isCancelled()) {
                            return Error.CANCELLED;
                        }
                        int request = (int) Math.min(buffer.length, resumeOffset - total);
                        int count = prefix.read(buffer, 0, request);
                        if (count <= 0) {
                            return Error.STORAGE_FAILURE;
                        }
                        digest.update(buffer, 0, count);
                        total += count;
                        progress.onProgress(total, expectedBytes);
                    }
                    if (prefix.read() != -1) {
                        return Error.STORAGE_FAILURE;
                    }
                }
            }
        } catch (IOException exception) {
            return Error.STORAGE_FAILURE;
        }

        OutputStream openedOutput;
        try {
            if (resumeOffset == 0) {
                openedOutput = Files.newOutputStream(partial,
                        StandardOpenOption.WRITE, StandardOpenOption.TRUNCATE_EXISTING);
            } else {
                openedOutput = Files.newOutputStream(partial,
                        StandardOpenOption.WRITE, StandardOpenOption.APPEND);
            }
        } catch (IOException exception) {
            return Error.STORAGE_FAILURE;
        }

        try (OutputStream output = openedOutput) {
            while (true) {
                if (cancellation.isCancelled()) {
                    return Error.CANCELLED;
                }
                int count;
                try {
                    count = input.read(buffer);
                } catch (IOException exception) {
                    return Error.NETWORK_FAILURE;
                }
                if (count < 0) {
                    break;
                }
                if (count == 0) {
                    continue;
                }
                if (total > expectedBytes - count) {
                    return Error.SIZE_MISMATCH;
                }
                try {
                    output.write(buffer, 0, count);
                } catch (IOException exception) {
                    return Error.STORAGE_FAILURE;
                }
                digest.update(buffer, 0, count);
                total += count;
                progress.onProgress(total, expectedBytes);
            }
        } catch (IOException exception) {
            return Error.STORAGE_FAILURE;
        }

        if (total != expectedBytes) {
            return Error.SIZE_MISMATCH;
        }
        return MessageDigest.isEqual(digest.digest(), expectedDigest)
                ? Error.NONE : Error.HASH_MISMATCH;
    }

    static Error verifyFile(Path path, long expectedBytes, String expectedSha256) {
        byte[] expectedDigest = decodeSha256(expectedSha256);
        if (!Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS) ||
                expectedBytes < 0 || expectedDigest == null) {
            return Error.STORAGE_FAILURE;
        }
        MessageDigest digest;
        try (InputStream input = Files.newInputStream(path)) {
            if (Files.size(path) != expectedBytes) {
                return Error.SIZE_MISMATCH;
            }
            digest = MessageDigest.getInstance("SHA-256");
            long total = 0;
            byte[] buffer = new byte[BUFFER_BYTES];
            while (true) {
                int count = input.read(buffer);
                if (count < 0) {
                    break;
                }
                if (count == 0) {
                    continue;
                }
                if (total > expectedBytes - count) {
                    return Error.SIZE_MISMATCH;
                }
                digest.update(buffer, 0, count);
                total += count;
            }
            if (total != expectedBytes) {
                return Error.SIZE_MISMATCH;
            }
            return MessageDigest.isEqual(digest.digest(), expectedDigest)
                    ? Error.NONE : Error.HASH_MISMATCH;
        } catch (NoSuchAlgorithmException | IOException exception) {
            return Error.STORAGE_FAILURE;
        }
    }

    private static boolean isRealDirectory(Path path) {
        return path != null && Files.isDirectory(path, LinkOption.NOFOLLOW_LINKS);
    }

    private static boolean isRedirect(int response) {
        return response == HttpURLConnection.HTTP_MOVED_PERM ||
                response == HttpURLConnection.HTTP_MOVED_TEMP ||
                response == HttpURLConnection.HTTP_SEE_OTHER ||
                response == 307 || response == 308;
    }

    static boolean isCompleteContentRange(String value, long offset, long expectedBytes) {
        if (value == null || offset <= 0 || offset >= expectedBytes) {
            return false;
        }
        Matcher match = CONTENT_RANGE.matcher(value);
        if (!match.matches()) {
            return false;
        }
        try {
            long first = Long.parseLong(match.group(1));
            long last = Long.parseLong(match.group(2));
            long total = Long.parseLong(match.group(3));
            return first == offset && last == expectedBytes - 1 && total == expectedBytes;
        } catch (NumberFormatException exception) {
            return false;
        }
    }

    static long preparePartial(
            Path partial, long expectedBytes, String expectedSha256) throws IOException {
        if (Files.exists(partial, LinkOption.NOFOLLOW_LINKS)) {
            if (!Files.isRegularFile(partial, LinkOption.NOFOLLOW_LINKS)) {
                Files.delete(partial);
                Files.createFile(partial);
                return 0;
            }
            long bytes = Files.size(partial);
            if (bytes < 0 || bytes > expectedBytes) {
                Files.delete(partial);
                Files.createFile(partial);
                return 0;
            }
            if (bytes == expectedBytes &&
                    verifyFile(partial, expectedBytes, expectedSha256) != Error.NONE) {
                Files.delete(partial);
                Files.createFile(partial);
                return 0;
            }
            return bytes;
        }
        Files.createFile(partial);
        return 0;
    }

    private static void deletePartial(Path partial) {
        try {
            Files.deleteIfExists(partial);
        } catch (IOException ignored) {
            // The stable app-private partial is never accepted without full verification.
        }
    }

    private static byte[] decodeSha256(String value) {
        if (value == null || value.length() != 64) {
            return null;
        }
        byte[] decoded = new byte[32];
        for (int index = 0; index < decoded.length; index++) {
            int high = Character.digit(value.charAt(index * 2), 16);
            int low = Character.digit(value.charAt(index * 2 + 1), 16);
            if (high < 0 || low < 0) {
                return null;
            }
            decoded[index] = (byte) ((high << 4) | low);
        }
        return decoded;
    }

    private static Result result(Error error, boolean reusedExisting) {
        return new Result(error, reusedExisting);
    }
}
