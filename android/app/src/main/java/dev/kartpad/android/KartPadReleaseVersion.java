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
