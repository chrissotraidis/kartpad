package dev.kartpad.android;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.stream.Stream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public final class RetroRewindMusicTestMain {
    private RetroRewindMusicTestMain() {}

    public static void main(String[] args) throws Exception {
        Path temporary = Files.createTempDirectory("kartpad-music-test-");
        try {
            File files = temporary.toFile();
            expectFailure(() -> RetroRewindMusic.importFile(files, "104_N.brstm", track("a")),
                    "import before Retro Rewind is installed");
            Path pack = Files.createDirectories(RetroRewindInstallStorage.installedRoot(files)
                    .resolve("RetroRewind6"));
            Path music = pack.resolve("MyStuff");

            check(RetroRewindMusic.importFile(files, "104_N.brstm", track("one")).added == 1,
                    "single track was not added");
            check(Files.readString(music.resolve("104_N.brstm")).equals("RSTMone"), "track bytes differ");
            check(RetroRewindMusic.importFile(files, "104_N.brstm", track("two")).added == 1 &&
                    Files.readString(music.resolve("104_N.brstm")).equals("RSTMtwo"),
                    "same name did not replace the track");
            check(RetroRewindMusic.importFile(files, "fake.brstm",
                    new ByteArrayInputStream("not music".getBytes(StandardCharsets.UTF_8))).skipped == 1,
                    "non-RSTM file was accepted");
            check(!Files.exists(music.resolve("fake.brstm")), "rejected track was written");
            expectFailure(() -> RetroRewindMusic.importFile(files, "song.mp3", track("x")),
                    "non-music file type");

            RetroRewindMusic.Result zip = RetroRewindMusic.importFile(files, "Pack.zip", zip(
                    "Pack/Normal/105_N.brstm", "RSTMfive",
                    "Pack/Final/105_F.brstm", "RSTMfinal",
                    "__MACOSX/Pack/._105_N.brstm", "RSTMjunk",
                    "Pack/readme.txt", "hello",
                    "Pack/bad name.brstm", "RSTMspace",
                    "Pack/broken.brstm", "RIFF"));
            check(zip.added == 2 && zip.skipped == 2, "zip result " + zip.added + "/" + zip.skipped);
            check(Files.readString(music.resolve("105_F.brstm")).equals("RSTMfinal"), "zip track differs");
            expectFailure(() -> RetroRewindMusic.importFile(files, "Empty.zip", zip("readme.txt", "x")),
                    "zip without music");
            check(RetroRewindMusic.count(files) == 3, "count " + RetroRewindMusic.count(files));
            try (Stream<Path> leftovers = Files.list(music)) {
                check(leftovers.noneMatch(path -> path.getFileName().toString().startsWith(".import-")),
                        "temporary file left behind");
            }

            try (var lock = RetroRewindInstallStorage.tryInstallLock(files)) {
                check(lock != null, "test lock unavailable");
                expectFailure(() -> RetroRewindMusic.importFile(files, "106_N.brstm", track("b")),
                        "import during an install");
            }

            Path staging = RetroRewindInstallStorage.createStagingDirectory(files, "music");
            Files.createDirectories(staging.resolve("RetroRewind6/MyStuff"));
            Files.writeString(staging.resolve("RetroRewind6/version.txt"), "new");
            RetroRewindInstallStorage.activateValidatedStaging(files, staging, "music");
            check(Files.readString(pack.resolve("version.txt")).equals("new"), "update not activated");
            check(RetroRewindMusic.count(files) == 3 &&
                    Files.readString(music.resolve("104_N.brstm")).equals("RSTMtwo"),
                    "pack update lost player music");

            check(RetroRewindMusic.removeAll(files) == 3 && RetroRewindMusic.count(files) == 0,
                    "remove all left tracks");
            System.out.println("Retro Rewind music: 9 cases passed");
        } finally {
            try (Stream<Path> paths = Files.walk(temporary)) {
                paths.sorted(Comparator.reverseOrder()).forEach(path -> path.toFile().delete());
            }
        }
    }

    private interface Action {
        void run() throws IOException;
    }

    private static ByteArrayInputStream track(String body) {
        return new ByteArrayInputStream(("RSTM" + body).getBytes(StandardCharsets.UTF_8));
    }

    private static ByteArrayInputStream zip(String... namesAndBodies) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ZipOutputStream output = new ZipOutputStream(bytes)) {
            for (int index = 0; index < namesAndBodies.length; index += 2) {
                output.putNextEntry(new ZipEntry(namesAndBodies[index]));
                output.write(namesAndBodies[index + 1].getBytes(StandardCharsets.UTF_8));
                output.closeEntry();
            }
        }
        return new ByteArrayInputStream(bytes.toByteArray());
    }

    private static void expectFailure(Action action, String label) {
        try {
            action.run();
        } catch (IOException expected) {
            return;
        }
        throw new AssertionError("expected failure: " + label);
    }

    private static void check(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
