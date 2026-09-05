# Android A6 emulator update-in-place preservation

Date: 2026-09-05

Classification: **Pass for app-private durable-state preservation across a
same-version emulator APK replacement.** This profile had no retail
`rksys.dat`, touch-preference file, or installed Retro Rewind version, so this
does not prove save migration, customized-layout migration, Retro installation
preservation, version-code upgrade behavior, or physical-device acceptance.

## Method

`scripts/test-android-update-in-place-emulator.sh` requires two APKs with
different byte hashes and exactly one attached Android emulator. It installs
each package with `adb install -r` and never clears package data. After each
install it verifies the approved app-private `sys/main.dol` SHA-256 and computes
a private aggregate digest, without printing individual private hashes or
content, over:

- `Config.toml`;
- `GameData/sys/main.dol`;
- the complete managed NAND tree;
- the saves tree, when present;
- shared preferences, when present; and
- the Retro Rewind version marker, when present.

The runner always restores the production game selector before exiting.

## Result

The visible API 36 ARM64 Pixel Tablet passed:

```text
Android emulator update-in-place preservation passed: before_apk_sha256=08c016da3ceb7f2dada9880249d94aacce9e7e6351c7f9a4d813dd86d183aec9 after_apk_sha256=aa227e2b2232c2d36d86044f44a26caa310325f42ca9774216a1a62dde94df89 durable_state_preserved=yes game_data_preserved=yes
```

Both APKs use the same debug application identity, signing identity, and
version. Their 149 extracted files are byte-identical, while their outer ZIP
ordering/alignment differs. This exercises a real package replacement and
durable-data preservation, but it is not a semantic application-version
migration.

No APK/AAB, user data, private state digest, signing key, or game content was
published.
