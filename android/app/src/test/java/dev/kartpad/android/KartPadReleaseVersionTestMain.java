package dev.kartpad.android;

public final class KartPadReleaseVersionTestMain {
    private KartPadReleaseVersionTestMain() {}

    public static void main(String[] args) {
        expect(KartPadReleaseVersion.isNewer("v0.7.4", "0.7.3"), "patch update");
        expect(KartPadReleaseVersion.isNewer("v0.8.0", "0.7.9"), "minor update");
        expect(KartPadReleaseVersion.isNewer("v1.0", "0.9.9"), "major update");
        expect(KartPadReleaseVersion.isNewer("v0.7.10", "0.7.9"), "numeric, not text, order");
        expect(KartPadReleaseVersion.isNewer("0.7.3.1", "0.7.3"), "fourth part");
        expect(!KartPadReleaseVersion.isNewer("v0.7.3", "0.7.3"), "same version");
        expect(!KartPadReleaseVersion.isNewer("v0.7.2", "0.7.3"), "older release");
        expect(!KartPadReleaseVersion.isNewer("v0.7.4-rc1", "0.7.3"), "prerelease tag");
        expect(!KartPadReleaseVersion.isNewer("v0.7.4", "0.7.3-dev"), "unparseable install");
        expect(!KartPadReleaseVersion.isNewer("latest", "0.7.3"), "not a version");
        expect(!KartPadReleaseVersion.isNewer(null, "0.7.3"), "missing tag");
        expect(!KartPadReleaseVersion.isNewer("v0..4", "0.7.3"), "empty part");
        expect(!KartPadReleaseVersion.isNewer("v9999999.0", "0.7.3"), "oversized part");
        expect("0.7.4".equals(KartPadReleaseVersion.normalize(" v0.7.4 ")), "normalize");
        expect(KartPadReleaseVersion.normalize("v0.7.4-rc1") == null, "normalize prerelease");
        expect("KartPad-v0.7.4-android.apk".equals(KartPadReleaseVersion.apkName("0.7.4")), "apk name");
        expect(KartPadReleaseVersion.isReleasePage(
                "https://github.com/chrissotraidis/kartpad/releases/tag/v0.7.4"), "release page");
        expect(!KartPadReleaseVersion.isReleasePage(
                "https://github.com/someone/kartpad/releases/tag/v0.7.4"), "foreign page");
        expect(KartPadReleaseVersion.isReleaseDownload(
                "https://github.com/chrissotraidis/kartpad/releases/download/v0.7.4/KartPad-v0.7.4-android.apk"),
                "release download");
        expect(!KartPadReleaseVersion.isReleaseDownload(
                "http://github.com/chrissotraidis/kartpad/releases/download/v0.7.4/x.apk"), "plain http");
        expect(!KartPadReleaseVersion.isReleaseDownload(
                "https://github.com/chrissotraidis/kartpad.evil/releases/download/x.apk"), "lookalike host");
        expect(("https://github.com/chrissotraidis/kartpad/releases/download/v0.7.14/SHA256SUMS")
                .equals(KartPadReleaseVersion.sumsUrl("0.7.14")), "sums url");
        String hash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
        String sums = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff  KartPad-v0.7.14-ios.ipa\n"
                + hash.toUpperCase(java.util.Locale.ROOT) + "  KartPad-v0.7.14-android.apk\n";
        expect(hash.equals(KartPadReleaseVersion.sha256For(sums, "KartPad-v0.7.14-android.apk")), "sums lookup");
        expect(hash.equals(KartPadReleaseVersion.sha256For(hash + " *KartPad-v0.7.14-android.apk", "KartPad-v0.7.14-android.apk")),
                "binary-mode entry");
        expect(KartPadReleaseVersion.sha256For(sums, "KartPad-v0.7.15-android.apk") == null, "missing entry");
        expect(KartPadReleaseVersion.sha256For("abc  KartPad-v0.7.14-android.apk", "KartPad-v0.7.14-android.apk") == null,
                "short hash");
        expect(KartPadReleaseVersion.sha256For(hash + "  KartPad-v0.7.14-android.apk.bak", "KartPad-v0.7.14-android.apk") == null,
                "different file");
        System.out.println("KartPad release version rules passed.");
    }

    private static void expect(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
