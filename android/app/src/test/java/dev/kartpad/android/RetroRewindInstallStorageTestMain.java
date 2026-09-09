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
            testSavePreservingReplacement(temporary.resolve("saves"));
            for (String boundary : new String[]{"source-parent", "source-file", "target-parent", "target-file", "target-conflict"}) {
                testSaveCopyFailure(temporary.resolve(boundary), boundary);
            }
            testActivationRollback(temporary.resolve("rollback"));
            testScopeChecks(temporary.resolve("scope"));
            testSymlinkBoundary(temporary.resolve("symlink"));
            testRollbackSymlinkBoundary(temporary.resolve("rollback-symlink"));
            System.out.println("Retro install storage: 13 cases passed");
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

    private static void testSavePreservingReplacement(Path root) throws Exception {
        File files = Files.createDirectories(root).toFile();
        Path support = RetroRewindInstallStorage.supportRoot(files);
        Path installed = Files.createDirectories(support.resolve("RetroRewind"));
        String[] saves = {"riivolution/save/RetroWFC/RMCP/rksys.dat",
                "riivolution/save/RetroWFC2/RMCP/rksys.dat",
                "riivolution/save/RetroWFC/RMCP/other-progress.dat"};
        for (String save : saves) {
            Files.createDirectories(installed.resolve(save).getParent());
            write(installed.resolve(save), "player:" + save);
        }
        Path pulsar = support.resolve("NAND/shared2/Pulsar/RetroRewind6/Ghosts/track/ldb.pul");
        Files.createDirectories(pulsar.getParent());
        write(pulsar, "custom record");
        Path staging = RetroRewindInstallStorage.createStagingDirectory(files, "preserve");
        write(staging.resolve("new-pack"), "new pack");
        Files.createDirectories(staging.resolve(saves[0]).getParent());
        write(staging.resolve(saves[0]), "pack default must not replace player save");

        RetroRewindInstallStorage.activateValidatedStaging(files, staging, "preserve");
        RetroRewindInstallStorage.recover(files);

        for (String save : saves) {
            expect(Files.exists(installed.resolve(save)), "replacement lost save: " + save);
            expect(Files.readString(installed.resolve(save)).equals("player:" + save),
                    "replacement overwrote save: " + save);
        }
        expect(Files.readString(installed.resolve("new-pack")).equals("new pack"),
                "updated pack was not activated");
        expect(Files.readString(pulsar).equals("custom record"), "Pulsar data changed");
    }

    private static void testSaveCopyFailure(Path root, String boundary) throws Exception {
        File files = Files.createDirectories(root.resolve("files")).toFile();
        Path installed = Files.createDirectories(RetroRewindInstallStorage.installedRoot(files));
        write(installed.resolve("old"), "old pack");
        Path outside = Files.createDirectories(root.resolve("outside"));
        write(outside.resolve("sentinel"), "unchanged");
        Path save = installed.resolve("riivolution/save/RetroWFC/RMCP/rksys.dat");
        Path staging = RetroRewindInstallStorage.createStagingDirectory(files, "boundary");
        Path target = staging.resolve("riivolution/save/RetroWFC/RMCP/rksys.dat");
        if (boundary.equals("source-parent")) {
            Files.createSymbolicLink(installed.resolve("riivolution"), outside);
        } else {
            Files.createDirectories(save.getParent());
            if (boundary.equals("source-file")) {
                Files.createSymbolicLink(save, outside.resolve("sentinel"));
            } else {
                write(save, "player progress");
                if (boundary.equals("target-parent")) {
                    Files.createSymbolicLink(staging.resolve("riivolution"), outside);
                } else {
                    Files.createDirectories(target.getParent());
                    if (boundary.equals("target-file")) {
                        Files.createSymbolicLink(target, outside.resolve("sentinel"));
                    } else {
                        Files.createDirectory(target);
                    }
                }
            }
        }
        AtomicInteger moves = new AtomicInteger();
        try {
            RetroRewindInstallStorage.activateValidatedStaging(files, staging, "boundary",
                    (source, destination) -> {
                        moves.incrementAndGet();
                        Files.move(source, destination);
                    });
            throw new AssertionError("unsafe save copy was accepted: " + boundary);
        } catch (IOException expected) {
            expect(moves.get() == 0, "save-copy failure moved active data");
        }
        expect(Files.readString(installed.resolve("old")).equals("old pack"),
                "save-copy failure replaced active pack");
        expect(Files.readString(outside.resolve("sentinel")).equals("unchanged"),
                "save-copy failure changed link target");
        if (boundary.startsWith("target-")) {
            expect(Files.readString(save).equals("player progress"),
                    "save-copy failure changed original progress");
        }
    }

    private static void testActivationRollback(Path root) throws Exception {
        File files = Files.createDirectories(root).toFile();
        Path support = RetroRewindInstallStorage.supportRoot(files);
        Path installed = Files.createDirectories(support.resolve("RetroRewind"));
        write(installed.resolve("old"), "old");
        Path save = installed.resolve("riivolution/save/RetroWFC/RMCP/rksys.dat");
        Files.createDirectories(save.getParent());
        write(save, "retained progress");
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
        expect(Files.readString(save).equals("retained progress"),
                "activation rollback lost saved progress");
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
