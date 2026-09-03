# KartPad Android source-only fixture

This directory currently contains the non-playable A0 Android shell. It proves
the pinned ARM64 toolchain, SDLActivity/JNI entry, SDL Vulkan loader, Dawn
Vulkan adapter discovery, 4 KiB execution, and 16 KiB execution without game
data or generated translated code. It does not prove presentation, gameplay,
physical-device support, or release readiness.

On an Apple Silicon Mac, explicitly install the pinned public toolchain and
AVDs, then verify it:

```sh
./scripts/bootstrap-android-host.sh
./scripts/check-android-host.sh
```

The bootstrap may download several gigabytes. It never accepts licenses or
other legal terms; if the SDK reports an unaccepted term, complete that human
step separately and rerun it. It does not modify shell profiles or unrelated
toolchains.

Build, audit, install, launch, and exercise the API 36 / 4 KiB fixture with one
command:

```sh
./scripts/run-android-fixture.sh KartPad_API_36_ARM64
```

Repeat the same cold-boot lane on the pinned Android 15 / 16 KiB image:

```sh
./scripts/run-android-fixture.sh KartPad_API_35_PS16K_ARM64
```

The runner refuses to start when another Android device or emulator is
connected, wipes only the named disposable KartPad AVD, stops it on exit, and
keeps raw emulator output under the ignored `.android-bootstrap/` directory.
The produced debug APK remains a local audit fixture and must not be published.
