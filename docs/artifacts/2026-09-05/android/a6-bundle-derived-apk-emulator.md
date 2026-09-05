# Android A6 bundle-derived release APK emulator execution

Date: 2026-09-05

Classification: **Pass for local execution of a non-debuggable universal APK
derived from the exact reproducible unsigned release AAB.** Release-candidate
signing, Play delivery/device splits, physical-device acceptance, and
publication remain open.

## Falsifiable subgoal

Use pinned official bundletool to produce the kind of installable APK that an
app store derives from KartPad's unsigned release bundle, audit it independently,
install it over the populated emulator package without clearing data, enter
Original mode through the production selector, prove the packaged ARM64 native
entry point executes, then restore the prior debug build and prove durable state
was unchanged.

## Guarded runner

`scripts/test-android-bundle-derived-apk-emulator.sh`:

- requires exactly one ready Android emulator and the audited AAB;
- pulls the installed debug APK to an exact temporary recovery directory before
  replacing anything;
- compares a private aggregate of configuration, approved game entry point,
  managed NAND, saves, preferences, and Retro version state without printing
  component hashes or content;
- locally signs bundletool's universal test APK with the standard developer
  debug keystore, never copies that key, and does not designate the result as a
  candidate;
- verifies exact package/version identity and that the derived APK is not
  debuggable;
- audits permissions, ABI, libraries, exports, 16 KiB ELF alignment, public
  assets, private-data extensions, paths, and key-marker cardinality before
  installation;
- reaches gameplay only by tapping the enabled Original card in the exported
  production selector; and
- restores the pulled debug APK and visible selector on success or failure.

The APK audit now recognizes bundletool's deterministic materialization of the
two AGP baseline-profile metadata entries as
`assets/dexopt/baseline.prof` and `assets/dexopt/baseline.profm`. If either is
present, the exact pair is required; no other asset was added to the allowlist.

## Failures found before acceptance

The first run correctly stopped before installation because the direct-APK
audit had not modeled those two bundletool-generated baseline-profile paths.
Inspection tied them exactly to the AAB's two pinned
`BUNDLE-METADATA/com.android.tools.build.profiles` entries, after which the
strict pair rule was added.

The next attempt correctly exposed that `KartPadActivity` is non-exported in a
release package, so ADB cannot launch it directly. The runner now uses the
exported launcher and production Original card. A further test race was fixed
by waiting until asynchronous game-data validation actually enables the card,
not merely until it is rendered.

The Java `KartPadActivity` info marker is suppressed in the release package,
but SDL's native loader supplied the stronger accepted signal:

```text
Running main function SDL_main from library .../lib/arm64/libmain.so
```

## Accepted result

```text
Android bundle-derived APK emulator test passed:
aab_sha256=f1c107a7b2cf853f77ef245164821fa46e3502a83be8a3881d794edca7cf9e3e
derived_apk_sha256=ebfcbd0c8fc1471451e72b226480b3792c0a217938b482b705790311e143ac2e
version_code=5
release_non_debuggable=yes
selector_visible=yes
sdl_main_executed=yes
debug_apk_restored=yes
durable_state_preserved=yes
```

The derived APK remained temporary and was removed after the run. No APK, AAB,
save, game data, key, credential, device identifier, or private capture was
committed, uploaded, hosted, or published. The emulator ends on the restored
production two-game selector.

The focused runner contract, 103-test Python suite with one intentional skip,
strict AAB audit, pinned-source/input verification, repository-safety audit,
shell syntax/lint, and whitespace checks pass.
