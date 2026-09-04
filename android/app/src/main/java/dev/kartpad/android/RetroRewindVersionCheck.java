package dev.kartpad.android;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;

/** Bounded official-version check for the code-pinned Retro Rewind profile. */
final class RetroRewindVersionCheck {
    private static final int MAXIMUM_MANIFEST_BYTES = 512 * 1024;
    private static final int MAXIMUM_VERSION_CHARACTERS = 64;
    private static final int BUFFER_BYTES = 16 * 1024;
    private static final int MAXIMUM_REDIRECTS = 5;
    private static final int CONNECT_TIMEOUT_MILLIS = 15_000;
    private static final int READ_TIMEOUT_MILLIS = 15_000;

    interface Cancellation {
        boolean isCancelled();
    }

    enum Error {
        NONE,
        CANCELLED,
        INVALID_MANIFEST,
        INSECURE_REDIRECT,
        TOO_MANY_REDIRECTS,
        HTTP_FAILURE,
        NETWORK_FAILURE,
    }

    static final class Result {
        final Error error;
        final String latestVersion;
        final boolean updateRequired;

        Result(Error error, String latestVersion, boolean updateRequired) {
            this.error = error;
            this.latestVersion = latestVersion;
            this.updateRequired = updateRequired;
        }

        boolean isReady() {
            return error == Error.NONE;
        }
    }

    private RetroRewindVersionCheck() {}

    static Result checkRelease(Cancellation cancellation) {
        try {
            return checkFrom(new URL(RetroRewindRelease.VERSION_MANIFEST_URL), cancellation);
        } catch (IOException exception) {
            return failed(Error.NETWORK_FAILURE);
        }
    }

    static Result checkFrom(URL initial, Cancellation cancellation) {
        if (cancellation == null) {
            return failed(Error.NETWORK_FAILURE);
        }
        URL current = initial;
        for (int redirects = 0; redirects <= MAXIMUM_REDIRECTS; redirects++) {
            if (cancellation.isCancelled()) {
                return failed(Error.CANCELLED);
            }
            if (current == null || !"https".equalsIgnoreCase(current.getProtocol())) {
                return failed(Error.INSECURE_REDIRECT);
            }

            HttpURLConnection connection = null;
            try {
                connection = (HttpURLConnection) current.openConnection();
                connection.setInstanceFollowRedirects(false);
                connection.setConnectTimeout(CONNECT_TIMEOUT_MILLIS);
                connection.setReadTimeout(READ_TIMEOUT_MILLIS);
                connection.setRequestProperty("Accept-Encoding", "identity");
                int response = connection.getResponseCode();
                if (isRedirect(response)) {
                    if (redirects == MAXIMUM_REDIRECTS) {
                        return failed(Error.TOO_MANY_REDIRECTS);
                    }
                    String location = connection.getHeaderField("Location");
                    if (location == null || location.isEmpty()) {
                        return failed(Error.HTTP_FAILURE);
                    }
                    current = new URL(current, location);
                    continue;
                }
                if (response != HttpURLConnection.HTTP_OK) {
                    return failed(Error.HTTP_FAILURE);
                }
                String encoding = connection.getContentEncoding();
                if (encoding != null && !"identity".equalsIgnoreCase(encoding)) {
                    return failed(Error.HTTP_FAILURE);
                }
                long declaredBytes = connection.getContentLengthLong();
                if (declaredBytes > MAXIMUM_MANIFEST_BYTES) {
                    return failed(Error.INVALID_MANIFEST);
                }
                byte[] body;
                try (InputStream input = connection.getInputStream()) {
                    body = readBounded(input, cancellation);
                }
                if (body == null) {
                    return failed(cancellation.isCancelled()
                            ? Error.CANCELLED : Error.INVALID_MANIFEST);
                }
                if (declaredBytes >= 0 && body.length != declaredBytes) {
                    return failed(Error.INVALID_MANIFEST);
                }
                String latest = parseLatest(body);
                if (latest == null) {
                    return failed(Error.INVALID_MANIFEST);
                }
                return new Result(Error.NONE, latest,
                        compareVersions(latest, RetroRewindRelease.VERSION) > 0);
            } catch (IOException exception) {
                return failed(Error.NETWORK_FAILURE);
            } finally {
                if (connection != null) {
                    connection.disconnect();
                }
            }
        }
        return failed(Error.TOO_MANY_REDIRECTS);
    }

    static String parseLatest(byte[] body) {
        if (body == null || body.length == 0 || body.length > MAXIMUM_MANIFEST_BYTES) {
            return null;
        }
        final String text;
        try {
            text = StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(body)).toString();
        } catch (CharacterCodingException exception) {
            return null;
        }

        String latest = null;
        for (String line : text.split("\\R", -1)) {
            String trimmed = line.trim();
            if (trimmed.isEmpty()) {
                continue;
            }
            int separator = firstWhitespace(trimmed);
            String version = separator < 0 ? trimmed : trimmed.substring(0, separator);
            if (!isValidVersion(version)) {
                return null;
            }
            if (latest == null || compareVersions(version, latest) > 0) {
                latest = version;
            }
        }
        return latest;
    }

    static int compareVersions(String left, String right) {
        if (!isValidVersion(left) || !isValidVersion(right)) {
            throw new IllegalArgumentException("Invalid Retro Rewind version");
        }
        String[] leftParts = left.split("\\.", -1);
        String[] rightParts = right.split("\\.", -1);
        int count = Math.max(leftParts.length, rightParts.length);
        for (int index = 0; index < count; index++) {
            String leftPart = index < leftParts.length ? normalizedNumber(leftParts[index]) : "0";
            String rightPart = index < rightParts.length ? normalizedNumber(rightParts[index]) : "0";
            if (leftPart.length() != rightPart.length()) {
                return Integer.compare(leftPart.length(), rightPart.length());
            }
            int comparison = leftPart.compareTo(rightPart);
            if (comparison != 0) {
                return comparison;
            }
        }
        return 0;
    }

    private static byte[] readBounded(InputStream input, Cancellation cancellation)
            throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[BUFFER_BYTES];
        while (true) {
            if (cancellation.isCancelled()) {
                return null;
            }
            int count = input.read(buffer);
            if (count == -1) {
                return output.toByteArray();
            }
            if (count == 0) {
                continue;
            }
            if (output.size() > MAXIMUM_MANIFEST_BYTES - count) {
                return null;
            }
            output.write(buffer, 0, count);
        }
    }

    private static boolean isValidVersion(String version) {
        if (version == null || version.length() > MAXIMUM_VERSION_CHARACTERS) {
            return false;
        }
        String[] parts = version.split("\\.", -1);
        if (parts.length < 2 || parts.length > 4) {
            return false;
        }
        for (String part : parts) {
            if (part.isEmpty()) {
                return false;
            }
            for (int index = 0; index < part.length(); index++) {
                char value = part.charAt(index);
                if (value < '0' || value > '9') {
                    return false;
                }
            }
        }
        return true;
    }

    private static String normalizedNumber(String value) {
        int index = 0;
        while (index + 1 < value.length() && value.charAt(index) == '0') {
            index++;
        }
        return value.substring(index);
    }

    private static int firstWhitespace(String value) {
        for (int index = 0; index < value.length(); index++) {
            if (Character.isWhitespace(value.charAt(index))) {
                return index;
            }
        }
        return -1;
    }

    private static boolean isRedirect(int response) {
        return response == HttpURLConnection.HTTP_MOVED_PERM ||
                response == HttpURLConnection.HTTP_MOVED_TEMP ||
                response == HttpURLConnection.HTTP_SEE_OTHER ||
                response == 307 || response == 308;
    }

    private static Result failed(Error error) {
        return new Result(error, null, false);
    }
}
