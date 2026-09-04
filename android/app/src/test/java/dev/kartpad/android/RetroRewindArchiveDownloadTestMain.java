package dev.kartpad.android;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLConnection;
import java.net.URLStreamHandler;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.HexFormat;

public final class RetroRewindArchiveDownloadTestMain {
    private RetroRewindArchiveDownloadTestMain() {}

    public static void main(String[] args) throws Exception {
        Path directory = Files.createTempDirectory("kartpad-archive-download-");
        try {
            byte[] content = "verified archive fixture".getBytes(StandardCharsets.UTF_8);
            String hash = sha256(content);
            Path partial = directory.resolve("fixture.part");
            Files.write(partial, new byte[0]);
            expect(RetroRewindArchiveDownload.partialPath(directory).equals(
                            directory.resolve(".RetroRewind-" +
                                    RetroRewindRelease.VERSION + ".part")),
                    "partial path is not stable and version-scoped");

            long[] progress = {0, 0};
            expectError(RetroRewindArchiveDownload.transfer(
                            new ByteArrayInputStream(content), partial,
                            content.length, hash, () -> false,
                            (downloaded, total) -> {
                                progress[0] = downloaded;
                                progress[1] = total;
                            }),
                    RetroRewindArchiveDownload.Error.NONE);
            expect(progress[0] == content.length && progress[1] == content.length,
                    "successful transfer did not report final progress");
            expect(java.util.Arrays.equals(content, Files.readAllBytes(partial)),
                    "successful transfer bytes changed");
            expectError(RetroRewindArchiveDownload.verifyFile(
                    partial, content.length, hash), RetroRewindArchiveDownload.Error.NONE);

            int resumeOffset = 7;
            Files.write(partial, Arrays.copyOf(content, resumeOffset));
            long[] resumedProgress = {-1, -1};
            expectError(RetroRewindArchiveDownload.transferResuming(
                            new ByteArrayInputStream(
                                    Arrays.copyOfRange(content, resumeOffset, content.length)),
                            partial, content.length, hash, resumeOffset, () -> false,
                            (downloaded, total) -> {
                                if (resumedProgress[0] < 0) {
                                    resumedProgress[0] = downloaded;
                                }
                                resumedProgress[1] = downloaded;
                            }),
                    RetroRewindArchiveDownload.Error.NONE);
            expect(resumedProgress[0] == resumeOffset &&
                            resumedProgress[1] == content.length,
                    "resumed transfer did not include cached and final progress");
            expect(Arrays.equals(content, Files.readAllBytes(partial)),
                    "resumed transfer bytes changed");

            Files.write(partial, Arrays.copyOf(content, resumeOffset));
            expectError(RetroRewindArchiveDownload.transferResuming(
                            new ByteArrayInputStream(
                                    Arrays.copyOfRange(content, resumeOffset, content.length)),
                            partial, content.length, hash, resumeOffset, () -> true,
                            (downloaded, total) -> {}),
                    RetroRewindArchiveDownload.Error.CANCELLED);
            expect(Files.size(partial) == resumeOffset,
                    "cancellation during prefix hashing changed partial bytes");

            Files.write(partial, Arrays.copyOf(content, resumeOffset));
            int bytesBeforeFailure = 3;
            expectError(RetroRewindArchiveDownload.transferResuming(
                            new FailingAfterInputStream(
                                    Arrays.copyOfRange(content, resumeOffset, content.length),
                                    bytesBeforeFailure),
                            partial, content.length, hash, resumeOffset, () -> false,
                            (downloaded, total) -> {}),
                    RetroRewindArchiveDownload.Error.NETWORK_FAILURE);
            long persistedBytes = Files.size(partial);
            expect(persistedBytes == resumeOffset + bytesBeforeFailure,
                    "network loss did not preserve appended partial bytes");
            expectError(RetroRewindArchiveDownload.transferResuming(
                            new ByteArrayInputStream(
                                    Arrays.copyOfRange(
                                            content, (int) persistedBytes, content.length)),
                            partial, content.length, hash, persistedBytes, () -> false,
                            (downloaded, total) -> {}),
                    RetroRewindArchiveDownload.Error.NONE);
            expect(Arrays.equals(content, Files.readAllBytes(partial)),
                    "second resume after network loss changed bytes");

            Files.write(partial, Arrays.copyOf(content, resumeOffset));
            expectError(RetroRewindArchiveDownload.transferResuming(
                            new ByteArrayInputStream(
                                    Arrays.copyOfRange(content, resumeOffset, content.length)),
                            partial, content.length, hash, resumeOffset + 1, () -> false,
                            (downloaded, total) -> {}),
                    RetroRewindArchiveDownload.Error.STORAGE_FAILURE);
            expect(Files.size(partial) == resumeOffset,
                    "invalid resume offset changed partial bytes");

            expect(RetroRewindArchiveDownload.isCompleteContentRange(
                            "bytes 7-" + (content.length - 1) + "/" + content.length,
                            7, content.length),
                    "valid complete Content-Range rejected");
            expect(!RetroRewindArchiveDownload.isCompleteContentRange(
                            "bytes 6-" + (content.length - 1) + "/" + content.length,
                            7, content.length),
                    "wrong Content-Range start accepted");
            expect(!RetroRewindArchiveDownload.isCompleteContentRange(
                            "bytes 7-8/*", 7, content.length),
                    "incomplete Content-Range accepted");
            expect(!RetroRewindArchiveDownload.isCompleteContentRange(
                            "bytes 7-999999999999999999999999999999/23",
                            7, content.length),
                    "overflowing Content-Range accepted");

            Files.write(partial, Arrays.copyOf(content, resumeOffset));
            FixtureHandler rangeHandler = new FixtureHandler(
                    HttpURLConnection.HTTP_PARTIAL,
                    Arrays.copyOfRange(content, resumeOffset, content.length),
                    "bytes " + resumeOffset + "-" + (content.length - 1) +
                            "/" + content.length,
                    null);
            var rangeResult = RetroRewindArchiveDownload.downloadFrom(
                    fixtureUrl(rangeHandler), partial, resumeOffset, content.length, hash,
                    () -> false, (downloaded, total) -> {});
            expect(rangeResult.isReady(), "valid ranged response failed");
            expect(("bytes=" + resumeOffset + "-").equals(
                            rangeHandler.connection.getRequestProperty("Range")),
                    "resume request did not send the exact Range header");
            expect(Arrays.equals(content, Files.readAllBytes(partial)),
                    "ranged response did not complete the archive");

            Files.write(partial, Arrays.copyOf(content, resumeOffset));
            FixtureHandler restartHandler = new FixtureHandler(
                    HttpURLConnection.HTTP_OK, content, null, null);
            var restartResult = RetroRewindArchiveDownload.downloadFrom(
                    fixtureUrl(restartHandler), partial, resumeOffset, content.length, hash,
                    () -> false, (downloaded, total) -> {});
            expect(restartResult.isReady(), "200 response did not restart partial transfer");
            expect(Arrays.equals(content, Files.readAllBytes(partial)),
                    "200 restart response appended instead of truncating");

            Files.write(partial, Arrays.copyOf(content, resumeOffset));
            FixtureHandler badRangeHandler = new FixtureHandler(
                    HttpURLConnection.HTTP_PARTIAL,
                    Arrays.copyOfRange(content, resumeOffset, content.length),
                    "bytes 0-" + (content.length - 1) + "/" + content.length,
                    null);
            var badRangeResult = RetroRewindArchiveDownload.downloadFrom(
                    fixtureUrl(badRangeHandler), partial, resumeOffset,
                    content.length, hash, () -> false, (downloaded, total) -> {});
            expectError(badRangeResult.error,
                    RetroRewindArchiveDownload.Error.HTTP_FAILURE);
            expect(Files.size(partial) == resumeOffset,
                    "invalid range response changed the partial");

            Files.write(partial, content);
            expect(RetroRewindArchiveDownload.preparePartial(
                            partial, content.length, hash) == content.length,
                    "verified complete partial was not reusable");
            Files.write(partial, new byte[content.length + 1]);
            expect(RetroRewindArchiveDownload.preparePartial(
                            partial, content.length, hash) == 0 && Files.size(partial) == 0,
                    "oversized partial was not reset");
            Files.write(partial, new byte[content.length]);
            expect(RetroRewindArchiveDownload.preparePartial(
                            partial, content.length, hash) == 0 && Files.size(partial) == 0,
                    "complete corrupt partial was not reset");

            expectError(transfer(content, partial, content.length + 1, hash, () -> false),
                    RetroRewindArchiveDownload.Error.SIZE_MISMATCH);
            expectError(transfer(content, partial, content.length - 1, hash, () -> false),
                    RetroRewindArchiveDownload.Error.SIZE_MISMATCH);
            expectError(transfer(content, partial, content.length, "0".repeat(64), () -> false),
                    RetroRewindArchiveDownload.Error.HASH_MISMATCH);

            var cancellation = new RetroRewindArchiveDownload.Cancellation() {
                private int probes;

                @Override
                public boolean isCancelled() {
                    probes++;
                    return probes > 1;
                }
            };
            expectError(RetroRewindArchiveDownload.transfer(
                    new ChunkedInputStream(content), partial,
                    content.length, hash, cancellation),
                    RetroRewindArchiveDownload.Error.CANCELLED);
            expect(Files.size(partial) == 1,
                    "cancelled transfer did not preserve completed bytes");

            expectError(RetroRewindArchiveDownload.transfer(
                    new FailingInputStream(), partial, content.length, hash, () -> false),
                    RetroRewindArchiveDownload.Error.NETWORK_FAILURE);

            Path symlink = directory.resolve("archive-link");
            try {
                Files.createSymbolicLink(symlink, partial.getFileName());
                expectError(RetroRewindArchiveDownload.verifyFile(
                        symlink, content.length, hash),
                        RetroRewindArchiveDownload.Error.STORAGE_FAILURE);
            } catch (UnsupportedOperationException | IOException exception) {
                // Symlink creation is not guaranteed on every host running this harness.
            }

            Path outside = directory.resolve("outside");
            Path partialSymlink = directory.resolve("partial-link");
            Files.write(outside, content);
            try {
                Files.createSymbolicLink(partialSymlink, outside.getFileName());
                expect(RetroRewindArchiveDownload.preparePartial(
                                partialSymlink, content.length, hash) == 0,
                        "partial symlink was not reset");
                expect(Files.isRegularFile(partialSymlink) &&
                                Files.size(partialSymlink) == 0,
                        "partial symlink was not replaced by an empty regular file");
                expect(Arrays.equals(content, Files.readAllBytes(outside)),
                        "partial symlink reset changed its target");
            } catch (UnsupportedOperationException | IOException exception) {
                // Symlink creation is not guaranteed on every host running this harness.
            }
        } finally {
            try (var paths = Files.list(directory)) {
                paths.forEach(path -> {
                    try {
                        Files.deleteIfExists(path);
                    } catch (IOException exception) {
                        throw new IllegalStateException(exception);
                    }
                });
            }
            Files.deleteIfExists(directory);
        }
        System.out.println("Android Retro Rewind archive download passed.");
    }

    private static RetroRewindArchiveDownload.Error transfer(
            byte[] content,
            Path partial,
            long expectedBytes,
            String expectedHash,
            RetroRewindArchiveDownload.Cancellation cancellation) {
        return RetroRewindArchiveDownload.transfer(
                new ByteArrayInputStream(content), partial,
                expectedBytes, expectedHash, cancellation);
    }

    private static String sha256(byte[] content) throws NoSuchAlgorithmException {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(content));
    }

    private static URL fixtureUrl(FixtureHandler handler) throws IOException {
        return new URL(null, "https://fixture.invalid/archive.zip", handler);
    }

    private static void expectError(
            RetroRewindArchiveDownload.Error actual,
            RetroRewindArchiveDownload.Error expected) {
        expect(actual == expected, "expected " + expected + ", got " + actual);
    }

    private static void expect(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    private static final class ChunkedInputStream extends InputStream {
        private final byte[] content;
        private int offset;

        ChunkedInputStream(byte[] content) {
            this.content = content;
        }

        @Override
        public int read() {
            if (offset >= content.length) {
                return -1;
            }
            return content[offset++] & 0xff;
        }

        @Override
        public int read(byte[] output, int outputOffset, int length) {
            if (offset >= content.length) {
                return -1;
            }
            output[outputOffset] = content[offset++];
            return 1;
        }
    }

    private static final class FailingInputStream extends InputStream {
        @Override
        public int read() throws IOException {
            throw new IOException("injected network loss");
        }

        @Override
        public int read(byte[] output, int offset, int length) throws IOException {
            throw new IOException("injected network loss");
        }
    }

    private static final class FailingAfterInputStream extends InputStream {
        private final byte[] content;
        private final int failAfter;
        private int offset;

        FailingAfterInputStream(byte[] content, int failAfter) {
            this.content = content;
            this.failAfter = failAfter;
        }

        @Override
        public int read() throws IOException {
            if (offset >= failAfter) {
                throw new IOException("injected network loss after bytes");
            }
            return content[offset++] & 0xff;
        }

        @Override
        public int read(byte[] output, int outputOffset, int length) throws IOException {
            if (offset >= failAfter) {
                throw new IOException("injected network loss after bytes");
            }
            output[outputOffset] = content[offset++];
            return 1;
        }
    }

    private static final class FixtureHandler extends URLStreamHandler {
        private final int response;
        private final byte[] content;
        private final String contentRange;
        private final String contentEncoding;
        private FixtureConnection connection;

        FixtureHandler(
                int response, byte[] content, String contentRange, String contentEncoding) {
            this.response = response;
            this.content = content;
            this.contentRange = contentRange;
            this.contentEncoding = contentEncoding;
        }

        @Override
        protected URLConnection openConnection(URL url) {
            connection = new FixtureConnection(
                    url, response, content, contentRange, contentEncoding);
            return connection;
        }
    }

    private static final class FixtureConnection extends HttpURLConnection {
        private final byte[] content;
        private final String contentRange;
        private final String contentEncoding;

        FixtureConnection(
                URL url, int response, byte[] content,
                String contentRange, String contentEncoding) {
            super(url);
            this.responseCode = response;
            this.content = content;
            this.contentRange = contentRange;
            this.contentEncoding = contentEncoding;
        }

        @Override
        public int getResponseCode() {
            return responseCode;
        }

        @Override
        public String getHeaderField(String name) {
            return "Content-Range".equalsIgnoreCase(name) ? contentRange : null;
        }

        @Override
        public long getContentLengthLong() {
            return content.length;
        }

        @Override
        public String getContentEncoding() {
            return contentEncoding;
        }

        @Override
        public InputStream getInputStream() {
            return new ByteArrayInputStream(content);
        }

        @Override
        public void disconnect() {}

        @Override
        public boolean usingProxy() {
            return false;
        }

        @Override
        public void connect() {}
    }
}
