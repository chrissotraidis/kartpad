# Android A0 source-only fixture

## Classification

**Pass for A0 on the authorized second Apple Silicon host.** A clean
`origin/main` checkout at
`8432a7f32f34b286653cde34f8977570756816b8` gained an explicit pinned
bootstrap, read-only validator, minimal SDLActivity shell, transparent
KartPad-owned overlay, ARM64 SDL/JNI/Dawn-Vulkan fixture, package audit, and
cold-boot runners. No private game input, generated translated source, save,
credential, or signing material was used.

This is build and ARM64 emulator execution evidence only. The fixture discovers
one Dawn Vulkan adapter; it does not clear, read back, or present a frame.
Surface recreation, rotation, background/foreground behavior, guest memory,
fibers, gameplay, audio, touch feel, physical devices, performance, signing,
distribution, and release readiness remain unproven.

## Reproducible commands

```sh
./scripts/bootstrap-android-host.sh
./scripts/check-android-host.sh
./scripts/run-android-fixture.sh KartPad_API_36_ARM64
./scripts/run-android-fixture.sh KartPad_API_35_PS16K_ARM64
```

The first command is the only installation step. The validator and ordinary
build/run commands do not install tools. Each run verifies the host and pinned
dependencies, builds and audits the local debug APK, cold boots exactly one
disposable AVD without snapshots, installs and launches the APK, checks the ABI
and runtime page size, waits for the native pass marker, and shuts the AVD down.

## Baseline and locks

- Host: macOS 26.6.2, Apple Silicon ARM64.
- JDK: Eclipse Temurin `17.0.20.1+1`, hash- and size-pinned by the bootstrap.
- Gradle wrapper: 8.13; Android Gradle Plugin: 8.13.2; Kotlin plugin: 2.2.21.
- Android command-line tools revision: 15641748.
- Compile/target/minimum SDK: 36 / 36 / 28; Build Tools: 36.0.0.
- NDK: 29.0.14206865; SDK CMake: 3.31.6; emulator: 37.1.11.
- SDL3 Android 3.4.4 archive SHA-256:
  `da67b5a43442e449511399c65aa86b724419f92850cf36a2a8c7de72eb992bc0`.
- Extracted SDL3 AAR SHA-256:
  `8652e2b16a7644fb6a755f9a12590f87ae1932f46755485f96c5bd5a4555ce7e`.
- Dawn Android archive SHA-256:
  `27d910dee1201fd1e5b6ac567f0ba2306ebf2135e9f40b6929976c365d38b09b`.
- Sanitized `DawnTargets.cmake` SHA-256:
  `950622eccd03a73154849a5f682347b1f69b5cb5847cc00857eb12459fee4591`.
- Dependency-lock SHA-256:
  `19c98a240293d3c0115ddd48d7aa4f5ae028c5904a94a4c3a378e5b9f9479ee6`.

The Dawn preparation replaces only the pinned package's Linux-CI absolute
`liblog.so` path with Android's logical `log` library, rejects any remaining
CI SDK prefix, and verifies the sanitized file digest before configuration.

## Results

| Lane | API | ABI | Runtime page size | Emulator renderer | Result |
| --- | ---: | --- | ---: | --- | --- |
| `KartPad_API_36_ARM64` | 36 | `arm64-v8a` | 4,096 | gfxstream with host lavapipe; guest Vulkan `ranchu` | Pass, one Dawn Vulkan adapter |
| `KartPad_API_35_PS16K_ARM64` | 35 | `arm64-v8a` | 16,384 | gfxstream with host lavapipe; guest Vulkan `ranchu` | Pass, one Dawn Vulkan adapter |

An initial 16 KiB automation attempt created the SDL activity but did not
observe the native marker inside a 30-second poll. An unchanged clean cold-boot
retry passed. The runner now uses a 60-second marker deadline and prints wider
SDL/native crash diagnostics on failure; this timing observation is not
silently relabeled as a native defect or ignored.

The audited local debug APK is 19,884,099 bytes with SHA-256
`c28461e09f78ba2dc05ab70d137d1918d2e559c9ec2864ae645d26f3697e22ee`.
It contains only `arm64-v8a` `libmain.so`, `libSDL3.so`, and
`libc++_shared.so`; all native `LOAD` segments and ZIP storage pass the 16 KiB
checks. The audit also confirms API/package metadata, expected ELF
dependencies, RELRO, a non-executable stack, and absence of forbidden private
extensions, local user paths, game-data names, and private-key markers. The
generic local Android debug certificate digest is
`61dfb51411efe50b2e7fb8d280fcfbba766792c275d1024013940760caa3afaf`.

No APK or AAB was copied to a release directory, hosted, or published.

Repository safety and the byte-identical pinned SunPad snapshot checks pass.
The broader `scripts/verify-sources.sh` validated all patch hunks and the first
three reference checkouts, then stopped because this machine's ignored, clean
`rr-pulsar` checkout is already at a newer HEAD than the lock. The exact locked
commit/tree remains present and push-disabled, and the checkout was not
changed. This machine-local reference state is unrelated to the source-only A0
graph; SDL3 and Dawn are independently hash-verified before every build.

## Next gate

Begin A1 with a deterministic Vulkan clear/readback/present fixture and SDL
surface create/destroy/recreate coverage. Guest-memory and ELF AArch64
scheduler/register fixtures must then pass on both page-size lanes before any
private full-game link begins.
