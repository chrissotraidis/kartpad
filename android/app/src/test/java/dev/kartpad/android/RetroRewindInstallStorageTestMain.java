package dev.kartpad.android;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Stream;

public final class RetroRewindInstallStorageTestMain {
    private RetroRewindInstallStorageTestMain() {}

    public static void main(String[] args) throws Exception {
        Path temporary = Files.createTempDirectory("kartpad-storage-test-");
        try {
            testRecovery(temporary.resolve("recovery"));
            testAmbiguousRecovery(temporary.resolve("ambiguous"));
            testActivation(temporary.resolve("activation"));
            testActivationRollback(temporary.resolve("rollback"));
            testScopeChecks(temporary.resolve("scope"));
            testSymlinkBoundary(temporary.resolve("symlink"));
            testRollbackSymlinkBoundary(temporary.resolve("rollback-symlink"));
        } finally {
            deleteTree(temporary);
        }
    }

    private static void testRecovery(Path root) throws Exception {
        File files = Files.createDirectories(root).toFile();
        Path support = RetroRewindInstallStorage.supportRoot(files);
        Path stale = Files.createDirectories(support.resolve("RetroRewind.import-stale"));
        write(stale.resolve("partial"), "partial");
        Path rollback = Files.createDirectories(support.resolve("RetroRewind.rollback-one"));
        write(rollback.resolve("old"), "old");

        RetroRewindInstallStorage.recover(files);

        expect(!Files.exists(stale), "stale import was not removed");
        expect(Files.readString(support.resolve("RetroRewind/old")).equals("old"),
                "single rollback was not restored");
        expect(!Files.exists(rollback), "restored rollback remains present");
    }

    private static void testAmbiguousRecovery(Path root) throws Exception {
        File files = Files.createDirectories(root).toFile();
        Path support = RetroRewindInstallStorage.supportRoot(files);
        Files.createDirectories(support.resolve("RetroRewind.rollback-a"));
        Files.createDirectories(support.resolve("RetroRewind.rollback-b"));

        RetroRewindInstallStorage.recover(files);

        expect(!Files.exists(support.resolve("RetroRewind")),
                "ambiguous rollback was restored");
    }

    private static void testActivation(Path root) throws Exception {
        File files = Files.createDirectories(root).toFile();
        Path support = RetroRewindInstallStorage.supportRoot(files);
        Path installed = Files.createDirectories(support.resolve("RetroRewind"));
        write(installed.resolve("old"), "old");
        Path staging = RetroRewindInstallStorage.createStagingDirectory(files, "success");
        write(staging.resolve("new"), "new");

        RetroRewindInstallStorage.activateValidatedStaging(files, staging, "success");

        expect(Files.readString(support.resolve("RetroRewind/new")).equals("new"),
                "validated staging was not activated");
        expect(!Files.exists(support.resolve("RetroRewind/old")),
                "old install remains active");
        expect(!Files.exists(support.resolve("RetroRewind.rollback-success")),
                "successful rollback was not removed");
    }

    private static void testActivationRollback(Path root) throws Exception {
        File files = Files.createDirectories(root).toFile();
        Path support = RetroRewindInstallStorage.supportRoot(files);
        Path installed = Files.createDirectories(support.resolve("RetroRewind"));
        write(installed.resolve("old"), "old");
        Path staging = RetroRewindInstallStorage.createStagingDirectory(files, "failure");
        write(staging.resolve("new"), "new");
        AtomicInteger calls = new AtomicInteger();

        try {
            RetroRewindInstallStorage.activateValidatedStaging(
                    files, staging, "failure", (source, destination) -> {
                        if (calls.incrementAndGet() == 2) {
                            throw new IOException("injected activation failure");
                        }
                        Files.move(source, destination);
                    });
            throw new AssertionError("injected activation failure was accepted");
        } catch (IOException expected) {
            expect(expected.getMessage().equals("injected activation failure"),
                    "unexpected activation error");
        }

        expect(Files.readString(support.resolve("RetroRewind/old")).equals("old"),
                "old install was not restored after activation failure");
        expect(Files.exists(staging.resolve("new")),
                "failed staging directory was unexpectedly removed");
        expect(!Files.exists(support.resolve("RetroRewind.rollback-failure")),
                "restored rollback remains present");
    }

    private static void testScopeChecks(Path root) throws Exception {
        File files = Files.createDirectories(root).toFile();
        Files.createDirectories(RetroRewindInstallStorage.supportRoot(files));
        Path outside = Files.createDirectories(root.resolve("outside"));
        try {
            RetroRewindInstallStorage.activateValidatedStaging(files, outside, "safe");
            throw new AssertionError("out-of-scope staging was accepted");
        } catch (IOException expected) {
            expect(expected.getMessage().contains("staging"),
                    "unexpected out-of-scope error");
        }
        try {
            RetroRewindInstallStorage.createStagingDirectory(files, "../escape");
            throw new AssertionError("unsafe token was accepted");
        } catch (IllegalArgumentException expected) {
            expect(expected.getMessage().contains("token"), "unexpected token error");
        }
    }

    private static void testSymlinkBoundary(Path root) throws Exception {
        File files = Files.createDirectories(root.resolve("files")).toFile();
        Path outside = Files.createDirectories(root.resolve("outside"));
        write(outside.resolve("sentinel"), "outside");
        Files.createSymbolicLink(RetroRewindInstallStorage.supportRoot(files), outside);

        try {
            RetroRewindInstallStorage.recover(files);
            throw new AssertionError("symlinked support root was accepted");
        } catch (IOException expected) {
            expect(expected.getMessage().contains("support root"),
                    "unexpected support-root error");
        }
        expect(Files.readString(outside.resolve("sentinel")).equals("outside"),
                "support-root symlink target was modified");
    }

    private static void testRollbackSymlinkBoundary(Path root) throws Exception {
        File files = Files.createDirectories(root.resolve("files")).toFile();
        Path support = Files.createDirectories(
                RetroRewindInstallStorage.supportRoot(files));
        Path outside = Files.createDirectories(root.resolve("outside"));
        write(outside.resolve("sentinel"), "outside");
        Files.createSymbolicLink(support.resolve("RetroRewind.rollback-link"), outside);

        try {
            RetroRewindInstallStorage.recover(files);
            throw new AssertionError("symlinked rollback was accepted");
        } catch (IOException expected) {
            expect(expected.getMessage().contains("rollback entry"),
                    "unexpected rollback-entry error");
        }
        expect(Files.readString(outside.resolve("sentinel")).equals("outside"),
                "rollback symlink target was modified");
        expect(!Files.exists(support.resolve("RetroRewind")),
                "rollback symlink was activated");
    }

    private static void write(Path path, String value) throws IOException {
        Files.write(path, value.getBytes(StandardCharsets.UTF_8));
    }

    private static void expect(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    private static void deleteTree(Path root) throws IOException {
        if (!Files.exists(root)) {
            return;
        }
        try (Stream<Path> paths = Files.walk(root)) {
            paths.sorted((left, right) -> right.compareTo(left)).forEach(path -> {
                try {
                    Files.delete(path);
                } catch (IOException error) {
                    throw new RuntimeException(error);
                }
            });
        }
    }
}
