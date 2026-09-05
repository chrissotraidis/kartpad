# Android A6 versioned local hardware preview

Date: 2026-09-05

Classification: **Pass for honest Android preview metadata, byte-identical
clean unsigned AAB production, a locally retained audited hardware-preview APK,
and emulator forward-upgrade execution.** This is not physical-device
acceptance, release-key signing, Play device-split delivery, or publication.

## Version identity

The Android package no longer exposes the original A0 shell label
`0.0.1-a0`. Its current preview identity is:

```text
versionName=0.4.0-android-preview.1
versionCode=6
```

The name identifies parity with KartPad 0.4.0 while explicitly retaining
preview status. Gradle owns a validated `kartpadVersionName` property, and the
product builder exposes the matching `KARTPAD_ANDROID_VERSION_NAME` override.
Both accept only 1--64 portable alphanumeric, dot, underscore, or hyphen
characters. APK and AAB audits fail closed unless the expected preview name is
present. Version code 6 is deliberately forward from the populated emulator's
installed version 5.

## Clean reproducibility

Two independent scoped `:app:clean` plus release bundle builds produced exact
byte equality:

```text
clean_to_clean_preview_aab_match=yes
aab_sha256=eaf16573290b5e27c161e47ede4641944545d7e8deb07c20671c185df7996110
```

The strict unsigned AAB audit passes the version/package/SDK/permission,
ARM64-only library and public-asset sets, 16 KiB ELF, dependencies/exports,
path/private-data, signature, and key-marker boundaries.

## Upgrade/runtime result

The guarded bundle-derived runner upgraded the visible Pixel Tablet from the
installed debug version 5 to the locally test-signed, non-debuggable version 6
APK. It waited for the production selector's asynchronous validation, showed
both Original and Retro Rewind, entered through the enabled Original card, and
proved SDL executed the installed ARM64 `libmain.so`. The runner then restored
the version 5 debug APK using the explicit local-test downgrade path and proved
the complete private durable-state aggregate unchanged.

```text
derived_apk_sha256=24e977d497d5c587eb79771d09e3176932633fe0671f6e5444ddca335bc8bd92
release_non_debuggable=yes
sdl_main_executed=yes
debug_apk_restored=yes
durable_state_preserved=yes
```

## Retained local preview

The exact 90,477,735-byte tested APK is retained outside Git at:

```text
.android-bootstrap/hardware-preview/KartPad-0.4.0-android-preview.1-v6-arm64.apk
```

It is an ARM64/API-28+ universal APK signed only with the local standard Android
debug identity for hands-on testing. It contains no game data or save. It must
not be uploaded or treated as a public/release-key candidate. A later package
signed by a true release key cannot update this debug-signed preview in place;
testers should use KartPad's save export before changing signing identities.

No package, signing material, private translated source, game data, save,
credential, device identifier, or capture was committed, hosted, uploaded, or
published.

The 103-test Python suite with one intentional skip, focused metadata/runner
contracts, strict AAB and retained-APK audits, pinned-source/input verification,
repository safety, shell syntax/lint, and whitespace checks pass.
