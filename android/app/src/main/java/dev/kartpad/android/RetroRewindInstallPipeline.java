package dev.kartpad.android;

import java.io.File;
import java.io.IOException;
import java.nio.file.Path;

/** Joins verified archive input, bounded extraction, validation, and activation. */
final class RetroRewindInstallPipeline {
    @FunctionalInterface
    interface ArchiveVerifier {
        RetroRewindArchiveDownload.Error verify(Path archive);
    }

    @FunctionalInterface
    interface Extractor {
        RetroRewindArchiveExtractor.Result extract(
                Path archive,
                Path staging,
                RetroRewindArchiveExtractor.Cancellation cancellation,
                RetroRewindArchiveExtractor.Progress progress) throws IOException;
    }

    enum Error {
        NONE,
        ARCHIVE_INVALID,
        STAGING_FAILURE,
        EXTRACTION_FAILURE,
        CONTENT_INVALID,
        ACTIVATION_FAILURE,
    }

    static final class Result {
        final Error error;
        final RetroRewindArchiveExtractor.Error extractionError;
        final RetroRewindInstallValidator.Error validationError;

        Result(
                Error error,
                RetroRewindArchiveExtractor.Error extractionError,
                RetroRewindInstallValidator.Error validationError) {
            this.error = error;
            this.extractionError = extractionError;
            this.validationError = validationError;
        }

        boolean isInstalled() {
            return error == Error.NONE;
        }
    }

    private RetroRewindInstallPipeline() {}

    static Result install(
            File filesDirectory,
            Path archive,
            String token,
            RetroRewindArchiveExtractor.Cancellation cancellation,
            RetroRewindArchiveExtractor.Progress progress) {
        return install(
                filesDirectory,
                archive,
                token,
                cancellation,
                progress,
                path -> RetroRewindArchiveDownload.verifyFile(
                        path,
                        RetroRewindRelease.ARCHIVE_BYTES,
                        RetroRewindRelease.ARCHIVE_SHA256),
                RetroRewindArchiveExtractor::extract,
                RetroRewindInstallValidator.productionContract());
    }

    static Result install(
            File filesDirectory,
            Path archive,
            String token,
            RetroRewindArchiveExtractor.Cancellation cancellation,
            RetroRewindArchiveExtractor.Progress progress,
            ArchiveVerifier verifier,
            Extractor extractor,
            RetroRewindInstallValidator.Contract contract) {
        if (filesDirectory == null || archive == null || cancellation == null ||
                progress == null || verifier == null || extractor == null || contract == null) {
            return failed(Error.STAGING_FAILURE, null, null);
        }
        if (verifier.verify(archive) != RetroRewindArchiveDownload.Error.NONE) {
            return failed(Error.ARCHIVE_INVALID, null, null);
        }

        Path staging = null;
        boolean activated = false;
        try {
            staging = RetroRewindInstallStorage.createStagingDirectory(filesDirectory, token);
        } catch (IOException | IllegalArgumentException exception) {
            return failed(Error.STAGING_FAILURE, null, null);
        }
        try {
            RetroRewindArchiveExtractor.Result extraction;
            try {
                extraction = extractor.extract(archive, staging, cancellation, progress);
            } catch (IOException exception) {
                return failed(Error.EXTRACTION_FAILURE,
                        RetroRewindArchiveExtractor.Error.IO_FAILURE, null);
            }
            if (!extraction.isComplete()) {
                return failed(Error.EXTRACTION_FAILURE, extraction.error, null);
            }
            RetroRewindInstallValidator.Result validation =
                    RetroRewindInstallValidator.validateAndActivate(
                            filesDirectory, staging, token, contract);
            if (!validation.isValid()) {
                Error error = validation.error == RetroRewindInstallValidator.Error.IO_ERROR
                        ? Error.ACTIVATION_FAILURE : Error.CONTENT_INVALID;
                return failed(error, extraction.error, validation.error);
            }
            activated = true;
            return failed(Error.NONE, extraction.error, validation.error);
        } finally {
            if (!activated && staging != null) {
                try {
                    RetroRewindInstallStorage.discardStagingDirectory(
                            filesDirectory, staging, token);
                } catch (IOException | IllegalArgumentException ignored) {
                    // Startup recovery retries cleanup without risking active data.
                }
            }
        }
    }

    private static Result failed(
            Error error,
            RetroRewindArchiveExtractor.Error extractionError,
            RetroRewindInstallValidator.Error validationError) {
        return new Result(error, extractionError, validationError);
    }
}
