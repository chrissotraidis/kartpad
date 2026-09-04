package dev.kartpad.android;

import android.content.Context;
import android.util.Log;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Collections;
import java.util.concurrent.atomic.AtomicLong;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/** Drives the real extraction pipeline against a bounded ENOSPC filesystem. */
final class RetroRewindEnospcDeviceFixture {
    private static final String TAG = "KartPadFixture";
    private static final String ARCHIVE_NAME = "RetroRewindEnospcFixture.zip";
    private static final String CURRENT_PATH = "fixture/current.bin";
    private static final byte[] CURRENT_CONTENT =
            "preserve-this-install".getBytes(StandardCharsets.UTF_8);

    private RetroRewindEnospcDeviceFixture() {}

    static void prepare(Context context) {
        try {
            System.loadLibrary("main");
            Path archive = context.getCacheDir().toPath().resolve("current-fixture.zip");
            try (ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(archive))) {
                addDirectory(zip, RetroRewindRelease.ROOT + "/");
                addFile(zip, RetroRewindRelease.ROOT + "/version.txt",
                        (RetroRewindRelease.VERSION + "\n").getBytes(StandardCharsets.UTF_8));
                addDirectory(zip, RetroRewindRelease.ROOT + "/fixture/");
                addFile(zip, RetroRewindRelease.ROOT + "/" + CURRENT_PATH, CURRENT_CONTENT);
            }
            RetroRewindInstallValidator.Contract contract = currentContract();
            RetroRewindInstallPipeline.Result result = install(
                    context, archive, "enospc-current", contract, new AtomicLong());
            require(result.isInstalled(), "existing install setup failed: " + result.error);
            require(validateInstalled(context, contract).isValid(),
                    "existing install setup did not validate");
            Files.deleteIfExists(archive);
            Log.i(TAG, "A3 ENOSPC fixture prepared existing=valid");
        } catch (Exception error) {
            Log.e(TAG, "A3 ENOSPC fixture preparation failed", error);
        }
    }

    static void run(
            Context context,
            long archiveBytes,
            String archiveSha256,
            long payloadBytes,
            String payloadSha256) {
        try {
            System.loadLibrary("main");
            require(archiveBytes > 0 && payloadBytes > 0,
                    "ENOSPC fixture sizes are invalid");
            require(isLowercaseSha256(archiveSha256) && isLowercaseSha256(payloadSha256),
                    "ENOSPC fixture digest is invalid");
            RetroRewindInstallValidator.Contract current = currentContract();
            require(validateInstalled(context, current).isValid(),
                    "existing install was not valid before ENOSPC extraction");

            Path archive = context.getCacheDir().toPath().resolve(ARCHIVE_NAME);
            require(Files.size(archive) == archiveBytes, "ENOSPC archive size changed");
            RetroRewindInstallValidator.Contract replacement =
                    new RetroRewindInstallValidator.Contract(
                            RetroRewindRelease.VERSION,
                            RetroRewindRelease.ROOT,
                            Collections.singletonList(
                                    new RetroRewindInstallValidator.ArtifactRequirement(
                                            "fixture/large.bin", payloadBytes, payloadSha256)));
            AtomicLong extractedBytes = new AtomicLong();
            RetroRewindInstallPipeline.Result result = RetroRewindInstallPipeline.install(
                    context.getFilesDir(),
                    archive,
                    "enospc-replacement",
                    () -> false,
                    (completed, total) -> extractedBytes.set(completed),
                    path -> RetroRewindArchiveDownload.verifyFile(
                            path, archiveBytes, archiveSha256),
                    RetroRewindArchiveExtractor::extract,
                    replacement);
            require(result.error == RetroRewindInstallPipeline.Error.EXTRACTION_FAILURE,
                    "ENOSPC did not fail extraction: " + result.error);
            require(result.extractionError == RetroRewindArchiveExtractor.Error.IO_FAILURE,
                    "ENOSPC did not report native IO failure: " + result.extractionError);
            require(extractedBytes.get() > 0 && extractedBytes.get() < payloadBytes,
                    "ENOSPC did not interrupt an active extraction");
            require(validateInstalled(context, current).isValid(),
                    "ENOSPC changed the existing valid install");
            require(!Files.exists(RetroRewindInstallStorage.supportRoot(context.getFilesDir())
                            .resolve("RetroRewind.import-enospc-replacement")),
                    "ENOSPC left staging behind");
            Log.i(TAG, "A3 ENOSPC extraction passed existing=preserved " +
                    "error=IO_FAILURE extracted=" + extractedBytes.get() +
                    " selected=" + payloadBytes);
        } catch (Exception error) {
            Log.e(TAG, "A3 ENOSPC extraction failed", error);
        }
    }

    static String archiveName() {
        return ARCHIVE_NAME;
    }

    private static RetroRewindInstallPipeline.Result install(
            Context context,
            Path archive,
            String token,
            RetroRewindInstallValidator.Contract contract,
            AtomicLong extractedBytes) throws IOException {
        long archiveBytes = Files.size(archive);
        String archiveSha256 = sha256(archive);
        return RetroRewindInstallPipeline.install(
                context.getFilesDir(),
                archive,
                token,
                () -> false,
                (completed, total) -> extractedBytes.set(completed),
                path -> RetroRewindArchiveDownload.verifyFile(
                        path, archiveBytes, archiveSha256),
                RetroRewindArchiveExtractor::extract,
                contract);
    }

    private static RetroRewindInstallValidator.Contract currentContract() {
        return new RetroRewindInstallValidator.Contract(
                RetroRewindRelease.VERSION,
                RetroRewindRelease.ROOT,
                Collections.singletonList(
                        new RetroRewindInstallValidator.ArtifactRequirement(
                                CURRENT_PATH,
                                CURRENT_CONTENT.length,
                                sha256(CURRENT_CONTENT))));
    }

    private static RetroRewindInstallValidator.Result validateInstalled(
            Context context, RetroRewindInstallValidator.Contract contract) {
        return RetroRewindInstallValidator.validate(
                RetroRewindInstallStorage.installedRoot(context.getFilesDir())
                        .resolve(RetroRewindRelease.ROOT),
                contract);
    }

    private static void addDirectory(ZipOutputStream zip, String name) throws IOException {
        zip.putNextEntry(new ZipEntry(name));
        zip.closeEntry();
    }

    private static void addFile(ZipOutputStream zip, String name, byte[] content)
            throws IOException {
        zip.putNextEntry(new ZipEntry(name));
        zip.write(content);
        zip.closeEntry();
    }

    private static String sha256(Path path) throws IOException {
        MessageDigest digest = sha256Digest();
        try (var input = Files.newInputStream(path)) {
            byte[] buffer = new byte[16 * 1024];
            int count;
            while ((count = input.read(buffer)) != -1) {
                digest.update(buffer, 0, count);
            }
        }
        return hex(digest.digest());
    }

    private static String sha256(byte[] bytes) {
        return hex(sha256Digest().digest(bytes));
    }

    private static MessageDigest sha256Digest() {
        try {
            return MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException error) {
            throw new AssertionError("Android runtime has no SHA-256", error);
        }
    }

    private static boolean isLowercaseSha256(String value) {
        return value != null && value.matches("[0-9a-f]{64}");
    }

    private static String hex(byte[] bytes) {
        char[] digits = "0123456789abcdef".toCharArray();
        char[] output = new char[bytes.length * 2];
        for (int index = 0; index < bytes.length; index++) {
            int value = bytes[index] & 0xff;
            output[index * 2] = digits[value >>> 4];
            output[index * 2 + 1] = digits[value & 0x0f];
        }
        return new String(output);
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalStateException(message);
        }
    }
}
