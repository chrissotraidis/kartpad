# Android A6 emulator forward-version upgrade preservation

Date: 2026-09-05

Classification: **Pass for a real emulator version-code upgrade with populated
KartPad preferences and app-private durable state preserved.** This is not
physical-device, signed-release, retail-save, or installed-Retro acceptance.

## Method

The product builder now accepts a positive
`KARTPAD_ANDROID_VERSION_CODE` override for a local migration fixture while
retaining version code 1 by default. The update runner uses `aapt2` to require
the exact `dev.kartpad.android` package on both inputs, verifies the installed
version after each `adb install -r`, and can require the after version to be
strictly greater than the before version.

The visible API 36 ARM64 Pixel Tablet first upgraded version code 1 to 2. A
second pass toggled **Show FPS Counter** off through the actual KartPad product
menu, producing a real `kartpad_touch_controls` preference, then upgraded
version code 2 to 3 without clearing package data.

## Results

```text
Android emulator update-in-place preservation passed: before_apk_sha256=aa227e2b2232c2d36d86044f44a26caa310325f42ca9774216a1a62dde94df89 after_apk_sha256=9dc456d7841484ed4b78f1e49002b4d39b611b570bb62e18a0a25edf9d9e6106 before_version_code=1 after_version_code=2 durable_state_preserved=yes game_data_preserved=yes
Android emulator update-in-place preservation passed: before_apk_sha256=9dc456d7841484ed4b78f1e49002b4d39b611b570bb62e18a0a25edf9d9e6106 after_apk_sha256=d0e7ca2004bf9c0a43cec7a29503a29c0d87ea63086cd70907b8f8e9af541f7f before_version_code=2 after_version_code=3 durable_state_preserved=yes game_data_preserved=yes
Android emulator update-in-place preservation passed: before_apk_sha256=d0e7ca2004bf9c0a43cec7a29503a29c0d87ea63086cd70907b8f8e9af541f7f after_apk_sha256=4efee32c73ba0f5832733d4059316d9c4389c7358f2ff71f8f15dea0e2118ed7 before_version_code=3 after_version_code=4 durable_state_preserved=yes game_data_preserved=yes
```

After version 3 installation, the semantic preference remained:

```text
<boolean name="show_fps" value="false" />
```

The final 3-to-4 pass exercised the hardened package/installed-version checks.
The exact version 4 fixture at SHA-256
`4efee32c73ba0f5832733d4059316d9c4389c7358f2ff71f8f15dea0e2118ed7`
passed the strict Android package/privacy audit. The runner restored
`.KartPadLaunchActivity`, which was the top resumed activity after the test.

The profile still had no retail `rksys.dat` or complete installed Retro Rewind
tree. Those populated-state migrations, physical hardware, release signing,
and release authorization remain open. No APK/AAB or private artifact was
published.
