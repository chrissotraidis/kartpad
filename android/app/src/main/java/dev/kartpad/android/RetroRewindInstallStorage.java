package dev.kartpad.android;

import java.io.File;
import java.io.IOException;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.StandardCopyOption;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** Owns same-volume Retro Rewind staging, activation, rollback, and recovery. */
final class RetroRewindInstallStorage {
    private static final String SUPPORT_DIRECTORY = "KartPad";
    private static final String INSTALLED_DIRECTORY = "RetroRewind";
    private static final String STAGING_PREFIX = "RetroRewind.import-";
    private static final String ROLLBACK_PREFIX = "RetroRewind.rollback-";

    @FunctionalInterface
    interface AtomicMover {
        void move(Path source, Path destination) throws IOException;
    }

    private RetroRewindInstallStorage() {}

    static void recover(File filesDirectory) throws IOException {
        Path support = supportRoot(filesDirectory);
        if (!exists(support)) {
            return;
        }
        requireDirectory(support, "Retro Rewind support root is invalid");

        List<Path> rollbacks = new ArrayList<>();
        try (var entries = Files.newDirectoryStream(support)) {
            for (Path entry : entries) {
                String name = entry.getFileName().toString();
                if (name.startsWith(STAGING_PREFIX)) {
                    deleteTree(entry);
                } else if (name.startsWith(ROLLBACK_PREFIX)) {
                    requireDirectory(entry, "Retro Rewind rollback entry is invalid");
                    rollbacks.add(entry);
                }
            }
        }
        rollbacks.sort(Comparator.comparing(path -> path.getFileName().toString()));

        Path installed = support.resolve(INSTALLED_DIRECTORY);
        if (exists(installed)) {
            requireDirectory(installed, "Retro Rewind installed root is invalid");
        } else if (rollbacks.size() == 1) {
            atomicMove(rollbacks.get(0), installed);
        }
    }

    static Path createStagingDirectory(File filesDirectory, String token)
            throws IOException {
        requireToken(token);
        Path support = supportRoot(filesDirectory);
        Files.createDirectories(support);
        requireDirectory(support, "Retro Rewind support root is invalid");
        Path staging = support.resolve(STAGING_PREFIX + token);
        return Files.createDirectory(staging);
    }

    static void activateValidatedStaging(File filesDirectory, Path staging, String token)
            throws IOException {
        activateValidatedStaging(filesDirectory, staging, token,
                RetroRewindInstallStorage::atomicMove);
    }

    static void discardStagingDirectory(File filesDirectory, Path staging, String token)
            throws IOException {
        requireToken(token);
        Path support = supportRoot(filesDirectory).toAbsolutePath().normalize();
        requireDirectory(support, "Retro Rewind support root is invalid");
        Path expectedStaging = support.resolve(STAGING_PREFIX + token);
        Path normalizedStaging = staging.toAbsolutePath().normalize();
        if (!normalizedStaging.equals(expectedStaging)) {
            throw new IOException("Retro Rewind staging directory is invalid");
        }
        if (exists(normalizedStaging)) {
            requireDirectory(normalizedStaging, "Retro Rewind staging directory is invalid");
            deleteTree(normalizedStaging);
        }
    }

    static void activateValidatedStaging(
            File filesDirectory, Path staging, String token, AtomicMover mover)
            throws IOException {
        requireToken(token);
        Path support = supportRoot(filesDirectory).toAbsolutePath().normalize();
        requireDirectory(support, "Retro Rewind support root is invalid");
        Path expectedStaging = support.resolve(STAGING_PREFIX + token);
        Path normalizedStaging = staging.toAbsolutePath().normalize();
        if (!normalizedStaging.equals(expectedStaging)) {
            throw new IOException("Retro Rewind staging directory is invalid");
        }
        requireDirectory(normalizedStaging, "Retro Rewind staging directory is invalid");

        Path installed = support.resolve(INSTALLED_DIRECTORY);
        Path rollback = support.resolve(ROLLBACK_PREFIX + token);
        if (exists(rollback)) {
            throw new IOException("Retro Rewind rollback destination already exists");
        }

        boolean movedExisting = false;
        if (exists(installed)) {
            requireDirectory(installed, "Retro Rewind installed root is invalid");
            // Saves live beside pack content. Copy them before moving either root;
            // a failed copy must leave the installed pack and progress untouched.
            preserveRedirectedSaves(installed, normalizedStaging);
            mover.move(installed, rollback);
            movedExisting = true;
        }
        try {
            mover.move(normalizedStaging, installed);
        } catch (IOException activationError) {
            if (movedExisting && !exists(installed) && exists(rollback)) {
                try {
                    mover.move(rollback, installed);
                } catch (IOException restoreError) {
                    activationError.addSuppressed(restoreError);
                }
            }
            throw activationError;
        }

        if (movedExisting) {
            deleteTree(rollback);
        }
    }

    private static void preserveRedirectedSaves(Path installed, Path staging) throws IOException {
        Path riivolution = installed.resolve("riivolution");
        if (!exists(riivolution)) return;
        requireDirectory(riivolution, "Retro Rewind save parent is invalid");
        Path saves = riivolution.resolve("save");
        if (!exists(saves)) return;
        requireDirectory(saves, "Retro Rewind save root is invalid");

        Path destinationParent = staging.resolve("riivolution");
        ensureSaveDirectory(destinationParent);
        Path destination = destinationParent.resolve("save");
        // Do not follow links from either the retained data or the staged pack.
        Files.walkFileTree(saves, new SimpleFileVisitor<>() {
            @Override
            public FileVisitResult preVisitDirectory(Path directory, BasicFileAttributes attrs)
                    throws IOException {
                ensureSaveDirectory(destination.resolve(saves.relativize(directory)));
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs)
                    throws IOException {
                Path target = destination.resolve(saves.relativize(file));
                if (!attrs.isRegularFile() || (exists(target) &&
                        !Files.isRegularFile(target, LinkOption.NOFOLLOW_LINKS))) {
                    throw new IOException("Retro Rewind save entry is invalid");
                }
                Files.copy(file, target, StandardCopyOption.REPLACE_EXISTING,
                        LinkOption.NOFOLLOW_LINKS);
                return FileVisitResult.CONTINUE;
            }
        });
    }

    private static void ensureSaveDirectory(Path directory) throws IOException {
        if (exists(directory)) {
            requireDirectory(directory, "Retro Rewind save destination is invalid");
        } else {
            Files.createDirectory(directory);
        }
    }

    static Path supportRoot(File filesDirectory) {
        return filesDirectory.toPath().resolve(SUPPORT_DIRECTORY)
                .toAbsolutePath().normalize();
    }

    static Path installedRoot(File filesDirectory) {
        return supportRoot(filesDirectory).resolve(INSTALLED_DIRECTORY);
    }

    private static void requireToken(String token) {
        if (token == null || token.isEmpty() || token.length() > 64 ||
                !token.matches("[A-Za-z0-9-]+")) {
            throw new IllegalArgumentException("Invalid Retro Rewind install token");
        }
    }

    private static void requireDirectory(Path path, String message) throws IOException {
        if (!Files.isDirectory(path, LinkOption.NOFOLLOW_LINKS)) {
            throw new IOException(message);
        }
    }

    private static void atomicMove(Path source, Path destination) throws IOException {
        Files.move(source, destination, StandardCopyOption.ATOMIC_MOVE);
    }

    private static boolean exists(Path path) {
        return Files.exists(path, LinkOption.NOFOLLOW_LINKS);
    }

    private static void deleteTree(Path root) throws IOException {
        if (!exists(root)) {
            return;
        }
        Files.walkFileTree(root, new SimpleFileVisitor<>() {
            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attributes)
                    throws IOException {
                Files.delete(file);
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult postVisitDirectory(Path directory, IOException error)
                    throws IOException {
                if (error != null) {
                    throw error;
                }
                Files.delete(directory);
                return FileVisitResult.CONTINUE;
            }
        });
    }
}
