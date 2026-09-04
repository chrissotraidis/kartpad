package dev.kartpad.android;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.util.List;
import java.util.stream.Stream;

public final class RetroRewindInstallValidatorTestMain {
    private static final byte[] CODE = "code-data".getBytes();
    private static final byte[] XML = "xml-data".getBytes();

    private RetroRewindInstallValidatorTestMain() {}

    public static void main(String[] args) throws Exception {
        Path temporary = Files.createTempDirectory("kartpad-content-test-");
        try {
            testValidAndActivated(temporary.resolve("valid"));
            testVersionFailures(temporary.resolve("version"));
            testArtifactFailures(temporary.resolve("artifact"));
            testRequirementAndSymlinkFailures(temporary.resolve("safety"));
            testProductionContract();
        } finally {
            deleteTree(temporary);
        }
    }

    private static void testValidAndActivated(Path base) throws Exception {
        Path filesPath = Files.createDirectories(base.resolve("files"));
        Path staging = RetroRewindInstallStorage.createStagingDirectory(
                filesPath.toFile(), "valid");
        Path root = staging.resolve("RetroRewind6");
        writeValidTree(root);

        expectValid(RetroRewindInstallValidator.validate(root, testContract()));
        expectValid(RetroRewindInstallValidator.validateAndActivate(
                filesPath.toFile(), staging, "valid", testContract()));
        Path active = RetroRewindInstallStorage.supportRoot(filesPath.toFile())
                .resolve("RetroRewind/RetroRewind6");
        expectValid(RetroRewindInstallValidator.validate(active, testContract()));

        Path invalidStaging = RetroRewindInstallStorage.createStagingDirectory(
                filesPath.toFile(), "invalid");
        Path invalidRoot = invalidStaging.resolve("RetroRewind6");
        writeValidTree(invalidRoot);
        Files.delete(invalidRoot.resolve("Binaries/Code.pul"));
        expectError(
                RetroRewindInstallValidator.validateAndActivate(
                        filesPath.toFile(), invalidStaging, "invalid", testContract()),
                RetroRewindInstallValidator.Error.MISSING_ARTIFACT);
        expect(Files.exists(invalidStaging), "invalid staging was activated");
        expectValid(RetroRewindInstallValidator.validate(active, testContract()));
    }

    private static void testVersionFailures(Path base) throws Exception {
        Path root = base.resolve("wrong");
        writeValidTree(root);
        Files.writeString(root.resolve("version.txt"), "6.12.4\n");
        expectError(
                RetroRewindInstallValidator.validate(root, testContract()),
                RetroRewindInstallValidator.Error.VERSION_MISMATCH);

        root = base.resolve("invalid-utf8");
        writeValidTree(root);
        Files.write(root.resolve("version.txt"), new byte[] {(byte) 0xc3, (byte) 0x28});
        expectError(
                RetroRewindInstallValidator.validate(root, testContract()),
                RetroRewindInstallValidator.Error.VERSION_MISMATCH);

        root = base.resolve("oversize");
        writeValidTree(root);
        Files.write(root.resolve("version.txt"), new byte[129]);
        expectError(
                RetroRewindInstallValidator.validate(root, testContract()),
                RetroRewindInstallValidator.Error.VERSION_MISMATCH);
    }

    private static void testArtifactFailures(Path base) throws Exception {
        Path missing = base.resolve("missing");
        writeValidTree(missing);
        Files.delete(missing.resolve("xml/RetroRewind6.xml"));
        expectError(
                RetroRewindInstallValidator.validate(missing, testContract()),
                RetroRewindInstallValidator.Error.MISSING_ARTIFACT);

        Path size = base.resolve("size");
        writeValidTree(size);
        Files.writeString(size.resolve("Binaries/Code.pul"), "short");
        expectError(
                RetroRewindInstallValidator.validate(size, testContract()),
                RetroRewindInstallValidator.Error.SIZE_MISMATCH);

        Path hash = base.resolve("hash");
        writeValidTree(hash);
        Files.writeString(hash.resolve("Binaries/Code.pul"), "code-datA");
        expectError(
                RetroRewindInstallValidator.validate(hash, testContract()),
                RetroRewindInstallValidator.Error.HASH_MISMATCH);
    }

    private static void testRequirementAndSymlinkFailures(Path base) throws Exception {
        Path root = base.resolve("root");
        writeValidTree(root);
        var unsafe = new RetroRewindInstallValidator.Contract(
                "6.12.5",
                "RetroRewind6",
                List.of(new RetroRewindInstallValidator.ArtifactRequirement(
                        "../outside", 1, "0".repeat(64))));
        expectError(
                RetroRewindInstallValidator.validate(root, unsafe),
                RetroRewindInstallValidator.Error.INVALID_REQUIREMENT);

        Path outside = base.resolve("outside");
        Files.writeString(outside, "code-data");
        Files.delete(root.resolve("Binaries/Code.pul"));
        Files.createSymbolicLink(root.resolve("Binaries/Code.pul"), outside);
        expectError(
                RetroRewindInstallValidator.validate(root, testContract()),
                RetroRewindInstallValidator.Error.MISSING_ARTIFACT);
    }

    private static void testProductionContract() {
        var contract = RetroRewindInstallValidator.productionContract();
        expect(contract.version.equals("6.12.5"), "production version drifted");
        expect(contract.root.equals("RetroRewind6"), "production root drifted");
        expect(contract.artifacts.size() == 2, "production artifact count drifted");
    }

    private static RetroRewindInstallValidator.Contract testContract() throws Exception {
        return new RetroRewindInstallValidator.Contract(
                "6.12.5",
                "RetroRewind6",
                List.of(
                        new RetroRewindInstallValidator.ArtifactRequirement(
                                "Binaries/Code.pul", CODE.length, sha256(CODE)),
                        new RetroRewindInstallValidator.ArtifactRequirement(
                                "xml/RetroRewind6.xml", XML.length, sha256(XML))));
    }

    private static void writeValidTree(Path root) throws IOException {
        Files.createDirectories(root.resolve("Binaries"));
        Files.createDirectories(root.resolve("xml"));
        Files.writeString(root.resolve("version.txt"), " 6.12.5\n");
        Files.write(root.resolve("Binaries/Code.pul"), CODE);
        Files.write(root.resolve("xml/RetroRewind6.xml"), XML);
    }

    private static String sha256(byte[] bytes) throws Exception {
        byte[] digest = MessageDigest.getInstance("SHA-256").digest(bytes);
        StringBuilder output = new StringBuilder(digest.length * 2);
        for (byte value : digest) {
            output.append(String.format("%02x", value & 0xff));
        }
        return output.toString();
    }

    private static void expectValid(RetroRewindInstallValidator.Result result) {
        expect(result.isValid(), "expected valid content, got " + result.error);
    }

    private static void expectError(
            RetroRewindInstallValidator.Result result,
            RetroRewindInstallValidator.Error expected) {
        expect(!result.isValid() && result.error == expected,
                "expected " + expected + ", got " + result.error);
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
