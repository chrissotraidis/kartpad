# Android A6 clean APK reproducibility

Date: 2026-09-05

Classification: **Pass for byte-identical repeated clean local debug APK
packaging from the same prepared source and private translated graph.** This is
not a release candidate, physical-device acceptance, signed-package
reproducibility, update-in-place proof, or publication authorization.

## Baseline and method

- Branch: `codex/android-a4-touch-settings`
- Commit: `6e405f3`
- Build: pinned Java/SDK/NDK/CMake, Gradle `:app:clean`, then the documented
  `scripts/build-android-game-app.sh` product build.
- Inputs: the existing ignored user-owned translated graph and prepared
  runtime. No private input was copied into the APK or evidence.

An immediate incremental rebuild initially retained APK SHA-256
`08c016da3ceb7f2dada9880249d94aacce9e7e6351c7f9a4d813dd86d183aec9`.
A scoped Android app clean followed by a rebuild produced a different outer APK
SHA-256:

```text
aa227e2b2232c2d36d86044f44a26caa310325f42ca9774216a1a62dde94df89
```

Comparing the pre-clean and clean APKs found all 149 extracted entries
byte-identical. The difference was archive entry order/alignment and resulting
container size, not native code or resource content. Therefore incremental and
clean output hashes are not interchangeable, and a candidate checksum must
come from the documented clean path.

The Android app output and native object tree were then cleaned a second time.
The independent rebuild took 10 minutes 28 seconds and produced:

```text
clean_rebuild_two=aa227e2b2232c2d36d86044f44a26caa310325f42ca9774216a1a62dde94df89
clean_to_clean_byte_match=yes
```

The first clean APK passed the translated guest TLS IOCTLV product fixture and
strict package/privacy audit before it was retained for comparison. Because the
second clean APK passed byte-for-byte `cmp`, those results apply to the exact
second artifact as well. The emulator retained app-private game data and was
returned to the production selector.

No APK/AAB, private translated source, game data, save, certificate key, or
device identifier was published or committed.
