package dev.kartpad.android;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.List;

public final class RetroRewindInstallPipelineTestMain {
    private RetroRewindInstallPipelineTestMain() {}

    public static void main(String[] args) throws Exception {
        Path temporary = Files.createTempDirectory("kartpad-install-pipeline-");
        try {
            Path files = Files.createDirectory(temporary.resolve("files"));
            Path archive = Files.write(temporary.resolve("archive.zip"), new byte[] {1});
            byte[] artifact = "verified".getBytes(StandardCharsets.UTF_8);
            var contract = new RetroRewindInstallValidator.Contract(
                    RetroRewindRelease.VERSION,
                    RetroRewindRelease.ROOT,
                    List.of(new RetroRewindInstallValidator.ArtifactRequirement(
                            "Binaries/Code.pul", artifact.length, sha256(artifact))));

            var success = RetroRewindInstallPipeline.install(
                    files.toFile(), archive, "success", () -> false, (done, total) -> {},
                    path -> RetroRewindArchiveDownload.Error.NONE,
                    (path, staging, cancellation, progress) -> {
                        writeTree(staging, artifact);
                        progress.onProgress(artifact.length, artifact.length);
                        return extraction(RetroRewindArchiveExtractor.Error.NONE,
                                artifact.length);
                    },
                    contract);
            expect(success.isInstalled(), "valid extracted tree was not installed");
            Path installed = files.resolve("KartPad/RetroRewind/RetroRewind6");
            expect(Files.readString(installed.resolve("Binaries/Code.pul"))
                            .equals("verified"),
                    "activated content changed");

            var extractionFailure = RetroRewindInstallPipeline.install(
                    files.toFile(), archive, "cancel", () -> true, (done, total) -> {},
                    path -> RetroRewindArchiveDownload.Error.NONE,
                    (path, staging, cancellation, progress) ->
                            extraction(RetroRewindArchiveExtractor.Error.CANCELLED, 0),
                    contract);
            expect(extractionFailure.error ==
                            RetroRewindInstallPipeline.Error.EXTRACTION_FAILURE &&
                            extractionFailure.extractionError ==
                                    RetroRewindArchiveExtractor.Error.CANCELLED,
                    "cancellation was not preserved");
            expect(!Files.exists(files.resolve("KartPad/RetroRewind.import-cancel")),
                    "cancelled staging was not discarded");
            expect(Files.exists(installed), "cancellation removed active content");

            var invalidContent = RetroRewindInstallPipeline.install(
                    files.toFile(), archive, "invalid", () -> false, (done, total) -> {},
                    path -> RetroRewindArchiveDownload.Error.NONE,
                    (path, staging, cancellation, progress) -> {
                        writeTree(staging, "wrong".getBytes(StandardCharsets.UTF_8));
                        return extraction(RetroRewindArchiveExtractor.Error.NONE, 5);
                    },
                    contract);
            expect(invalidContent.error == RetroRewindInstallPipeline.Error.CONTENT_INVALID,
                    "invalid extracted content was not rejected");
            expect(!Files.exists(files.resolve("KartPad/RetroRewind.import-invalid")),
                    "invalid staging was not discarded");
            expect(Files.readString(installed.resolve("Binaries/Code.pul"))
                            .equals("verified"),
                    "invalid content replaced active installation");

            final boolean[] extracted = {false};
            var invalidArchive = RetroRewindInstallPipeline.install(
                    files.toFile(), archive, "bad-archive", () -> false,
                    (done, total) -> {},
                    path -> RetroRewindArchiveDownload.Error.HASH_MISMATCH,
                    (path, staging, cancellation, progress) -> {
                        extracted[0] = true;
                        return extraction(RetroRewindArchiveExtractor.Error.NONE, 0);
                    },
                    contract);
            expect(invalidArchive.error == RetroRewindInstallPipeline.Error.ARCHIVE_INVALID,
                    "invalid archive was accepted");
            expect(!extracted[0], "invalid archive reached extraction");
        } finally {
            deleteTree(temporary);
        }
        System.out.println("Android Retro Rewind install pipeline passed.");
    }

    private static void writeTree(Path staging, byte[] artifact) throws IOException {
        Path root = staging.resolve(RetroRewindRelease.ROOT);
        Files.createDirectories(root.resolve("Binaries"));
        Files.writeString(root.resolve("version.txt"), RetroRewindRelease.VERSION + "\n");
        Files.write(root.resolve("Binaries/Code.pul"), artifact);
    }

    private static RetroRewindArchiveExtractor.Result extraction(
            RetroRewindArchiveExtractor.Error error, long bytes) {
        return new RetroRewindArchiveExtractor.Result(error, new long[] {2, bytes, bytes});
    }

    private static String sha256(byte[] bytes) throws NoSuchAlgorithmException {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
        char[] digits = "0123456789abcdef".toCharArray();
        char[] output = new char[digest.length * 2];
        for (int index = 0; index < digest.length; index++) {
            int value = digest[index] & 0xff;
            output[index * 2] = digits[value >>> 4];
            output[index * 2 + 1] = digits[value & 0x0f];
        }
        return new String(output);
    }

    private static void deleteTree(Path root) throws IOException {
        try (var paths = Files.walk(root)) {
            for (Path path : paths.sorted(java.util.Comparator.reverseOrder()).toList()) {
                Files.deleteIfExists(path);
            }
        }
    }

    private static void expect(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
