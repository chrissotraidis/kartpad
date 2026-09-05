# Android A6 emulator save document-picker round trip

Date: 2026-09-05

Classification: **Pass for an end-to-end Android DocumentsUI export/import and
restart-applied restore of an initialized emulator RKSYS save.** Physical
hardware and physical-user acceptance remain open.

## Safety boundary

The runner requires an existing active save and refuses to proceed if a pending
restore, its exact recovery path, or the exact Downloads export path already
exists. It installs with `adb install -r`, never clears app data, verifies the
approved app-private `main.dol`, and creates an app-private recovery copy before
opening UI. On an incomplete run it retains that recovery copy. On success it
removes only its exact recovery, newly identified automatic backup, public
export, and UI-dump paths, then restores the production selector.

No save bytes or private hashes are printed.

## Executed path

The visible API 36 ARM64 Pixel Tablet exercised the production UI and Android
system provider:

1. **KartPad → Game Data & Saves → Manage Saves → Export Save Backup…**;
2. Android `ACTION_CREATE_DOCUMENT` in DocumentsUI, accepting the exact
   `KartPad-RMCP01-rksys.dat` name;
3. byte-for-byte comparison of the public export with the protected active
   save;
4. a fresh runtime process, then **Restore Save Backup…**;
5. Android `ACTION_OPEN_DOCUMENT` selecting the exported save;
6. KartPad validation and pending staging;
7. **Restart Now**, selector return, and a new runtime start applying the
   pending restore before SDL startup; and
8. byte-for-byte comparison of restored active data and KartPad's automatic
   prior-save backup with the protected original.

The repeatable runner emitted:

```text
Android save document-picker round trip passed: export=exact import=validated restart=applied backup=exact cleanup=armed
```

Post-run checks proved the pending file, exact app-private recovery copy,
automatic test backup, public Downloads export, and UI dump were absent; the
active initialized save remained and `.KartPadLaunchActivity` was visibly
resumed. The tested version-code 5 product fixture APK SHA-256 is
`67bc86e5c0e1ad5ea7fa9c93744a78279e046caba6a7336736fcd6d2e68cfd04`.

Physical device/provider variants, user review of the resulting document,
signed release, and publication remain open. No APK/AAB, save, game content,
private hash, or private artifact was published.
