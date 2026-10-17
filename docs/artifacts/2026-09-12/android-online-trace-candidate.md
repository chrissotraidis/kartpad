# Android online trace candidate — 2026-09-12

## Artifact

- Package: private debug APK, `dev.kartpad.android`
- Version: `0.4.17-android.12-wfctrace124` / version code `78`
- ABI: `arm64-v8a`
- SHA-256: `55cf5030811689cdeaf92965f90ed847b803a3d1962f438f06678f55b1862b92`
- Local path: `/private/tmp/kartpad-wfc-trace-candidate.DWybvX/gradle/outputs/apk/debug/app-debug.apk`
- Signing: local debug signer; APK v2 verification passed
- Publication: not published and not installed on any device or emulator

## Build evidence

- Isolated Gradle output directory; `:app:assembleDebug` passed after the
  native dual-runtime build.
- The native library contains `KartPadNetSession`, `poll_complete`,
  `recv_eagain`, and `event=poll_descriptor` markers.
- The packaged app includes the Retro save-preservation correction recorded in
  [the #169 source artifact](issue169-retro-save-preservation.md); its storage
  fixture passes independently.
- Embedded provenance records source revision
  `ca36e2be73ec7845004b493ed1052b27bf736464` and `source_dirty: true`; this
  candidate is therefore suitable only for private diagnosis, not release.
- The diagnostic remains opt-in through `KARTPAD_ANDROID_WFC_TRACE` and uses
  the existing bounded trace budget.

## Acceptance gate

This artifact has passed packaging and binary-marker checks only. It has not
passed Android device acceptance, online login, matching, race, results,
repeat, reconnect, or #206 endurance. The authorized Pixel owner must install
it through the existing data-preserving handoff, record the Retro music
setting, and capture the VS lobby-to-race/re-entry sequence. Correlate the
`poll_descriptor` records with session, close/error, deadline, and frame-time
events before proposing a runtime fix or any public build.
