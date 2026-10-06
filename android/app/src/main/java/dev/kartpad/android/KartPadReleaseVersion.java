package dev.kartpad.android;

/** Pure rules for the update notice: version order and trusted release URLs. */
final class KartPadReleaseVersion {
    static final String RELEASES = "https://github.com/chrissotraidis/kartpad/releases/";
    private static final int MAXIMUM_PARTS = 4;

    private KartPadReleaseVersion() {}

    /** True when release {@code candidate} (e.g. "v0.7.4") is newer than {@code current}. */
    static boolean isNewer(String candidate, String current) {
        int[] next = parse(candidate);
        int[] installed = parse(current);
        if (next == null || installed == null) {
            return false;
        }
        for (int i = 0; i < MAXIMUM_PARTS; i++) {
            if (next[i] != installed[i]) {
                return next[i] > installed[i];
            }
        }
        return false;
    }

    /** "v0.7.4" becomes "0.7.4"; null for anything that is not a plain release version. */
    static String normalize(String tag) {
        return parse(tag) == null ? null : strip(tag);
    }

    static String apkName(String version) {
        return "KartPad-v" + version + "-android.apk";
    }

    static boolean isReleasePage(String url) {
        return url != null && url.startsWith(RELEASES + "tag/");
    }

    static boolean isReleaseDownload(String url) {
        return url != null && url.startsWith(RELEASES + "download/");
    }

    /** The release's checksum list, published next to the APK. */
    static String sumsUrl(String version) {
        return RELEASES + "download/v" + version + "/SHA256SUMS";
    }

    /** The lowercase SHA-256 a SHA256SUMS file lists for {@code fileName}, or null. */
    static String sha256For(String sums, String fileName) {
        if (sums == null || fileName == null) {
            return null;
        }
        for (String line : sums.split("\n", -1)) {
            String trimmed = line.trim();
            if (trimmed.length() < 66 || trimmed.charAt(64) != ' ') {
                continue;
            }
            String hash = trimmed.substring(0, 64).toLowerCase(java.util.Locale.ROOT);
            String name = trimmed.substring(64).trim();
            if (name.startsWith("*")) {
                name = name.substring(1);
            }
            if (name.equals(fileName) && hash.matches("[0-9a-f]{64}")) {
                return hash;
            }
        }
        return null;
    }

    private static String strip(String value) {
        String trimmed = value.trim();
        return trimmed.startsWith("v") ? trimmed.substring(1) : trimmed;
    }

    private static int[] parse(String value) {
        if (value == null) {
            return null;
        }
        String[] parts = strip(value).split("\\.", -1);
        if (parts.length < 2 || parts.length > MAXIMUM_PARTS) {
            return null;
        }
        int[] numbers = new int[MAXIMUM_PARTS];
        for (int i = 0; i < parts.length; i++) {
            String part = parts[i];
            if (part.isEmpty() || part.length() > 6) {
                return null;
            }
            for (int c = 0; c < part.length(); c++) {
                if (part.charAt(c) < '0' || part.charAt(c) > '9') {
                    return null;
                }
            }
            numbers[i] = Integer.parseInt(part);
        }
        return numbers;
    }
}
