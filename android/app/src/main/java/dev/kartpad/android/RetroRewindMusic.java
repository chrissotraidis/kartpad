package dev.kartpad.android;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.UUID;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Player-added Retro Rewind music (#441). Retro Rewind's "My Stuff → RR Music" option, which
 * KartPad always selects, lays RetroRewind6/MyStuff over the game's music folder, so a .brstm
 * named like the pack's own (for example 104_N.brstm) replaces that track after a restart.
 * Pack updates keep the folder (RetroRewindInstallStorage).
 */
final class RetroRewindMusic {
    static final long MAX_TRACK_BYTES = 64L << 20;
    private static final Pattern TRACK_NAME =
            Pattern.compile("[A-Za-z0-9][A-Za-z0-9_.-]{0,79}\\.brstm", Pattern.CASE_INSENSITIVE);
    private static final byte[] MAGIC = {'R', 'S', 'T', 'M'};

    /** Tracks added and files that were not usable music. */
    static final class Result {
        final int added;
        final int skipped;

        Result(int added, int skipped) {
            this.added = added;
            this.skipped = skipped;
        }
    }

    private RetroRewindMusic() {}

    static Path directory(File filesDirectory) {
        return RetroRewindInstallStorage.installedRoot(filesDirectory).resolve("RetroRewind6/MyStuff");
    }

    static int count(File filesDirectory) throws IOException {
        Path directory = directory(filesDirectory);
        if (!Files.isDirectory(directory, LinkOption.NOFOLLOW_LINKS)) return 0;
        int count = 0;
        try (DirectoryStream<Path> entries = Files.newDirectoryStream(directory)) {
            for (Path entry : entries) {
                if (isTrack(entry)) count += 1;
            }
        }
        return count;
    }

    /** Adds one .brstm, or every .brstm inside a .zip, replacing tracks with the same name. */
    static Result importFile(File filesDirectory, String displayName, InputStream input)
            throws IOException {
        String lower = displayName == null ? "" : displayName.toLowerCase(Locale.ROOT);
        boolean zip = lower.endsWith(".zip");
        if (!zip && !lower.endsWith(".brstm")) {
            throw new IOException("Choose .brstm music files or a .zip of them.");
        }
        try (RetroRewindInstallStorage.InstallLock lock =
                     RetroRewindInstallStorage.tryInstallLock(filesDirectory)) {
            if (lock == null) {
                throw new IOException("Retro Rewind is being installed. Try again when it finishes.");
            }
            Path directory = prepareDirectory(filesDirectory);
            if (!zip) {
                return writeTrack(directory, baseName(displayName), input)
                        ? new Result(1, 0) : new Result(0, 1);
            }
            int added = 0;
            int skipped = 0;
            ZipInputStream archive = new ZipInputStream(input);
            for (ZipEntry entry; (entry = archive.getNextEntry()) != null; ) {
                if (entry.isDirectory() || entry.getName().contains("__MACOSX")) continue;
                String name = baseName(entry.getName());
                if (!name.toLowerCase(Locale.ROOT).endsWith(".brstm")) continue;
                if (writeTrack(directory, name, archive)) added += 1; else skipped += 1;
            }
            if (added == 0 && skipped == 0) {
                throw new IOException("That ZIP has no .brstm music files.");
            }
            return new Result(added, skipped);
        }
    }

    static int removeAll(File filesDirectory) throws IOException {
        try (RetroRewindInstallStorage.InstallLock lock =
                     RetroRewindInstallStorage.tryInstallLock(filesDirectory)) {
            if (lock == null) {
                throw new IOException("Retro Rewind is being installed. Try again when it finishes.");
            }
            Path directory = directory(filesDirectory);
            if (!Files.isDirectory(directory, LinkOption.NOFOLLOW_LINKS)) return 0;
            int removed = 0;
            try (DirectoryStream<Path> entries = Files.newDirectoryStream(directory)) {
                for (Path entry : entries) {
                    if (isTrack(entry)) {
                        Files.delete(entry);
                        removed += 1;
                    }
                }
            }
            return removed;
        }
    }

    private static Path prepareDirectory(File filesDirectory) throws IOException {
        Path pack = RetroRewindInstallStorage.installedRoot(filesDirectory).resolve("RetroRewind6");
        if (!Files.isDirectory(pack, LinkOption.NOFOLLOW_LINKS)) {
            throw new IOException("Set up Retro Rewind first, then add music.");
        }
        Path directory = pack.resolve("MyStuff");
        if (!Files.exists(directory, LinkOption.NOFOLLOW_LINKS)) {
            Files.createDirectory(directory);
        } else if (!Files.isDirectory(directory, LinkOption.NOFOLLOW_LINKS)) {
            throw new IOException("The Retro Rewind music folder is invalid.");
        }
        return directory;
    }

    /** Writes through a temporary file; returns false for a name or file that isn't music. */
    private static boolean writeTrack(Path directory, String name, InputStream input)
            throws IOException {
        if (!TRACK_NAME.matcher(name).matches()) return false;
        Path temporary = directory.resolve(".import-" + UUID.randomUUID() + ".tmp");
        boolean valid = false;
        try {
            try (OutputStream output = Files.newOutputStream(temporary)) {
                byte[] buffer = new byte[64 * 1024];
                long total = 0;
                for (int read; (read = input.read(buffer)) > 0; ) {
                    if (total < MAGIC.length) {
                        for (int index = 0; index < read && total + index < MAGIC.length; index++) {
                            if (buffer[index] != MAGIC[(int) total + index]) return false;
                        }
                    }
                    total += read;
                    if (total > MAX_TRACK_BYTES) return false;
                    output.write(buffer, 0, read);
                }
                if (total < MAGIC.length) return false;
            }
            Path target = directory.resolve(name);
            if (Files.exists(target, LinkOption.NOFOLLOW_LINKS) &&
                    !Files.isRegularFile(target, LinkOption.NOFOLLOW_LINKS)) {
                return false;
            }
            Files.move(temporary, target, StandardCopyOption.REPLACE_EXISTING,
                    StandardCopyOption.ATOMIC_MOVE);
            valid = true;
            return true;
        } finally {
            if (!valid) Files.deleteIfExists(temporary);
        }
    }

    private static boolean isTrack(Path entry) {
        return Files.isRegularFile(entry, LinkOption.NOFOLLOW_LINKS) &&
                TRACK_NAME.matcher(entry.getFileName().toString()).matches();
    }

    private static String baseName(String path) {
        String name = path == null ? "" : path;
        int slash = Math.max(name.lastIndexOf('/'), name.lastIndexOf('\\'));
        return slash >= 0 ? name.substring(slash + 1) : name;
    }
}
