package dev.kartpad.android;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLConnection;
import java.net.URLStreamHandler;
import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.Arrays;
import java.util.Queue;

public final class RetroRewindVersionCheckTestMain {
    private RetroRewindVersionCheckTestMain() {}

    public static void main(String[] args) throws Exception {
        if (args.length == 1 && "--live".equals(args[0])) {
            var live = RetroRewindVersionCheck.checkRelease(() -> false);
            expect(live.isReady(), "official version check failed: " + live.error);
            System.out.println("KartPad pins Retro Rewind " + RetroRewindRelease.VERSION +
                    "; official feed reports " + live.latestVersion);
            if (live.updateRequired) {
                throw new IllegalStateException(
                        "newer Retro Rewind requires a KartPad profile update");
            }
            return;
        }
        expect(args.length == 0, "only --live is supported");
        expectLatest("6.12.5\n", "6.12.5");
        expectLatest("6.12.4 old\n6.12.6 current\n6.12.5\n", "6.12.6");
        expectLatest("  006.012.0005  stable  \r\n", "006.012.0005");
        expectLatest("\n \t\n", null);
        expectLatest("6.12.5\nnot-a-version\n", null);
        expectLatest("6..5\n", null);
        expectLatest("6.12.5.0.1\n", null);
        expectLatest("6." + "1".repeat(63) + "\n", null);
        expect(RetroRewindVersionCheck.parseLatest(new byte[] {(byte) 0xc3, 0x28}) == null,
                "invalid UTF-8 manifest accepted");
        expect(RetroRewindVersionCheck.parseLatest(new byte[512 * 1024 + 1]) == null,
                "oversized manifest accepted");

        expect(RetroRewindVersionCheck.compareVersions("6.12.5", "6.12.5.0") == 0,
                "zero suffix comparison changed");
        expect(RetroRewindVersionCheck.compareVersions("6.12.10", "6.12.9") > 0,
                "numeric component comparison became lexical");
        expect(RetroRewindVersionCheck.compareVersions(
                        "6.999999999999999999999999999999", "6.12.5") > 0,
                "large numeric component overflowed");
        expect(RetroRewindVersionCheck.compareVersions("006.012.0005", "6.12.5") == 0,
                "leading zero comparison changed");

        QueueHandler currentHandler = new QueueHandler(response(200, "6.12.5\n"));
        var current = RetroRewindVersionCheck.checkFrom(
                fixtureUrl("https://fixture.invalid/version", currentHandler), () -> false);
        expect(current.isReady() && !current.updateRequired &&
                        "6.12.5".equals(current.latestVersion),
                "current version did not pass");
        expect("identity".equals(currentHandler.opened.getRequestProperty("Accept-Encoding")),
                "version request did not disable content encoding");

        var update = RetroRewindVersionCheck.checkFrom(
                fixtureUrl("https://fixture.invalid/version",
                        new QueueHandler(response(200, "6.12.6\n"))), () -> false);
        expect(update.isReady() && update.updateRequired &&
                        "6.12.6".equals(update.latestVersion),
                "newer official version did not block the compiled profile");

        QueueHandler redirectHandler = new QueueHandler(
                response(302, new byte[0], "/current", null, 0),
                response(200, "6.12.5\n"));
        var redirected = RetroRewindVersionCheck.checkFrom(
                fixtureUrl("https://fixture.invalid/version", redirectHandler), () -> false);
        expect(redirected.isReady() && redirectHandler.opens == 2,
                "bounded HTTPS redirect failed");

        QueueHandler redirectLoop = new QueueHandler(
                response(302, new byte[0], "/again", null, 0),
                response(302, new byte[0], "/again", null, 0),
                response(302, new byte[0], "/again", null, 0),
                response(302, new byte[0], "/again", null, 0),
                response(302, new byte[0], "/again", null, 0),
                response(302, new byte[0], "/again", null, 0));
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("https://fixture.invalid/version", redirectLoop),
                        () -> false),
                RetroRewindVersionCheck.Error.TOO_MANY_REDIRECTS);

        QueueHandler insecureRedirectHandler = new QueueHandler(
                response(302, new byte[0], "http://fixture.invalid/current", null, 0));
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("https://fixture.invalid/version", insecureRedirectHandler),
                        () -> false),
                RetroRewindVersionCheck.Error.INSECURE_REDIRECT);
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("http://fixture.invalid/version",
                                new QueueHandler(response(200, "6.12.5\n"))),
                        () -> false),
                RetroRewindVersionCheck.Error.INSECURE_REDIRECT);
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("https://fixture.invalid/version",
                                new QueueHandler(response(500, new byte[0], null, null, 0))),
                        () -> false),
                RetroRewindVersionCheck.Error.HTTP_FAILURE);
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("https://fixture.invalid/version",
                                new QueueHandler(response(
                                        200, "6.12.5\n".getBytes(StandardCharsets.UTF_8),
                                        null, "gzip", 7))),
                        () -> false),
                RetroRewindVersionCheck.Error.HTTP_FAILURE);
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("https://fixture.invalid/version",
                                new QueueHandler(response(
                                        200, "6.12.5\n".getBytes(StandardCharsets.UTF_8),
                                        null, null, 512 * 1024 + 1))),
                        () -> false),
                RetroRewindVersionCheck.Error.INVALID_MANIFEST);
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("https://fixture.invalid/version",
                                new QueueHandler(response(
                                        200, "6.12.5\n".getBytes(StandardCharsets.UTF_8),
                                        null, null, 1))),
                        () -> false),
                RetroRewindVersionCheck.Error.INVALID_MANIFEST);

        byte[] oversized = new byte[512 * 1024 + 1];
        Arrays.fill(oversized, (byte) '1');
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("https://fixture.invalid/version",
                                new QueueHandler(response(200, oversized, null, null, -1))),
                        () -> false),
                RetroRewindVersionCheck.Error.INVALID_MANIFEST);
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("https://fixture.invalid/version",
                                new QueueHandler(response(200, "6.12.5\n"))),
                        () -> true),
                RetroRewindVersionCheck.Error.CANCELLED);
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("https://fixture.invalid/version", new QueueHandler()),
                        () -> false),
                RetroRewindVersionCheck.Error.NETWORK_FAILURE);
        var midReadCancellation = new RetroRewindVersionCheck.Cancellation() {
            private int probes;

            @Override
            public boolean isCancelled() {
                probes++;
                return probes > 1;
            }
        };
        expectError(RetroRewindVersionCheck.checkFrom(
                        fixtureUrl("https://fixture.invalid/version",
                                new QueueHandler(response(200, "6.12.5\n"))),
                        midReadCancellation),
                RetroRewindVersionCheck.Error.CANCELLED);

        System.out.println("Android Retro Rewind version check passed.");
    }

    private static void expectLatest(String body, String expected) {
        String actual = RetroRewindVersionCheck.parseLatest(
                body.getBytes(StandardCharsets.UTF_8));
        expect(expected == null ? actual == null : expected.equals(actual),
                "unexpected latest version: " + actual);
    }

    private static void expectError(
            RetroRewindVersionCheck.Result result,
            RetroRewindVersionCheck.Error expected) {
        expect(result.error == expected,
                "expected " + expected + " but received " + result.error);
    }

    private static void expect(boolean condition, String message) {
        if (!condition) {
            throw new IllegalStateException(message);
        }
    }

    private static FixtureConnection response(int code, String body) {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        return response(code, bytes, null, null, bytes.length);
    }

    private static FixtureConnection response(
            int code, byte[] body, String location, String encoding, long declaredBytes) {
        return new FixtureConnection(code, body, location, encoding, declaredBytes);
    }

    private static URL fixtureUrl(String value, QueueHandler handler) throws Exception {
        return new URL(null, value, handler);
    }

    private static final class QueueHandler extends URLStreamHandler {
        private final Queue<FixtureConnection> responses = new ArrayDeque<>();
        FixtureConnection opened;
        int opens;

        QueueHandler(FixtureConnection... responses) {
            this.responses.addAll(Arrays.asList(responses));
        }

        @Override
        protected URLConnection openConnection(URL url) throws IOException {
            FixtureConnection response = responses.poll();
            if (response == null) {
                throw new IOException("No fixture response");
            }
            opened = response;
            opens++;
            return response;
        }
    }

    private static final class FixtureConnection extends HttpURLConnection {
        private final int responseCode;
        private final byte[] body;
        private final String location;
        private final String encoding;
        private final long declaredBytes;

        FixtureConnection(
                int responseCode,
                byte[] body,
                String location,
                String encoding,
                long declaredBytes) {
            super(null);
            this.responseCode = responseCode;
            this.body = body;
            this.location = location;
            this.encoding = encoding;
            this.declaredBytes = declaredBytes;
        }

        @Override
        public int getResponseCode() {
            return responseCode;
        }

        @Override
        public String getHeaderField(String name) {
            return "Location".equalsIgnoreCase(name) ? location : null;
        }

        @Override
        public String getContentEncoding() {
            return encoding;
        }

        @Override
        public long getContentLengthLong() {
            return declaredBytes;
        }

        @Override
        public InputStream getInputStream() {
            return new ByteArrayInputStream(body);
        }

        @Override
        public void disconnect() {}

        @Override
        public boolean usingProxy() {
            return false;
        }

        @Override
        public void connect() {}
    }
}
