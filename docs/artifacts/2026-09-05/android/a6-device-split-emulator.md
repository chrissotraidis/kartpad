# Android A6 device-specific split APK emulator execution

Date: 2026-09-05

Classification: **Pass for local bundletool device targeting, strict split-set
inspection, four-part split installation, and native runtime execution on the
canonical Pixel Tablet emulator.** This is not Play service delivery,
release-key signing, or physical-device acceptance.

## Falsifiable subgoal

Starting from the exact clean Android preview AAB, query the active emulator's
real device specification, produce only the APK splits bundletool selects for
that device, prove the split contents and signer form one coherent install,
replace the already running universal version without clearing package data,
and execute the production selector plus native runtime. Restore the debug
fixture and prove durable data remains unchanged.

## Audited split contract

The guarded `scripts/test-android-bundle-derived-apk-emulator.sh` now requires
the device-targeted APK set to contain exactly:

```text
toc.pb
splits/base-master.apk
splits/base-arm64_v8a.apk
splits/base-en.apk
splits/base-<recognized-density>.apk
```

The accepted Pixel Tablet selected `base-xhdpi.apk`. The runner additionally:

- verifies package, `0.4.0-android-preview.1` name, version code 6, and
  non-debuggable state from the base split;
- verifies every split signature and requires one identical signer-certificate
  digest across all four APKs;
- runs 16 KiB-aware zip alignment checks on each APK;
- byte-compares all four ARM64 native libraries in the ABI split with the exact
  corresponding entries in the already audited AAB;
- scans the complete APK set for developer paths and game-image names;
- requires Package Manager to report exactly the installed base, ARM64,
  English, and density components; and
- enters through the enabled Original card and observes SDL execute installed
  ARM64 `libmain.so` after the split install.

The device specification, split archive, extracted APKs, signer output, and
temporary native comparisons remain under one guarded temporary directory and
are removed after the run. Bundletool and ADB helper output that contains host
or device-internal temporary paths is suppressed; failure output is a bounded
sanitized diagnostic.

## Accepted result

```text
Android bundle-derived APK emulator test passed:
aab_sha256=eaf16573290b5e27c161e47ede4641944545d7e8deb07c20671c185df7996110
derived_apk_sha256=24e977d497d5c587eb79771d09e3176932633fe0671f6e5444ddca335bc8bd92
version_code=6
release_non_debuggable=yes
universal_selector_visible=yes
universal_sdl_main_executed=yes
device_splits=4
split_signer_consistent=yes
split_native_bytes_exact=yes
split_selector_visible=yes
split_sdl_main_executed=yes
debug_apk_restored=yes
durable_state_preserved=yes
```

No package data was cleared. The previously installed debug version 5 and
visible two-game selector were restored. No APK/AAB, split, device spec,
certificate, signing key, game data, save, private artifact, or device
identifier was committed, uploaded, hosted, or published.

The 103-test Python suite with one intentional skip, focused split-runner
contract, strict AAB and retained-preview APK audits, pinned-source/input
verification, repository safety, shell syntax/lint, and whitespace checks pass.
