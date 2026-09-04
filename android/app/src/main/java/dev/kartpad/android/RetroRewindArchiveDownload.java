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

/** Downloads and verifies the one profile-pinned Retro Rewind archive. */
final class RetroRewindArchiveDownload {
    private static final int BUFFER_BYTES = 1024 * 1024;
    private static final int MAXIMUM_REDIRECTS = 5;
    private static final int CONNECT_TIMEOUT_MILLIS = 30_000;
    private static final int READ_TIMEOUT_MILLIS = 30_000;

    interface Cancellation {
        boolean isCancelled();
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
        if (!isRealDirectory(cacheDirectory)) {
            return result(Error.INVALID_CACHE, false);
        }

        Path archive = cacheDirectory.resolve(
                "RetroRewind-" + RetroRewindRelease.VERSION + ".zip");
        if (verifyFile(archive, RetroRewindRelease.ARCHIVE_BYTES,
                RetroRewindRelease.ARCHIVE_SHA256) == Error.NONE) {
            return result(Error.NONE, true);
        }

        Path partial;
        try {
            partial = Files.createTempFile(cacheDirectory,
                    ".RetroRewind-" + RetroRewindRelease.VERSION + "-", ".part");
        } catch (IOException exception) {
            return result(Error.STORAGE_FAILURE, false);
        }

        try {
            Result transfer = downloadPinned(partial, cancellation);
            if (!transfer.isReady()) {
                return transfer;
            }
            try {
                Files.move(partial, archive, StandardCopyOption.ATOMIC_MOVE,
                        StandardCopyOption.REPLACE_EXISTING);
                return result(Error.NONE, false);
            } catch (IOException exception) {
                return result(Error.STORAGE_FAILURE, false);
            }
        } finally {
            try {
                Files.deleteIfExists(partial);
            } catch (IOException ignored) {
                // A private, unverified .part file is never treated as an archive.
            }
        }
    }

    private static Result downloadPinned(Path partial, Cancellation cancellation) {
        URL current;
        try {
            current = new URL(RetroRewindRelease.ARCHIVE_URL);
        } catch (IOException exception) {
            return result(Error.NETWORK_FAILURE, false);
        }

        for (int redirects = 0; redirects <= MAXIMUM_REDIRECTS; redirects++) {
            if (!"https".equalsIgnoreCase(current.getProtocol())) {
                return result(Error.INSECURE_REDIRECT, false);
            }

            HttpURLConnection connection = null;
            try {
                connection = (HttpURLConnection) current.openConnection();
                connection.setInstanceFollowRedirects(false);
                connection.setConnectTimeout(CONNECT_TIMEOUT_MILLIS);
                connection.setReadTimeout(READ_TIMEOUT_MILLIS);
                connection.setRequestProperty("Accept-Encoding", "identity");
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
                if (response != HttpURLConnection.HTTP_OK) {
                    return result(Error.HTTP_FAILURE, false);
                }
                String encoding = connection.getContentEncoding();
                if (encoding != null && !"identity".equalsIgnoreCase(encoding)) {
                    return result(Error.HTTP_FAILURE, false);
                }
                long declaredBytes = connection.getContentLengthLong();
                if (declaredBytes >= 0 && declaredBytes != RetroRewindRelease.ARCHIVE_BYTES) {
                    return result(Error.SIZE_MISMATCH, false);
                }
                try (InputStream input = new BufferedInputStream(connection.getInputStream())) {
                    Error error = transfer(input, partial, RetroRewindRelease.ARCHIVE_BYTES,
                            RetroRewindRelease.ARCHIVE_SHA256, cancellation);
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
        byte[] expectedDigest = decodeSha256(expectedSha256);
        if (expectedBytes < 0 || expectedDigest == null || cancellation == null) {
            return Error.STORAGE_FAILURE;
        }

        MessageDigest digest;
        try {
            digest = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException exception) {
            return Error.STORAGE_FAILURE;
        }

        OutputStream openedOutput;
        try {
            openedOutput = Files.newOutputStream(partial,
                    StandardOpenOption.WRITE, StandardOpenOption.TRUNCATE_EXISTING);
        } catch (IOException exception) {
            return Error.STORAGE_FAILURE;
        }

        long total = 0;
        byte[] buffer = new byte[BUFFER_BYTES];
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
