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
background/foreground surface generations. The final A1 slice runs the shared
cooperative scheduler for two million deterministic operations and a native
ELF AArch64 fiber for one million context switches with callee-saved register
checks. None of these paths use game data or generated translated code.

Gameplay, physical-device support, performance, and release readiness remain
unproven. A1 is complete; A2 is the next gate.

The first A2 build slice can privately prepare and package the complete
29,065-function Original runtime when the ignored translated graph already
exists. This command never copies that graph or game data into Git and does
not publish the resulting APK:

```sh
./scripts/build-android-game-app.sh private/g8-full-translation
./scripts/audit-android-package.sh \
  android/app/build/outputs/apk/debug/app-debug.apk
```

Fixture mode remains the default when the private Gradle properties are not
provided. A full-runtime package is only build/link evidence until separately
staged validated game data boots and completes the A2 gameplay matrix.

In game-runtime mode the APK contains exactly 14 audited public support assets.
`KartPadRuntimeResources` atomically installs them into versioned app-private
storage before SDL loads. The Activity supplies its Context-derived private
files/cache paths to the native runtime, which keeps configuration, logs, NAND,
and writable renderer databases out of both the APK and shared storage. A cold
launch without staged game data must reach the explicit `No DVD root is
configured` boundary; it is not gameplay evidence.

With an already validated ignored RMCP01 DATA directory staged separately in
that private storage, the API 36 emulator now boots and renders the Original
title/demo loop. Six consecutive HOME/foreground surface generations retained
one process and resumed presentation. See
`docs/artifacts/2026-09-03/android/a2-emulator-boot-lifecycle.md` for the exact
evidence and open failures. A2 remains open: the complete race/results,
save/relaunch, real-controller, and physical-device rows are not yet proven.

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
