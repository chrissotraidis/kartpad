# KartPad handoff

## Current state

KartPad `v0.4.0` is published as the second stable community release from
`369159153bef0d045edf5cc1cf3b1b444b36a284`. The iPhone/iPad app 0.4.0 build
15 IPA has SHA-256
`af80c2bc6fcabdb4eee84aed05254eccef76d7e6bbf83f2c7f21101168c665c8`;
the experimental tvOS app 0.4.0 build 3 IPA has SHA-256
`9ee2a9b05bff56261d4d4986eca54840e98ade8ae0abd3ac623c1f2393dcf5cc`.
Both exact-main builds and two independent packages per platform pass. Fresh
anonymous downloads match the local bytes, checksums, provenance, and audits.
GitHub marks this non-prerelease as **Latest**. Physical Apple TV acceptance
remains open.

The `codex/iphone-touch-layout-editor` candidate captures the maintainer's
current physical-iPhone control positions as the default for untouched iPhone
installs only. Existing custom layouts and every iPad layout remain unchanged.
The editor lets a user hide or restore individual controls, treats the four
D-pad directions as one control, and returns to Touch Control Settings through
an explicit **Back** action. The D-pad remains present by default because it
drives tricks and wheelies. Source contracts, the pinned SunPad snapshot, a
fresh unsigned device build, app audit, signed in-place installation, launch,
and before/after save and preference checks pass. The maintainer then accepted
Retro Rewind launch, per-control hiding, and the editor's Back path on the
physical iPhone. These results clear the iPhone gate for the stable 0.4.0
release; physical Apple TV acceptance remains open.

KartPad `v0.4.0-preview.2` is published from
`e9fa6058ee09fff0b16481ebe4a78d61cea69c87`. It updates both Apple-platform
artifacts for Retro Rewind 6.12.5, repairs the universal iPhone/iPad three-dot
menu refresh, and adds a daily upstream-version watcher plus deterministic
profile updater. Its separate unsigned iPhone/iPad and tvOS IPAs were each
packaged twice byte-identically, and the freshly downloaded hosted artifacts
match and re-audit. Their SHA-256 values are respectively
`a796cd0e29bfd47d78afc50989a959803f9eff434252a3a455af85308b380fe6`
and `3f8f529a93cc3f1ddfe9e9b71171ba56ead5a49ae3598c449a42f00eed6c5a9a`.
The signed iPhone build 14 was installed in place, launched, and preserved the
pre-install configuration, identity, preferences, NAND, and saves byte-for-
byte. Physical 6.12.5 gameplay and Apple TV remain external acceptance gates.

KartPad `v0.3.0-preview.5` is published from
`8e57ac49c161ff576d6eff198ade2ee9b21f575e`. Its unsigned app 0.3.0 build 12
IPA has SHA-256
`9b7b8c586ddd04b639dda5634e72e88dc91ccefb93762f1afde6e8006d274d14`.
It makes an empty signed-container import scan open the normal Files picker
immediately and removes the native macOS runtime's five-second cursor auto-hide.
Exact-merge macOS and physical-iOS builds passed; both deterministic packages
and the freshly downloaded hosted artifact matched and audited cleanly.

KartPad `v0.3.0-preview.4` is published from
`3e43c002d60378bd4975c4637a8e3a149f2d733e`. Its unsigned app 0.3.0 build 11
IPA has SHA-256
`6bd4a3bd6a8582dd193093dda7471cecee2cafd7450f51ea59454329a1529b9e`.
Two local packages and the freshly downloaded hosted artifact are
byte-identical and pass checksum, ZIP, app, privacy, provenance,
signing-residue, and private-data audits. Remote main and the dereferenced tag
match the audited source commit.

Preview 4 adds experimental cross-platform Mii import/management and
experimental macOS-only direct Wii Remote/Nunchuk pairing. The format, storage,
staging, backup, UI, build, package, entitlement, and cancel-path contracts
pass. Issue #5 has the targeted tester request at
`https://github.com/chrissotraidis/kartpad/issues/5#issuecomment-5502139406` and
remains open for real exported Mii and physical Wii hardware results.

The immediately preceding signed iPad candidate was installed in place and
preserved the complete 5,745-file, 4.8-GB KartPad Application Support/NAND tree
byte-for-byte. Hands-on testing accepted Retro Rewind, ordinary controller
input, the repaired and reorganized three-dot menu, exit/reopen lifecycle,
Original Mario Kart Wii, and the existing license.

KartPad `v0.3.0-preview.3` is published from
`452af2dde3d19508a5e6ced6c03deb0e24b8b509`. The hosted unsigned iPhone/iPad
IPA is app 0.3.0 build 10 and has SHA-256
`e839c115a97867949b16fa1c4a2a3472dce4eb3da6c69fff6f40c3eca2abbdcf`.
The hosted artifact matches the local audited candidate byte-for-byte.

Preview 3 asks Files providers for a local picker copy and scans app-folder
disc extensions before provider package/directory metadata. User files placed
in the KartPad folder are preserved; only temporary picker copies are removed.
The full device build, app audit, deterministic packaging, hosted checksum,
and fresh hosted re-audit pass. Issue #1 remains open for reporter confirmation
on the exact affected iPad and Files provider.

The preview offers Original Mario Kart Wii or optional Retro Rewind 6.12.5.
The preceding 6.12.4 build completed physical iPad pack download, verification,
installation, launch, and a playable single-player match. General physical
execution is accepted on iPad and iPhone. Retro WFC remains unavailable during
external service maintenance; live public online play is not claimed and does
not block offline Retro Rewind support.

## Next executable work

1. Continue Android A2 using `docs/ANDROID-GOAL-LOOP.md`. The complete private
   Original runtime now boots ignored app-private RMCP01 data, restores its
   saved license across cold processes, enters live Luigi Circuit gameplay,
   survives repeated title/demo and live-race surface recreation, and sustains
   a clean retail staff replay. The debug-only app-private RKG bridge works,
   and an Android-only marker can replace only its steering with the debug
   keyboard stick. Those fixed replays diverge, but a content-free native
   trace feedback run using ordinary Android key events completed all three
   N64 Mario Raceway laps and reached retail results. The game declined ghost
   saving. A later controller-only pass navigated the full Time Trial setup and
   entered live N64 Mario Raceway. A controller retained across cold process
   startup exposed deferred SDL polling and short-edge collapse; scheduler-
   fiber handoff plus a one-snapshot press latch now let exact uninstrumented
   250 ms taps advance cold title/intro, Select License, and Main Menu.
   Controller-after-relaunch is therefore green on the emulator. The same
   exact APK subsequently completed all three N64 Mario Raceway laps through
   Android's virtual InputReader/SDL controller path at `04:28.063`, reached
   results, saved the KartPad ghost, retained the changed save hash across a
   force-stop/cold launch with the controller attached, and visibly reloaded
   that result.
   Aurora's discovered
   SDL pads now feed the Android Classic/KPAD path through a deterministic
   mapping contract, and `WPADControlMotor` now reaches that same resolved pad
   through a fail-closed SDL rumble bridge. Surface loss/backgrounding now
   makes that bridge neutral, rejects new rumble starts, and stops active
   rumble; a corrected process retained its PID through four emulator cycles.
   One earlier corrected process ended silently after one cycle and remains an
   unexplained non-reproduced exit. Virtual attached-controller input and
   lifecycle behavior now pass on the emulator; tactile output and all physical
   controller/device behavior remain unaccepted. A
   temporary exact-configuration retail-KPAD RKG replay also diverged by guest
   time 8.580 and was removed; do not repeat it unchanged. Repeat the complete
   race with a real controller and physical Android hardware, verify tactile
   rumble and audible output there, and retain emulator performance as a
   separate non-acceptance observation. Run
   `scripts/check-android-physical-device.sh` before installing or mutating the
   first device; it rejects emulators/unsupported hardware and redacts the ADB
   serial. Its twelve-case contract passes, while the live host currently has no
   ADB target. Use `scripts/capture-android-a2-session.sh start` immediately
   before the run and its `summarize` phase afterward; the tested wrapper keeps
   raw logcat off the host, scopes retrieval to KartPad's UID, and sends it
   directly through the strict sanitizer. Strict mode requires the automated
   controller/audio/lifecycle/crash-free signals in that single capture but
   does not replace listening, tactile, race/save, or performance judgment.
   Evidence is in
   `docs/artifacts/2026-09-03/android/a2-emulator-boot-lifecycle.md` and
   `docs/artifacts/2026-09-03/android/a2-debug-input-replay.md`, plus
   `docs/artifacts/2026-09-03/android/a2-keyboard-steer-diagnostic.md` and
   `docs/artifacts/2026-09-03/android/a2-sdl-controller-bridge.md`, plus
   `docs/artifacts/2026-09-03/android/a2-sdl-controller-rumble.md`, plus
   `docs/artifacts/2026-09-03/android/a2-controller-lifecycle.md`, plus
   `docs/artifacts/2026-09-03/android/a2-state-trace-player-race.md`, plus
   `docs/artifacts/2026-09-03/android/a2-virtual-controller-hotplug.md`, plus
   `docs/artifacts/2026-09-03/android/a2-controller-cold-relaunch.md`, plus
   `docs/artifacts/2026-09-04/android/a2-controller-complete-race-save.md` and
   `docs/artifacts/2026-09-04/android/a2-physical-device-preflight.md`, plus
   `docs/artifacts/2026-09-04/android/a2-runtime-signal-sanitizer.md` and
   `docs/artifacts/2026-09-04/android/a2-uid-scoped-capture.md`.
   A2 remains open. While no device is attached, an independent A3 source
   slice moved ZIP member-path validation into portable C++ already consumed
   by iOS/tvOS. Its host matrix, pinned NDK ARM64 compile, SDK-targeted
   installer compile, and fresh Apple patch preparation pass; a full Apple
   link stopped at an unrelated
   fail-closed cached-Dawn hash mismatch. Continue the remaining shared
   installer rules and thin Android owner only when they are immediately
   consumed and tested. Evidence:
   `docs/artifacts/2026-09-04/android/a3-shared-archive-path.md`.
   A second stacked slice adds a portable stateful archive scan now consumed by
   Apple for symlink/encryption/negative-size rejection, exact-root selection,
   entry and expansion caps, overflow-safe totals, and progress accounting.
   Host, pinned NDK ARM64, Apple SDK, fresh patch preparation, and source
   contracts pass. Evidence:
   `docs/artifacts/2026-09-04/android/a3-shared-archive-scan.md`.
   A third stacked slice rejects duplicate selected component paths during the
   portable scan, before extraction, while retaining the Apple filesystem check
   as defense in depth. Host, NDK, Apple SDK, safety, and contract tests pass.
   Evidence:
   `docs/artifacts/2026-09-04/android/a3-shared-archive-duplicates.md`.
   Android now also has an app-private same-volume staging/atomic-activation/
   rollback owner invoked during game-runtime startup. Its injected second-move
   failure restores the prior install, cold recovery refuses ambiguous or
   symlinked rollback state, and public/private build configurations, lint, and
   the source-only APK audit pass. Only validated staging may use activation;
   archive download/extraction/content validation are still absent. Evidence:
   `docs/artifacts/2026-09-04/android/a3-install-storage-recovery.md`.
   Android's exact release constants are now generated and regression-checked
   against the sole profile. A bounded strict-UTF-8/version and streamed-size/
   SHA-256 validator for `Code.pul` and XML gates atomic activation and rejects
   unsafe or symlinked content; the generated contract also retains the build-
   validated production payload pin. Public/private compile configurations,
   lint, content fault tests, and package audit pass. Evidence:
   `docs/artifacts/2026-09-04/android/a3-content-validation.md`.
   A further stacked slice adds overflow-safe Android free-space accounting and
   probes exact filesystem device IDs to distinguish shared from separate app
   files/cache stores. It retains a 256 MiB reserve and locks the current
   same-store production requirement to 4,327,477,355 bytes. Direct boundary
   tests, public build/release compilation, lint, safety, existing A3 fault
   matrices, and package audit pass. The future download worker does not yet
   invoke it. Evidence:
   `docs/artifacts/2026-09-04/android/a3-space-preflight.md`.
   The next layer adds HTTPS-only bounded redirects/timeouts, exact streamed
   byte/hash verification, cancellation, verified-cache reuse, and atomic
   publication of only a verified archive. Android now requests INTERNET and
   the package audit enforces it as the sole permission. Direct fault tests,
   earlier A3 matrices, public/private compilation, API-28 lint, package audit,
   and safety pass. No worker/UI calls this downloader and the production
   archive was not fetched. Evidence:
   `docs/artifacts/2026-09-04/android/a3-archive-download.md`.
   Android now also has a pinned minizip-ng, two-pass bounded extraction core,
   no-follow directory-relative output, JNI cancellation/progress, exact
   staging cleanup, and a joined validation/atomic-activation pipeline. Host
   faults, full private native linkage, public build/lint/audit, and wiped 4 KiB
   plus 16 KiB AVD JNI execution pass. At that checkpoint, production-size
   install, durable orchestration, and Retro Rewind gameplay remained open.
   Evidence:
   `docs/artifacts/2026-09-04/android/a3-archive-extraction.md`.
   The next stacked slice adds that durable owner: one unique AndroidX
   foreground worker now sequences recovery, capacity preflight, pinned
   download, extraction, validation, activation, and cache cleanup. It persists
   phase/byte progress, updates its data-sync notification, exposes
   cancellation, retries transport loss, and suppresses duplicate enqueue.
   Wiped 4 KiB and 16 KiB AVDs each prove exactly one start after two enqueues.
   A separate API 36 fault run kills the application during active work; the
   same persisted UUID restarts at attempt 1 after relaunch and completes.
   At that checkpoint, partial HTTP resume, production-size
   installation/faults, Retro Rewind gameplay/mode switching, and physical
   acceptance remained open. Evidence:
   `docs/artifacts/2026-09-04/android/a3-install-worker.md`.
   The downloader now retains a stable version-scoped partial and accepts
   append only after an exact HTTPS `206 Content-Range`; a full `200`
   response safely truncates/restarts and final publication still requires the
   complete pinned digest. Host faults cover range negotiation and repeated
   network-loss resume, both AVD page sizes execute prefix append, and the
   process-death worker test now resumes the same UUID from a measured nonzero
   prefix (seven bytes in the final run). The official 1.86 GB server/transfer,
   production fault matrix, gameplay/mode switching, and physical acceptance
   remain open. Evidence:
   `docs/artifacts/2026-09-04/android/a3-resumable-download.md`.
   A debug-only native installer activity now recreates in the same PID while
   work is active, re-enqueues with `KEEP`, and observes the original UUID
   complete after exactly one start. It is absent from release and requires
   privileged `DUMP` permission for ADB launch. This replaces a rejected
   experiment that recreated SDL during game-window startup and therefore
   restarted the native process rather than modeling installer UI lifecycle.
   Evidence:
   `docs/artifacts/2026-09-04/android/a3-worker-activity-recreation.md`.
   The production cancellation facade now has an Android runtime proof: one
   active UUID was cancelled after seven appended bytes, WorkManager reported
   terminal `CANCELLED`, the partial was retained, and no success marker was
   accepted. This closes the worker control/state contract, not the missing
   user-facing observer/cancel screen or official-archive cancellation.
   Evidence:
   `docs/artifacts/2026-09-04/android/a3-worker-cancellation.md`.
   A production-owned, release-present installer/status activity now observes
   the unique chain, displays waiting and determinate phase/byte progress,
   exposes Cancel/Retry, validates installed content off-main before claiming
   ready, and opens from the foreground notification. Android 13+ install
   starts require notification permission, and the foreground notice requests
   immediate display. A wiped API 36 fixture proved that actionable notice and
   its explicit return target, then activated the real Cancel control, observed
   terminal `CANCELLED`, rejected completion, and restored that state after
   force-stop/reopen. Release keeps
   the activity non-exported; debug ADB access is privileged and bounded. The
   missing first-launch dual-mode chooser does not yet route normal startup to
   this screen. Evidence:
   `docs/artifacts/2026-09-04/android/a3-installer-ui.md`.
   The worker now performs a profile-generated, bounded HTTPS version check
   before capacity preflight or archive acquisition. Strict UTF-8/numeric
   parsing, five redirects, 15-second timeouts, a 512 KiB cap, cancellation,
   and stale-profile blocking have direct host fault coverage. The host JVM and
   wiped API 36 Android TLS path each report official `6.12.5`; no archive bytes
   were requested. Normal startup's chooser/installed fallback remains absent.
   Evidence:
   `docs/artifacts/2026-09-04/android/a3-version-freshness.md`.
   The real Android install pipeline now also runs an existing-valid-install
   fault sequence with bounded synthetic content on wiped 4 KiB and 16 KiB
   ARM64 AVDs. It rejects a corrupt archive before extraction, preserves the
   validated active install across an injected activation failure, cleans the
   failed staging tree, atomically replaces the pack on success, and
   then recreates the single-rollback/no-active-install crash window. Startup
   recovery restores the valid pack and removes stale staging with no
   transient state. The trigger and
   implementation are debug-only; release compilation and API-28 lint remain
   clean. This closes the emulator form of that fault, not the official
   production-size install, real full-disk behavior, gameplay/mode routing, or
   physical acceptance. Evidence:
   `docs/artifacts/2026-09-04/android/a3-device-install-faults.md`.
2. Collect the first physical Apple TV report against `v0.4.0` using
   `docs/TVOS-TESTING.md`.
3. Await the Issue #1 Feather-signed iPad import retest and the Issue #5 MacBook
   Air cursor/settings retest requested against Preview 5.
4. Keep Mii and physical Wii Remote/Nunchuk acceptance open until the Issue #5
   reporter can reach the settings and returns real hardware results.
5. Continue representative performance and frame-pacing work without changing
   the accepted 0.3.0 release baseline.
6. Complete the remaining three- and four-player, touch, motion, controller,
   audio, thermal, lifecycle, and long-soak rows in `docs/PRD.md`.
7. When Retro WFC returns, retest production login, matchmaking, a complete
   race, results, reconnect, and physical-device online play.
8. Follow `docs/UPSTREAM_UPDATES.md` whenever WiiCompiled or Retro Rewind
   advances; never accept an unpinned pack or `Code.pul`.

## Operating constraints

- Preserve user game data, Retro Rewind content, saves, and signing state.
- Never commit or publish a disc image, extracted assets, translated source
  shards, saves, credentials, signing material, device identifiers, or private
  captures.
- Use no more than one Simulator at a time and close it after validation.
- Recheck available storage before rebuilding large dependency or translation
  graphs.
- Keep build proof, physical acceptance, public distribution, performance, and
  live-service online acceptance as separate claims.
