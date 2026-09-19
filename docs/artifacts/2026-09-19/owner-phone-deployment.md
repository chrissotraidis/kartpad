# Owner phone deployment — 19 September 2026

The owner authorized installation of the existing stabilization candidates on
the attached iPhone and Android phone. Both updates succeeded in place. This is
deployment and launcher evidence; race stability and performance acceptance
remain open.

| Phone | Previous app | Installed candidate | Observed result |
| --- | --- | --- | --- |
| iPhone 14, iOS 26.6.2 | 0.4.24 / build 49 | 0.4.25 / build 52 | Same bundle and signing team; install and launch succeeded. A physical-device screenshot shows Original and Retro Rewind both ready to play. Process remained alive at the launcher. |
| Pixel 9 Pro XL | 0.4.24-next-test / code 116 | 0.4.25-stabilization.3-prototype / code 125 | Matching signing certificate; package replacement succeeded and retained data. Launcher started in its separate process and logged `retro-installed=true`. Phone was locked, so game launch and rendering were not tested. |

## Candidate provenance

These are the already compiled candidates documented in
[the cross-platform build review](cross-platform-stabilization.md). No native
source changes or alternate diagnostic build were introduced for deployment.
The Android package audit was repeated and passed. Its installed-input SHA-256
is `8dea36d534845f78df9861ec4841c3903c770aef796ee985c19cc26b2e560068`.
Code125 is an optimized, non-debuggable, profileable APK with the local debug
signing certificate; this certificate matched the installed code116 package.

The unsigned iOS build52 app was copied to a private signing directory, signed
with the installed application's development identity/team and matching
entitlements, and checked with `codesign --verify --deep --strict`. Its profile
allows the attached iPhone and expires in July 2027. The installed version was
queried after installation. Original unsigned artifacts and matching symbols
remain preserved.

## State preservation

- Android: retained the installed code116 APK and verified its signer. Before
  replacement, stopped only KartPad and archived 37 durable files (14,187,520
  bytes in the TAR), including both save branches, NAND, identity, config,
  preferences and databases. Package Manager explicitly reported retained data
  during the update. The launcher subsequently recognized the existing pack.
  Code125 is non-debuggable, so direct private-file `run-as` readback is not
  available after installation; Android byte-for-byte post-install save
  verification is **not** claimed.
- iPhone: read installed signing entitlements, stopped KartPad, and used wired
  House Arrest to back up selected Library state. Post-install, before launch,
  all 32 selected files matched the quiesced backup byte for byte, including
  both saves, Mii data, config, identity and preferences. Existing Documents and
  extracted game data were retained in place; this was not a full game-data
  backup. Both existing modes were recognized by the launcher.
- No app uninstall, container reset, pack reimport or data-clear operation was
  performed. The attached iPad was not modified.

Raw device inventories, signing metadata, backups, readback manifests and
screenshots are private under `private/device-validation-20260919/` in the
stabilization worktree. Command/audit logs are under
`work/device-validation-20260919/`. They must not be included in public source
or release artifacts.

## iPhone discovery recovery

The initial CoreDevice inventory omitted the connected iPhone while the wired
libimobiledevice query could identify it. A direct CoreDevice details query by
the confirmed physical device identifier established a paired, wired,
developer-enabled connection. Subsequent normal inventories included the phone,
and app inspection, installation, launch, data transfer and CoreDevice screenshot
capture all succeeded. No reboot, service restart or pairing reset was needed.
This is consistent with delayed/stale discovery; its internal root cause is
not established. The older `idevicescreenshot` service was unavailable, so the
supported CoreDevice screenshot command was used successfully instead.

## Remaining acceptance and engineering work

On each phone, run Original and existing Retro Rewind, verify the expected save,
play a race through completion, return/relaunch, then run a longer warmed race
to assess slowdown. Confirm audio and touch behavior directly. This deployment
does not establish improved frame rates or solve device-specific reports.

Keep the issue-specific gates from the build review: affected Vulkan-loader
devices, PowerVR capability rejection, Adreno geometry, uniform/batch ownership,
and warmed CPU cost remain separate problems. Pixel and iPhone 14 success would
not clear those other hardware families. The next optimization work should use
matched warmed-scene measurements and CPU attribution before choosing a narrow
refactor. Do not distribute additional reporter builds on the basis of this
installation alone.

Candidate code remains on `codex/cross-platform-stabilization-20260919` in the
existing stabilization worktree; the dirty primary checkout is preserved.
This report and a build-review link are reconciled to that primary checkout.


## Subsequent owner result: Android failed

The owner subsequently reported a native crash and slowdowns on code125.
[Exact-build crash and timing evidence](pixel-code125-memory-crash.md) confirms
an out-of-memory abort during background shader compilation. Android stability
acceptance failed; earlier install/launcher success is not gameplay acceptance.
The owner has not yet tested iOS gameplay.
