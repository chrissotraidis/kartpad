# KartPad Android architecture and acceptance

Android is a supported community platform, with an ARM64 Vulkan app for
Original Mario Kart Wii and Retro Rewind. Start with [installation](INSTALL_ANDROID.md)
or the [source-build guide](../android/README.md). [STATUS.md](STATUS.md)
distinguishes the community release, public testing previews and local candidates.

The original [Android bring-up plan](archive/android-bringup-plan.md) retains
milestone observations and design decisions. Its projected schedule, proposed
file layout and pre-release restrictions are historical.

## Runtime and shell

```text
KartPadLaunchActivity — validated Original / Retro Rewind chooser
  ├─ game-data import and Retro Rewind installer
  └─ KartPadActivity : SDLActivity
       ├─ SDL surface → Aurora / Dawn → Vulkan
       ├─ KartPadOverlayView — controls and menus
       └─ JNI → libmain.so
                  ├─ ahead-of-time Original / Retro Rewind profiles
                  ├─ WiiCompiled runtime and HLE
                  ├─ guest memory and ARM64 fibers
                  ├─ SDL audio and controllers
                  └─ Android storage, TLS and sockets
```

The app owns the Kotlin UI, Storage Access Framework pickers, lifecycle,
sensors, haptics and installation work. Shared C/C++ runtime behavior stays in
`runtime/` and reproducible patches. The private translated graph is built into
the app; it is not downloaded as executable code at runtime.

The native game and the public source-only fixture are separate build modes.
A fixture's Vulkan frame, memory or scheduler check does not establish gameplay.
Generated game source and owned game data stay in ignored private directories.

## Product contracts

- **Profiles:** Original and Retro Rewind share one app with explicit profile
  selection. Release inputs come from
  [the pinned profile](../builder/profiles/mkwii-rmcp01-rev0.json). A new
  `Code.pul` requires matching translation and a new native package; follow
  [upstream updates](UPSTREAM_UPDATES.md).
- **Storage:** validated imports and the Retro installation use app-private
  staging, checked content and recoverable activation. Saves remain separate
  from imported game data. Use [profile-aware transfer](SUPPORT.md#android-save-transfer);
  never treat a raw save as a full NAND, Mii or identity migration.
- **Controls:** touch, motion and SDL controllers feed the Classic-controller
  bridge. Lifecycle changes and modal UI must clear held input. Preserve
  user-created layouts and stable controller assignments.
- **Rendering:** Vulkan surface recreation, cutouts, system bars and rotation
  require runtime checks. API/page-size compatibility is distinct from physical
  GPU-driver acceptance. [External output](EXTERNAL-DISPLAYS.md) remains open.
- **Networking:** Android DNS, sockets and TLS have local fixtures. Public
  Retro WFC, reconnect and network transitions need separate physical tests;
  see [online evidence](ONLINE.md).
- **Diagnostics:** reports are bounded and user-exported. Review excerpts
  before sharing; do not commit raw logs, game assets, saves or identifiers.

## Acceptance matrix

| Area | Existing evidence | Remaining coverage |
| --- | --- | --- |
| Toolchain / packaging | ARM64 builds, source-only checks, APK/AAB audits, 4 KiB and 16 KiB emulator lanes | Exact artifact and source must be checked for every release |
| Original / Retro gameplay | Pixel Original/Kishi acceptance; owner-reported Retro WFC live racing | New preview acceptance, broader hardware, complete online results/reconnect |
| Input and layout | Emulator menu, touch, lifecycle and accessibility fixtures; Pixel touch/Kishi observations | More controllers, rumble, motion, OEM and foldable behavior |
| Data and saves | Import/install fault fixtures, in-place state comparisons, profile-aware transfer checks | Real-save/rating migration acceptance; Miis and console identity remain separate |
| Performance | Physical Pixel timing and thermal observations | Sustained frame pacing and matched cold/warm races; no general 60 FPS claim |
| Graphics / lifecycle | Surface and API/page-size fixtures | Reported corruption, stalls, cup crashes and external displays |

The [maintenance board](MAINTENANCE-BOARD.md) and [known issues](KNOWN-ISSUES.md)
identify the current reproduction, owner and next evidence for each report.
For device work use the [physical handoff](ANDROID-PHYSICAL-HANDOFF.md).
For development cadence use the [Android goal loop](ANDROID-GOAL-LOOP.md);
for publication use the [release procedure](RELEASING_ANDROID.md).
