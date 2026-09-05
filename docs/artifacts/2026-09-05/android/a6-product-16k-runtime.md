# Android A6 complete product runtime on a 16 KiB kernel

Date: 2026-09-05

Classification: **Pass for sustained non-debuggable product-runtime execution,
rendered output, and universal/device-split update preservation on Android's
16 KiB kernel lane, with the same strengthened gate passing again on 4 KiB.**
Physical hardware, vendor Vulkan drivers, hands-on performance/audio/haptics,
release-key signing, and Play service delivery remain open.

## Risk closed

The repository previously proved source fixtures on the Android 15 / 16 KiB
AVD and 16 KiB ELF/package alignment for the complete product, but it did not
prove that the complete translated game runtime from the versioned release AAB
actually survived and rendered on a 16,384-byte kernel page size.

## Private fixture boundary

The persistent 4 KiB Pixel Tablet contained the approved app-private game test
fixture. A permission-restricted ignored transfer included only `GameData`,
managed `NAND`, public runtime resources, and `Config.toml`; it excluded saves,
logs, shared preferences, and unrelated application state. The installed known
version 5 debug APK was retained separately for recovery.

The 2,697,630,208-byte tar container was not used as equality evidence because
directory metadata changes during extraction. Instead, every regular file was
hashed privately on each side, normalized by relative path, sorted, and reduced
to one non-disclosing aggregate. The source archive and destination aggregates
matched exactly. Neither component hashes, paths beyond the public structure,
nor content were printed or recorded.

## Disposable target

- AVD: one newly created disposable Pixel 7, separate from every persistent AVD.
- Image: pinned Android 15 / API 35 `google_apis_ps16k` ARM64.
- Kernel page size: exactly 16,384 bytes.
- Available `/data` capacity before staging: 7,394,316 KiB.
- Runtime package: exact clean `0.4.0-android-preview.1` version code 6 AAB and
  derived APK SHA-256 values already recorded by A6.

The first preservation attempt correctly noticed that the fresh target had no
shared-preference file before KartPad had ever opened; selector startup created
default preferences, changing `absent` to initialized. The guarded runner now
opens and validates the debug selector before capturing its baseline. If a
future mismatch occurs, it reports only changed category names, never private
hashes or content.

## Strengthened runtime acceptance

`scripts/test-android-bundle-derived-apk-emulator.sh` now requires each
non-debuggable universal and device-split form to:

- execute `SDL_main` from installed ARM64 `libmain.so`;
- retain the same process for a configurable 15-second minimum interval;
- initialize SDL's surface and low-latency audio path;
- expose KartPad's accessible Menu control;
- contain no fatal Java/native/CheckJNI signature;
- reach a diverse rendered landscape frame within a bounded retry window; and
- preserve the existing private durable-state aggregate across restore.

The private raw screenshot exists only in the runner's guarded temporary
directory. `scripts/check-android-runtime-frame.py` samples its central region
and emits only viewport/sample/color-bin/luma/nonblack metrics. It rejects
solid, low-diversity, malformed, and portrait frames. A fixed single sample at
15 seconds was rejected because the slow lavapipe lane could still be loading;
the accepted gate retains the diversity threshold and retries for a bounded
minute instead of weakening it.

## Accepted results

The complete strengthened output passed first on the 16 KiB AVD:

```text
page_size=16384
release_non_debuggable=yes
universal_selector_visible=yes
universal_runtime_stable=yes
universal_frame_diverse=yes
device_splits=4
split_signer_consistent=yes
split_native_bytes_exact=yes
split_selector_visible=yes
split_runtime_stable=yes
split_frame_diverse=yes
debug_apk_restored=yes
durable_state_preserved=yes
```

After cleanup, the persistent API 36 Pixel Tablet passed the identical gate at
`page_size=4096`, ruling out a regression from the stronger checks. Both used:

```text
aab_sha256=eaf16573290b5e27c161e47ede4641944545d7e8deb07c20671c185df7996110
derived_apk_sha256=24e977d497d5c587eb79771d09e3176932633fe0671f6e5444ddca335bc8bd92
version_code=6
```

## Cleanup

The 16 KiB emulator was stopped, its exact temporary AVD was deleted, and the
restricted 2.7 GB transfer, recovery APK copy, device spec, split APKs, private
frames, and emulator log were deleted. Those copies are not recoverable, while
the original approved test fixture remains in the persistent Pixel Tablet AVD.
That tablet was restarted and ends on debug version 5's visible two-game
selector. No game data, save, screenshot, APK/AAB, signing material, identifier,
or private artifact was committed, uploaded, hosted, or published.

The 106-test Python suite with one intentional skip, runtime-frame and
bundle-runner contracts, strict AAB/preview-APK audits, pinned-source/input
verification, repository safety, Python/shell syntax, shell lint, and whitespace
checks pass.
