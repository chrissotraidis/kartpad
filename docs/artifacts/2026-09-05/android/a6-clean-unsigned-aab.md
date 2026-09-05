# Android A6 clean unsigned release AAB

Date: 2026-09-05

Classification: **Pass for deterministic, unsigned, path-clean ARM64 Android
App Bundle production and strict local audit.** Signing, store acceptance,
physical-device testing of APKs derived from this bundle, and publication
authorization remain open.

## Failure found and corrected

The first unsigned debug intermediary AAB was byte-reproducible, but strict
string inspection found absolute local Gradle-cache resource paths in
`base/resources.pb`. A clean rebuild with general source-set path mapping did
not change those bytes, proving that cached output was not the explanation.
That debug bundle was rejected as a candidate.

KartPad now builds the proper unsigned `bundleRelease` output and enables the
Android Gradle Plugin's release resource-source exclusion. The rebuilt release
`resources.pb` and the complete AAB contain no `/Users/` path. The debug APK
lane remains unchanged for emulator execution.

## Locked validation tool

The official bundletool all-in-one JAR is now pinned in
`dependencies.lock.json` and hash-verified by Android dependency preparation:

```text
version=1.18.1
bytes=32505571
sha256=675786493983787ffa11550bdb7c0715679a44e1643f3ff980a529e9c822595c
```

## Reproducibility and audit

Two independent scoped Android app cleans followed by product
`bundleRelease` builds produced byte-identical unsigned AABs:

```text
clean_to_clean_aab_byte_match=yes
aab_sha256=f1c107a7b2cf853f77ef245164821fa46e3502a83be8a3881d794edca7cf9e3e
```

`scripts/audit-android-bundle.sh` verifies:

- bundletool structural validation;
- package ID, compile/minimum/target SDK, and exact permission allowlist;
- absence of top-level JAR signatures;
- the exact ARM64-only native library and public runtime-asset sets;
- no forbidden private-data/signing extensions;
- 16 KiB ELF load-segment alignment, RELRO, non-executable stack, allowed
  dependencies, and required JNI/SDL exports;
- no absolute developer path or game-image filename; and
- exact known parser delimiter cardinality across libraries and native symbol
  metadata, rejecting any unexpected private-key marker.

The second clean artifact emitted:

```text
Android unsigned AAB audit passed.
aab_sha256=f1c107a7b2cf853f77ef245164821fa46e3502a83be8a3881d794edca7cf9e3e
```

The local bundle was not signed, uploaded, hosted, or published. No APK/AAB,
game data, save, translated source, credential, signing material, or private
artifact entered Git.
