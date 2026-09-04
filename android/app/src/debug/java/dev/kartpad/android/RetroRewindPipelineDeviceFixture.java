package dev.kartpad.android;

import android.content.Context;
import android.util.Log;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.Comparator;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/** Runs the real Android install pipeline against bounded synthetic content. */
final class RetroRewindPipelineDeviceFixture {
    private static final String TAG = "KartPadFixture";
    private static final String VERSION = RetroRewindRelease.VERSION;
    private static final String CODE_PATH = "fixture/code.bin";
    private static final String XML_PATH = "fixture/config.xml";

    private RetroRewindPipelineDeviceFixture() {}

    static void run(Context context) {
        Path fixtureRoot = context.getCacheDir().toPath()
                .resolve("RetroRewindPipelineDeviceFixture");
        try {
            // Deliberately do not preload JNI here. This fixture starts in a
            // non-SDL process and proves the extractor owns its cold load.
            deleteTree(fixtureRoot);
            Files.createDirectories(fixtureRoot);
            RetroRewindInstallStorage.recover(context.getFilesDir());

            byte[] firstCode = "first-device-code".getBytes(StandardCharsets.UTF_8);
            byte[] firstXml = "<first-device/>".getBytes(StandardCharsets.UTF_8);
            Path firstArchive = createArchive(fixtureRoot.resolve("first.zip"), firstCode, firstXml);
            RetroRewindInstallValidator.Contract firstContract = contract(firstCode, firstXml);
            RetroRewindInstallPipeline.Result first = install(
                    context, firstArchive, "device-first", firstContract);
            require(first.isInstalled(), "initial synthetic install failed: " + first.error);
            require(validateInstalled(context, firstContract).isValid(),
                    "initial installed content did not validate");

            Path rejectedArchive = fixtureRoot.resolve("rejected.zip");
            Files.copy(firstArchive, rejectedArchive);
            long firstArchiveBytes = Files.size(firstArchive);
            String firstArchiveSha256 = sha256(firstArchive);
            try (OutputStream output = Files.newOutputStream(
                    rejectedArchive, java.nio.file.StandardOpenOption.APPEND)) {
                output.write(0);
            }
            RetroRewindInstallPipeline.Result rejected = RetroRewindInstallPipeline.install(
                    context.getFilesDir(),
                    rejectedArchive,
                    "device-rejected",
                    () -> false,
                    (completed, total) -> {},
                    path -> RetroRewindArchiveDownload.verifyFile(
                            path, firstArchiveBytes, firstArchiveSha256),
                    RetroRewindArchiveExtractor::extract,
                    firstContract);
            require(rejected.error == RetroRewindInstallPipeline.Error.ARCHIVE_INVALID,
                    "corrupt archive reached extraction: " + rejected.error);
            require(validateInstalled(context, firstContract).isValid(),
                    "rejected archive changed the active install");

            byte[] secondCode = "second-device-code".getBytes(StandardCharsets.UTF_8);
            byte[] secondXml = "<second-device/>".getBytes(StandardCharsets.UTF_8);
            Path secondArchive = createArchive(
                    fixtureRoot.resolve("second.zip"), secondCode, secondXml);
            RetroRewindInstallValidator.Contract secondContract = contract(secondCode, secondXml);

            String blockedToken = "device-blocked";
            Path rollback = RetroRewindInstallStorage.supportRoot(context.getFilesDir())
                    .resolve("RetroRewind.rollback-" + blockedToken);
            Files.createDirectory(rollback);
            RetroRewindInstallPipeline.Result blocked = install(
                    context, secondArchive, blockedToken, secondContract);
            require(blocked.error == RetroRewindInstallPipeline.Error.ACTIVATION_FAILURE,
                    "injected activation failure was not surfaced: " + blocked.error);
            require(validateInstalled(context, firstContract).isValid(),
                    "activation failure did not retain the previous install");
            require(!Files.exists(RetroRewindInstallStorage.supportRoot(context.getFilesDir())
                            .resolve("RetroRewind.import-" + blockedToken)),
                    "failed activation left staging behind");
            Files.delete(rollback);

            RetroRewindInstallPipeline.Result replacement = install(
                    context, secondArchive, "device-replacement", secondContract);
            require(replacement.isInstalled(),
                    "replacement synthetic install failed: " + replacement.error);
            require(validateInstalled(context, secondContract).isValid(),
                    "replacement installed content did not validate");

            String recoveryToken = "device-recovery";
            Path support = RetroRewindInstallStorage.supportRoot(context.getFilesDir());
            Path installed = RetroRewindInstallStorage.installedRoot(context.getFilesDir());
            Path recoveryRollback = support.resolve("RetroRewind.rollback-" + recoveryToken);
            Files.move(installed, recoveryRollback, StandardCopyOption.ATOMIC_MOVE);
            Path staleStaging = RetroRewindInstallStorage.createStagingDirectory(
                    context.getFilesDir(), recoveryToken);
            Files.write(staleStaging.resolve("interrupted.tmp"),
                    "interrupted".getBytes(StandardCharsets.UTF_8));
            RetroRewindInstallStorage.recover(context.getFilesDir());
            require(validateInstalled(context, secondContract).isValid(),
                    "startup recovery did not restore the rollback install");
            require(noTransientInstallDirectories(context),
                    "startup recovery left staging or rollback state");

            Log.i(TAG, "A3 device install faults passed existing=preserved " +
                    "replacement=valid recovery=restored");
        } catch (Exception error) {
            Log.e(TAG, "A3 device install faults failed", error);
        } finally {
            try {
                deleteTree(fixtureRoot);
            } catch (IOException error) {
                Log.e(TAG, "A3 device install fixture cleanup failed", error);
            }
        }
    }

    private static RetroRewindInstallPipeline.Result install(
            Context context,
            Path archive,
            String token,
            RetroRewindInstallValidator.Contract contract) throws IOException {
        long archiveBytes = Files.size(archive);
        String archiveSha256 = sha256(archive);
        return RetroRewindInstallPipeline.install(
                context.getFilesDir(),
                archive,
                token,
                () -> false,
                (completed, total) -> {},
                path -> RetroRewindArchiveDownload.verifyFile(
                        path, archiveBytes, archiveSha256),
                RetroRewindArchiveExtractor::extract,
                contract);
    }

    private static RetroRewindInstallValidator.Result validateInstalled(
            Context context, RetroRewindInstallValidator.Contract contract) {
        return RetroRewindInstallValidator.validate(
                RetroRewindInstallStorage.installedRoot(context.getFilesDir())
                        .resolve(RetroRewindRelease.ROOT),
                contract);
    }

    private static RetroRewindInstallValidator.Contract contract(byte[] code, byte[] xml) {
        return new RetroRewindInstallValidator.Contract(
                VERSION,
                RetroRewindRelease.ROOT,
                Arrays.asList(
                        new RetroRewindInstallValidator.ArtifactRequirement(
                                CODE_PATH, code.length, sha256(code)),
                        new RetroRewindInstallValidator.ArtifactRequirement(
                                XML_PATH, xml.length, sha256(xml))));
    }

    private static Path createArchive(Path path, byte[] code, byte[] xml) throws IOException {
        try (ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(path))) {
            addDirectory(zip, RetroRewindRelease.ROOT + "/");
            addFile(zip, RetroRewindRelease.ROOT + "/version.txt",
                    (VERSION + "\n").getBytes(StandardCharsets.UTF_8));
            addDirectory(zip, RetroRewindRelease.ROOT + "/fixture/");
            addFile(zip, RetroRewindRelease.ROOT + "/" + CODE_PATH, code);
            addFile(zip, RetroRewindRelease.ROOT + "/" + XML_PATH, xml);
        }
        return path;
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

    private static boolean noTransientInstallDirectories(Context context) throws IOException {
        Path support = RetroRewindInstallStorage.supportRoot(context.getFilesDir());
        try (var entries = Files.list(support)) {
            return entries.map(path -> path.getFileName().toString())
                    .noneMatch(name -> name.startsWith("RetroRewind.import-") ||
                            name.startsWith("RetroRewind.rollback-"));
        }
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
        MessageDigest digest = sha256Digest();
        return hex(digest.digest(bytes));
    }

    private static MessageDigest sha256Digest() {
        try {
            return MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException error) {
            throw new AssertionError("Android runtime has no SHA-256", error);
        }
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

    private static void deleteTree(Path root) throws IOException {
        if (!Files.exists(root)) {
            return;
        }
        try (var paths = Files.walk(root)) {
            for (Path path : paths.sorted(Comparator.reverseOrder()).toList()) {
                Files.delete(path);
            }
        }
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new IllegalStateException(message);
        }
    }
}
