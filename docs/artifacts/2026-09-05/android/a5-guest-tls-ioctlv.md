# Android A5 translated guest TLS IOCTLV fixture

Date: 2026-09-05

Classification: **Pass for the product runtime's translated guest-memory
IOCTLV path on the ARM64 emulator.** This does not prove that retail Mario Kart
or WFC initiated the exchange, built-in Wii CA/client-certificate behavior,
connection interruption, public WFC, or physical-device networking.

## Baseline

- Branch: `codex/android-a4-touch-settings`
- Parent commit: `d8599c3375f648f31ddbb81296897095c7441331`
- Product APK SHA-256:
  `aa227e2b2232c2d36d86044f44a26caa310325f42ca9774216a1a62dde94df89`
- Target: visible API 36 ARM64 Pixel Tablet emulator
- Private input boundary: pre-existing app-private, user-owned extracted game
  data; `sys/main.dol` was verified only by its approved SHA-256
  `80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05`.

## Change and falsifiable check

The Android runtime preparation now applies
`patches/wiicompiled-android-tls-ioctlv-fixture.patch`. The patch adds an
opt-in, Android-only product fixture that is dormant unless the exact
app-private `KartPadTlsIoctlvFixture/port` configuration exists. It snapshots
and clears a guarded guest scratch window, constructs real guest `IoVector`
arguments, and invokes the production `HandleSslIoctlv` implementation for:

1. `SSL_NEW`;
2. `SETROOTCA`;
3. `CONNECT` through the runtime Wii/native socket table;
4. `DOHANDSHAKE`;
5. `WRITE`;
6. repeated `READ` through the complete response and orderly peer close; and
7. `SHUTDOWN`.

Every exit closes the fixture session/socket and restores the snapshotted guest
memory. A failed opt-in fixture is logged and does not abort normal product
startup.

Android no longer acknowledges `SETBUILTINROOTCA` without configuring a trust
anchor. It reads `rootca.pem` only from the managed app-private Wii NAND,
rejects empty or larger-than-64-KiB input, verifies the fixed Wii root-CA
SHA-256 published by the pinned Dolphin reference with a full-digest comparison,
and only then parses and installs it. Missing or wrong content returns guest
`-1`. Android also returns failure for client-certificate commands it has not
implemented instead of falsely reporting success. The clean emulator has no
user-owned Wii root certificate, so this run proves the missing-file failure
path; valid built-in root loading and mutual TLS remain unaccepted.

`scripts/test-android-tls-ioctlv-emulator.sh` reinstalls the existing product
APK with `-r`, refuses to proceed unless the private game-data hash matches,
creates one-run CA/server keys in a host temporary directory, and copies only
the public DER CA plus address/port/hostname/expected-result text to app-private
storage. It never clears app data. Its exit trap removes the exact public
fixture directory, destroys the host keys, and returns the emulator to the
production Original/Retro selector.

## Result

The repeatable product run passed both cases:

```text
[net] A5 guest TLS IOCTLV missing built-in root rejection passed result=-1
[net] A5 guest TLS IOCTLV trusted exchange passed response_bytes=4797 peer_close=-6
[net] A5 guest TLS IOCTLV hostname rejection passed result=-9
Android product guest TLS IOCTLV emulator fixture passed: apk_sha256=aa227e2b2232c2d36d86044f44a26caa310325f42ca9774216a1a62dde94df89 private_key_on_device=no game_data_preserved=yes
```

Afterward, the exact fixture directories were absent, the corrected app-private
configuration contained `[paths]` plus relative `dvd_root = "GameData"`, the
game-data hash was unchanged, and `KartPadLaunchActivity` was the resumed
activity. The selector was visibly rendered.

A fresh runtime preparation applied the complete patch stack and reproduced
the exact working `network.h`, `main.cpp`, and `network_ssl.cpp`. The full gate
then passed:

- 96 Python tests with one intentional skip;
- Android `:app:lintDebug` with the pinned product dependency environment;
- strict APK/package/privacy audit;
- repository safety audit;
- shell syntax and ShellCheck; and
- `git diff --check`.

No APK/AAB, certificate key, private game data, or private runtime log was
published or committed.
