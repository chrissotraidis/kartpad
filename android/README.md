# KartPad Android source-only fixture

This directory contains the non-playable Android source-only fixture. A0 proves
the pinned ARM64 toolchain, SDLActivity/JNI entry, SDL Vulkan loader, Dawn
Vulkan adapter discovery, 4 KiB execution, and 16 KiB execution. The first A1
slice additionally creates one Dawn device, byte-verifies a deterministic GPU
clear/readback, presents a separate clear through the Android native window,
and repeats presentation after HOME/foreground surface recreation. The next
A1 slice reserves a dynamic sparse 4 GiB guest range, maps two shared views,
and verifies alias visibility and read-only/guard/read-only protection changes
using the runtime page size. The surface fixture now also retains and
reconfigures its Dawn surface across a physical flipped-landscape sensor
transition, then replaces and presents through three consecutive Android
background/foreground surface generations. None of these paths use game data
or generated translated code.

Fibers, gameplay, physical-device support, performance, and release readiness
remain unproven.

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
connected, wipes only the named disposable KartPad AVD, settles it in the
shell's declared landscape orientation, stops it on exit, and keeps raw
emulator output under the ignored `.android-bootstrap/` directory. It drives
HOME/foreground and requires the post-recreation presentation marker. The
produced debug APK remains a local audit fixture and must not be published.
