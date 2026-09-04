package dev.kartpad.android;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.LinkOption;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/** Validates a staged or installed Retro Rewind tree without exposing its path. */
final class RetroRewindInstallValidator {
    private static final int MAXIMUM_VERSION_BYTES = 128;
    private static final int HASH_BUFFER_BYTES = 1024 * 1024;

    enum Error {
        NONE,
        MISSING_ROOT,
        VERSION_MISMATCH,
        INVALID_REQUIREMENT,
        MISSING_ARTIFACT,
        SIZE_MISMATCH,
        HASH_MISMATCH,
        IO_ERROR,
    }

    static final class Result {
        final Error error;
        final String artifact;

        Result(Error error, String artifact) {
            this.error = error;
            this.artifact = artifact;
        }

        boolean isValid() {
            return error == Error.NONE;
        }
    }

    static final class ArtifactRequirement {
        final String relativePath;
        final long bytes;
        final String sha256;

        ArtifactRequirement(String relativePath, long bytes, String sha256) {
            this.relativePath = relativePath;
            this.bytes = bytes;
            this.sha256 = sha256;
        }
    }

    static final class Contract {
        final String version;
        final String root;
        final List<ArtifactRequirement> artifacts;

        Contract(String version, String root, List<ArtifactRequirement> artifacts) {
            this.version = version;
            this.root = root;
            this.artifacts = Collections.unmodifiableList(new ArrayList<>(artifacts));
        }
    }

    private RetroRewindInstallValidator() {}

    static Contract productionContract() {
        return new Contract(
                RetroRewindRelease.VERSION,
                RetroRewindRelease.ROOT,
                Arrays.asList(
                        new ArtifactRequirement(
                                RetroRewindRelease.CODE_PUL_PATH,
                                RetroRewindRelease.CODE_PUL_BYTES,
                                RetroRewindRelease.CODE_PUL_SHA256),
                        new ArtifactRequirement(
                                RetroRewindRelease.XML_PATH,
                                RetroRewindRelease.XML_BYTES,
                                RetroRewindRelease.XML_SHA256)));
    }

    static Result validate(Path installedRoot, Contract contract) {
        try {
            Path root = installedRoot.toAbsolutePath().normalize();
            if (!Files.isDirectory(root, LinkOption.NOFOLLOW_LINKS)) {
                return failed(Error.MISSING_ROOT, null);
            }
            if (contract.version == null || contract.version.isEmpty() ||
                    !isSafeComponent(contract.root)) {
                return failed(Error.INVALID_REQUIREMENT, null);
            }

            String installedVersion = readVersion(root.resolve("version.txt"));
            if (!contract.version.equals(installedVersion)) {
                return failed(Error.VERSION_MISMATCH, "version.txt");
            }

            for (ArtifactRequirement requirement : contract.artifacts) {
                Result result = validateArtifact(root, requirement);
                if (!result.isValid()) {
                    return result;
                }
            }
            return new Result(Error.NONE, null);
        } catch (IOException error) {
            return failed(Error.IO_ERROR, null);
        }
    }

    static Result validateAndActivate(
            File filesDirectory, Path staging, String token, Contract contract) {
        if (contract == null || !isSafeComponent(contract.root)) {
            return failed(Error.INVALID_REQUIREMENT, null);
        }
        Result validation = validate(staging.resolve(contract.root), contract);
        if (!validation.isValid()) {
            return validation;
        }
        try {
            RetroRewindInstallStorage.activateValidatedStaging(
                    filesDirectory, staging, token);
            return new Result(Error.NONE, null);
        } catch (IOException error) {
            return failed(Error.IO_ERROR, null);
        }
    }

    private static Result validateArtifact(Path root, ArtifactRequirement requirement)
            throws IOException {
        if (requirement == null || requirement.bytes < 0 ||
                !isLowercaseSha256(requirement.sha256) ||
                !isSafeRelativePath(requirement.relativePath)) {
            return failed(Error.INVALID_REQUIREMENT, null);
        }

        Path relative = Paths.get(requirement.relativePath);
        Path current = root;
        for (int index = 0; index < relative.getNameCount() - 1; ++index) {
            current = current.resolve(relative.getName(index));
            if (!Files.isDirectory(current, LinkOption.NOFOLLOW_LINKS)) {
                return failed(Error.MISSING_ARTIFACT, requirement.relativePath);
            }
        }
        Path file = root.resolve(relative).normalize();
        if (!file.startsWith(root) || !Files.isRegularFile(file, LinkOption.NOFOLLOW_LINKS)) {
            return failed(Error.MISSING_ARTIFACT, requirement.relativePath);
        }
        if (Files.size(file) != requirement.bytes) {
            return failed(Error.SIZE_MISMATCH, requirement.relativePath);
        }

        HashResult hash = sha256(file);
        if (hash.bytes != requirement.bytes) {
            return failed(Error.SIZE_MISMATCH, requirement.relativePath);
        }
        if (!hash.hex.equals(requirement.sha256)) {
            return failed(Error.HASH_MISMATCH, requirement.relativePath);
        }
        return new Result(Error.NONE, null);
    }

    private static String readVersion(Path path) throws IOException {
        if (!Files.isRegularFile(path, LinkOption.NOFOLLOW_LINKS)) {
            return null;
        }
        byte[] bytes;
        try (InputStream input = Files.newInputStream(path)) {
            byte[] bounded = new byte[MAXIMUM_VERSION_BYTES + 1];
            int total = 0;
            while (total < bounded.length) {
                int count = input.read(bounded, total, bounded.length - total);
                if (count == -1) {
                    break;
                }
                total += count;
            }
            bytes = Arrays.copyOf(bounded, total);
        }
        if (bytes.length > MAXIMUM_VERSION_BYTES) {
            return null;
        }
        String decoded;
        try {
            decoded = StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes)).toString();
        } catch (CharacterCodingException error) {
            return null;
        }
        return trimWhitespace(decoded);
    }

    private static String trimWhitespace(String value) {
        int start = 0;
        int end = value.length();
        while (start < end && isWhitespace(value.charAt(start))) {
            ++start;
        }
        while (end > start && isWhitespace(value.charAt(end - 1))) {
            --end;
        }
        return value.substring(start, end);
    }

    private static boolean isWhitespace(char value) {
        return Character.isWhitespace(value) || Character.isSpaceChar(value);
    }

    private static HashResult sha256(Path path) throws IOException {
        MessageDigest digest;
        try {
            digest = MessageDigest.getInstance("SHA-256");
        } catch (NoSuchAlgorithmException error) {
            throw new AssertionError("Android runtime has no SHA-256", error);
        }
        byte[] buffer = new byte[HASH_BUFFER_BYTES];
        long bytes = 0;
        try (InputStream input = Files.newInputStream(path)) {
            int count;
            while ((count = input.read(buffer)) != -1) {
                digest.update(buffer, 0, count);
                bytes += count;
            }
        }
        return new HashResult(bytes, hex(digest.digest()));
    }

    private static boolean isSafeRelativePath(String value) {
        if (value == null || value.isEmpty() || value.startsWith("/") ||
                value.contains("\\") || value.indexOf('\0') >= 0 || value.contains(":")) {
            return false;
        }
        String[] components = value.split("/", -1);
        if (components.length == 0) {
            return false;
        }
        for (String component : components) {
            if (!isSafeComponent(component)) {
                return false;
            }
        }
        return true;
    }

    private static boolean isSafeComponent(String value) {
        return value != null && !value.isEmpty() && !value.equals(".") &&
                !value.equals("..") && !value.contains("/") &&
                !value.contains("\\") && !value.contains(":") &&
                value.indexOf('\0') < 0;
    }

    private static boolean isLowercaseSha256(String value) {
        if (value == null || value.length() != 64) {
            return false;
        }
        for (int index = 0; index < value.length(); ++index) {
            char character = value.charAt(index);
            if (!((character >= '0' && character <= '9') ||
                    (character >= 'a' && character <= 'f'))) {
                return false;
            }
        }
        return true;
    }

    private static String hex(byte[] bytes) {
        char[] digits = "0123456789abcdef".toCharArray();
        char[] output = new char[bytes.length * 2];
        for (int index = 0; index < bytes.length; ++index) {
            int value = bytes[index] & 0xff;
            output[index * 2] = digits[value >>> 4];
            output[index * 2 + 1] = digits[value & 0x0f];
        }
        return new String(output);
    }

    private static Result failed(Error error, String artifact) {
        return new Result(error, artifact);
    }

    private static final class HashResult {
        final long bytes;
        final String hex;

        HashResult(long bytes, String hex) {
            this.bytes = bytes;
            this.hex = hex;
        }
    }
}
