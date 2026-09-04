package dev.kartpad.android;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
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

            expectError(transfer(content, partial, content.length, hash, () -> false),
                    RetroRewindArchiveDownload.Error.NONE);
            expect(java.util.Arrays.equals(content, Files.readAllBytes(partial)),
                    "successful transfer bytes changed");
            expectError(RetroRewindArchiveDownload.verifyFile(
                    partial, content.length, hash), RetroRewindArchiveDownload.Error.NONE);

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
}
