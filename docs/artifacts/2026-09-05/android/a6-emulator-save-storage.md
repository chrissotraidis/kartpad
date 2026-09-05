# Android A6 emulator save-storage recovery

Date: 2026-09-05

Classification: **Pass for the Android save validation, export-read,
staged-restore, atomic activation, and prior-save backup implementation on an
ARM64 emulator.** The fixture is synthetic and isolated; this is not a real
retail save, Android document-picker, or physical-device acceptance result.

## Method

A debug-only activity created two deterministic synthetic `rksys.dat` images
with the required 2,883,584-byte size, `RKSD0006` magic, and valid core CRC.
It operated only below a dedicated directory in the app cache and removed that
directory afterward. It exercised the production `KartPadSaveStorage` API to:

1. read and validate the active save, matching the bytes an export would use;
2. validate and atomically stage a replacement;
3. apply the pending replacement before runtime startup semantics;
4. retain the prior active save exactly once in `SaveBackups`;
5. remove the finalized pending file; and
6. reject a checksum-corrupt replacement.

The emulator runner never clears app storage, verifies the approved
app-private `main.dol`, and restores the production selector on every exit.

## Result

The visible API 36 ARM64 Pixel Tablet emitted:

```text
A6 save storage passed export=validated restore=staged active=replaced backup=preserved corrupt=rejected
```

The exact version-code 5 product fixture APK SHA-256 is
`67bc86e5c0e1ad5ea7fa9c93744a78279e046caba6a7336736fcd6d2e68cfd04`.
It passed the strict Android package/privacy audit and remained installed with
`.KartPadLaunchActivity` visibly resumed.

The Android `ACTION_CREATE_DOCUMENT`/`ACTION_OPEN_DOCUMENT` UI round trip,
actual retail-save export/restore, failure during active-file replacement, and
physical hardware remain open. No APK/AAB, save, game content, or private
artifact was published.
