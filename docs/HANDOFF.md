# KartPad handoff

## Current state

Android's three-dot menu is now a KartPad-owned, iOS-shaped card rather than a
narrow platform popup. On the visible API 36 phone it shows the rounded light
surface, icon rows, FPS checkmark, chevrons, compact replacement submenus, and
bounded scrolling. The emulator walker reached all eight title/top-level rows,
5 Controls, 2 Display, 6 Game Data & Saves, and 16 action destinations; 110
tests pass with one skip. Physical-device visual/font-scale/OEM acceptance is
still open. The exact audited unpublished dual APK SHA-256 is
`898a03bed41a95af41537f626ffee6928b609aec397bde7643cdc48c136517d7`.
The menu walker no longer resets shared package data; after detecting that
legacy behavior, the retained 6.12.5 pack and prior save were restored exactly
and the selector again shows **Installed 6.12.5**. Evidence:
`docs/artifacts/2026-09-05/android/a4-ios-shaped-menu-surface.md`.

The complete product now passes the guarded release-bundle runtime gate on the
official API 29 / Android 10 ARM64 emulator. Android 10 Goldfish could deadlock
when priority pipeline compilation raced Vulkan submission; API 29 and lower
now serialize only that pipeline pool while keeping asynchronous frame and
presentation workers. Universal and four-part device-split version 7 packages
sustained the process, initialized surface/audio, exposed the menu, rendered
diverse frames, and preserved durable state. The same exact AAB passed again on
the API 36 Pixel Tablet. API 28 remains provisional because its official ARM64
emulator has an empty Vulkan inventory. The disposable API 29 AVD and all
restricted data/log/frame copies were deleted; API 36 is visible on the
restored version 5 selector. Evidence:
`docs/artifacts/2026-09-05/android/a6-api29-product-runtime.md`.

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

Android A5 now proves the product runtime's translated guest TLS IOCTLV path,
not only the Mbed TLS wrapper. The visible ARM64 Pixel Tablet used real guest
memory vectors and the runtime socket table for new-session, guest DER root CA,
connect, handshake, write, read, and shutdown. It consumed a complete
4,797-byte encrypted response, observed orderly peer close as guest `-6`, and
rejected a wrong hostname as guest error `-9`. The
clean profile also proves missing `SETBUILTINROOTCA` content now fails as `-1`
rather than falsely succeeding; the loader accepts only the fixed hash-verified
Wii root from app-private NAND. Valid root loading and mutual TLS remain open.
The repeatable runner preserves private game data, never copies a key to the
device, cleans its exact fixture, and restores the production selector. This is
an opt-in pre-guest product fixture, not yet a retail Mario Kart/WFC-initiated
exchange or physical-device acceptance. The exact clean audited baseline
dual-game APK SHA-256 is
`aa227e2b2232c2d36d86044f44a26caa310325f42ca9774216a1a62dde94df89`.
Evidence: `docs/artifacts/2026-09-05/android/a5-guest-tls-ioctlv.md`.

The guest TLS runner now injects an abortive peer close after TCP establishment
and before handshake completion. The translated IOCTLV path reports `-5`; a
following clean product process completes the verified 4,797-byte response,
observes close as `-6`, and retains hostname rejection at `-9`. Transcript
checks are byte-offset scoped when rapid launches reuse one timestamped path.
This passes cold-process interruption recovery while preserving private game
data and keeping keys off Android. Same-process reconnect, Wi-Fi/cellular
transitions, WFC, and physical networking remain open. Evidence:
`docs/artifacts/2026-09-05/android/a5-guest-tls-interruption-recovery.md`.

That gate is now stronger: the failed `-5` handshake is shut down and followed
by a fresh guest SSL session in the same Android process. The second session
completes the verified 4,797-byte response and close `-6`; a recursion guard
prevents repeated recovery, and the independent wrong-host case remains `-9`.
This closes controlled same-process session/socket recovery. Network
transitions, WFC reconnect, and physical networking remain open. Evidence:
`docs/artifacts/2026-09-05/android/a5-guest-tls-same-process-recovery.md`.

The translated guest DNS primitive now passes on the same API 36 product lane.
An opt-in `SO_GETHOSTBYNAME` request is copied from Wii memory, resolved on the
production deferred worker, normalized to IPv4, and encoded back into the Wii
`hostent` layout. The fixture validated guest `localhost` as `127.0.0.1`, then
the exact APK repeated the existing TLS recovery cases. This is not yet a
retail guest request, Retro-WFC routing, local WFC, or physical networking.
Evidence: `docs/artifacts/2026-09-05/android/a5-guest-dns-ioctl.md`.

Android can now reach a freshly reconstructed pinned local-WFC service through
the emulator host boundary. `scripts/test-android-local-wfc-server.sh` starts a
digest-pinned, tmpfs-only PostgreSQL container, imports the upstream schema,
builds the clean server pin, checks all TCP/UDP listeners, and requires the
emulator's `10.0.2.2` NAS response. Its cleanup leaves no fixture process,
container, listener, or temporary server state. This does not prove translated
guest routing/login or a race. Evidence:
`docs/artifacts/2026-09-05/android/a5-local-wfc-server-boundary.md`.

The actual translated Retro client now reaches that isolated service as well.
An opt-in debug route is restricted to the Retro profile and official emulator
hardware, with fixed destination `10.0.2.2:29980`; release builds and arbitrary
intent destinations cannot activate it. On the visible API 36 phone, **Retro
WFC — 1 Player** sent a QR2 availability request and then a real
`/payload?g=RMCPD00` NAS request. The local server intentionally had neither an
executable payload nor production signing key, so it logged a missing payload
and the game stopped at `20913`. This is a pass for translated guest routing
and first local-WFC traffic, not login. The test save was restored exactly,
all disposable service state was removed, and the selector is visible. The
exact unpublished APK SHA-256 is `fdb3cb3c…`. Next online work requires a
locally controlled payload/client pair with a matching test key; do not serve
a placeholder or use a production private key. Evidence:
`docs/artifacts/2026-09-05/android/a5-translated-retro-local-wfc-request.md`.

The visible API 36 phone AVD now holds the installed selector after an exact
dual-product Retro launch reached the branded title. The run fixed a secondary
pre-Aurora ImGui shutdown assertion and made the production Retro installer
atomically persist `retro_rewind_root` after activation; the selector also
repairs it for a validated pack retained across an app update. The final
unpublished debug APK is
`9c20099ab98f04dfde1d83e16fcb229936ccf7d1a596dbb0b1245ad1aa5cb4c7`.
The retained tablet AVD was not modified. This remains emulator evidence; next
A5 work is translated retail Retro traffic against the isolated local WFC
service and then physical-device hardening. Evidence:
`docs/artifacts/2026-09-05/android/a5-dual-retro-phone-launch.md`.

Two independent scoped clean Android product builds are byte-identical at that
same `aa227e2b…` hash. An incremental package had the same 149 extracted files
but different ZIP ordering/alignment, so only the clean path is authoritative
for candidate checksums. This is local unsigned reproducibility, not a release
candidate or publication authorization. Evidence:
`docs/artifacts/2026-09-05/android/a6-clean-apk-reproducibility.md`.

A same-version emulator update-in-place check also passes. Distinct APK bytes
were installed sequentially with package data intact; the approved game data
and a private aggregate covering configuration, managed NAND, saves,
preferences, and Retro version state were unchanged. The clean profile did not
contain a retail save, custom touch preferences, or an installed Retro version,
so populated-state/version-code migration and physical acceptance remain open.
Evidence: `docs/artifacts/2026-09-05/android/a6-emulator-update-in-place.md`.

The stronger forward-version lane now passes too: the Pixel Tablet upgraded
version code 1 to 2, 2 to 3, and 3 to 4, with the latter passes preserving an
actual `Show FPS Counter=false` preference created through KartPad's product
menu.
The runner verifies the exact package and installed versions in addition to
the private durable-state aggregate. Retail-save, complete Retro, signed
release, and physical migration remain open. Evidence:
`docs/artifacts/2026-09-05/android/a6-emulator-version-upgrade.md`.
The installed version 4 migration fixture is
`4efee32c73ba0f5832733d4059316d9c4389c7358f2ff71f8f15dea0e2118ed7`.

The Android save-storage layer now has an emulator execution gate using only
deterministic synthetic RKSYS images in isolated app cache. Production
validation, export-read, staged restore, atomic replacement, prior-save backup,
pending cleanup, and corrupt-checksum rejection pass. This is not the Android
document-picker flow or a real retail-save result. The exact audited and
installed version 5 fixture is `67bc86e5…`; the selector is visibly resumed.
Evidence: `docs/artifacts/2026-09-05/android/a6-emulator-save-storage.md`.

The real Android DocumentsUI save path now passes on the Pixel Tablet too. The
production menu exported the initialized emulator RKSYS, re-imported the exact
document, staged it, restarted through the selector, applied it before SDL,
and retained an exact automatic prior-save backup. The guarded runner proved
exact byte equality privately, removed its precise recovery/public/test-backup
artifacts, retained the active save, and restored the visible selector.
Physical provider/device acceptance remains open. Evidence:
`docs/artifacts/2026-09-05/android/a6-emulator-save-document-picker.md`.

The release AAB lane is now deterministic, unsigned, and path-clean. A debug
intermediary was rejected after its `resources.pb` exposed absolute Gradle
cache paths. Release resource-source exclusion fixed that boundary, and two
independent clean release bundles match byte-for-byte at
`f1c107a7b2cf853f77ef245164821fa46e3502a83be8a3881d794edca7cf9e3e`.
Pinned bundletool structural/manifest validation and the strict ARM64/ELF/
permission/asset/privacy audit pass. The bundle remains local and unpublished;
signing, Play-generated device-split execution, and physical acceptance remain
open.
Evidence: `docs/artifacts/2026-09-05/android/a6-clean-unsigned-aab.md`.

Store-derived APK execution now passes locally as well. Pinned bundletool
generated a non-debuggable universal APK from that exact AAB, the strict APK
audit accepted only its exact two-file baseline-profile materialization, and
the Pixel Tablet showed the production Original/Retro selector before
executing `SDL_main` from installed ARM64 `libmain.so`. The guarded runner
restored the prior debug package and selector and privately proved the full
durable-state aggregate unchanged. Its temporary APK SHA-256 was
`ebfcbd0c8fc1471451e72b226480b3792c0a217938b482b705790311e143ac2e`.
Play device-split delivery, release signing, physical-device acceptance, and
publication remain open. Evidence:
`docs/artifacts/2026-09-05/android/a6-bundle-derived-apk-emulator.md`.

The current hardware preview is `0.4.0-android-preview.2` at version code 7.
Two clean unsigned AABs match at `d03f1791…`; the derived, non-debuggable APK
at `cfb32065…` passed real version 5-to-7 emulator upgrades, selector/native
runtime execution, and durable-state preservation before the debug fixture was
restored. The exact audited 90,477,735-byte ARM64/API-28+ APK is retained
locally and ignored at
`.android-bootstrap/hardware-preview/KartPad-0.4.0-android-preview.2-v7-arm64.apk`.
It uses only the local debug identity, contains no game data, is not a
release-key candidate, and was not published. Physical-device execution is the
next authority. Evidence:
`docs/artifacts/2026-09-05/android/a6-api29-product-runtime.md`.

Pinned bundletool's device-targeted path now passes on the Pixel Tablet as
well. It generated exactly base, ARM64, English, and xhdpi APKs. Every split is
aligned and shares one signer, all four native libraries are byte-identical to
the strict-audited AAB entries, and Package Manager installed exactly those
four components. The split form showed the selector and executed installed
ARM64 `SDL_main`; debug version 5 and the private durable-state aggregate were
then restored unchanged. This closes local device-specific split execution,
not actual Play service delivery, release-key signing, or physical hardware.
Evidence: `docs/artifacts/2026-09-05/android/a6-device-split-emulator.md`.

The phone handoff is now one guarded command:
`scripts/install-android-hardware-preview.sh`. It verifies the exact preview
hash and package audit, refuses emulators/unsupported devices before mutation,
protects any different installed KartPad build behind explicit update opt-in,
never clears/uninstalls/downgrades data, verifies installed preview metadata and
the two-game selector, then starts the UID-scoped capture. Its live negative
gate rejected the connected Pixel Tablet emulator without revealing the serial
or changing installed version 5. Run it only after disconnecting/stopping the
emulator and attaching one authorized physical phone. Evidence:
`docs/artifacts/2026-09-05/android/a6-physical-preview-handoff.md`.

The exact versioned product now also passes sustained runtime/rendering checks
on a real 16,384-byte kernel page-size AVD, not merely ELF alignment or source
fixtures. Both universal and device-split non-debuggable packages retained one
process, initialized SDL surface/audio, exposed the KartPad menu, rendered
diverse frames, and preserved durable state. The stronger gate passed again on
the 4 KiB Pixel Tablet. The disposable API 35 AVD and restricted private
fixture transfer were deleted; the persistent tablet is restored to debug
version 5 and the selector. Physical vendor Vulkan, performance, audio,
haptics, controller, and thermal acceptance remain open. Evidence:
`docs/artifacts/2026-09-05/android/a6-product-16k-runtime.md`.

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

The Android A4 candidate now has a pinned API 36 ARM64 Pixel Tablet lane and a
real tablet overlay branch copied from the accepted iPad defaults. Its
source-only 2560x1600 fixture passes guarded guest memory, scheduler/controller,
Dawn/Vulkan, orientation, three foreground cycles, all 14 accessibility hit
targets, and safe-frame containment of the full 280 dp R trigger. Physical
tablet touch-only racing and ergonomics remain open. Evidence:
`docs/artifacts/2026-09-05/android/a4-tablet-overlay-parity.md`.

The Android A4 Controls menu now includes persistent Player 1--4 controller
setup backed by Aurora's existing identity store. On the visible Pixel Tablet
emulator, a two-controller source fixture proved separate assignments,
occupied-slot replacement with old-slot clearing, and explicit clearing through
the real accessible dialogs. A fresh patch preparation, complete translated
dual-runtime build, lint, 74-test suite, and package/privacy audit pass. Physical
multi-controller/reconnect/rumble behavior remains open. Evidence:
`docs/artifacts/2026-09-05/android/a4-controller-player-setup.md`.

The Android game selector no longer depends on legacy platform compass,
direction, or undo drawables. KartPad-owned steering-wheel, checkered-flag, and
go-backward vectors now match the iOS icon language and passed visible
2560x1600 Pixel Tablet inspection plus the complete translated-runtime build,
lint, and strict APK audit. Evidence:
`docs/artifacts/2026-09-05/android/a4-selector-owned-icons.md`.

The selector now also has a reusable raw-frame visual gate. Both visible pinned
API 36 ARM64 lanes pass: Pixel 6 at 2400x1080 and Pixel Tablet at 2560x1600.
The source-only test proves exact iOS-derived blue/pink fills, equal centered
cards, required labels, full-size mark, RGBA dimensions, and gradient direction;
its bypass cannot activate in game-runtime builds. Evidence:
`docs/artifacts/2026-09-05/android/a4-selector-visual-contract.md`.

Android's production touch owner now has a debug/source-only real `MotionEvent`
multi-pointer replay. Visible Pixel 6 and Pixel Tablet runs both sustain 0.75
analog steering while A, R, and Z are held together, retain steering through
independent button lifts, and finish neutral with no owners. The fixture is
unreachable in a game-runtime build; the complete translated APK still builds,
lints, and audits. Evidence:
`docs/artifacts/2026-09-05/android/a4-multipointer-replay.md`.

The phone and tablet overlay hit maps are now independently exercised from
their screenshots. Every one of 14 control centers and near-edge points maps
to the intended control, while a real touch in empty gameplay space passes
through without creating an owner or button state. Evidence:
`docs/artifacts/2026-09-05/android/a4-touch-hit-map.md`.

Virtual accessibility actions are now repeatable on both canonical emulators:
A focus, B pulse, Move Right plus timeout, A lock/state, normal-click unlock,
four haptic dispatches, focus clear, and final neutral state all pass through
the production node provider. Evidence:
`docs/artifacts/2026-09-04/android/a4-touch-accessibility.md`.

Motion steering now passes a real `SensorManager` flow on Pixel 6 and Pixel
Tablet. After confirmed gravity-sensor registration, an emulator accelerometer
tilt produces positive steering in standard mode and negative steering under
the persisted inversion setting; the original sensor vector is restored.
Evidence: `docs/artifacts/2026-09-05/android/a4-motion-sensor-flow.md`.

Android's selector now follows the iOS two-card interaction rather than adding
a separate recovery button: choosing Original or Retro without game data opens
the shared importer and retains that choice. The visible Pixel Tablet also
shows KartPad-owned symbols throughout the consolidated three-dot hierarchy.
A new raw-frame touch visual gate passes the accepted phone and tablet layouts,
including their intentionally different X/Z ordering. The final translated APK
build, lint, 77-test suite, and strict audit pass. Evidence:
`docs/artifacts/2026-09-05/android/a4-selector-menu-touch-visual-parity.md`.

Android's modal/lifecycle input clearing now has real event-replay evidence.
Held A (`0x10`, one owner) becomes neutral with no owner when the three-dot menu
opens on both canonical emulator layouts and when the Pixel 6 receives Home and
`onPause`. The source-only entry points cannot run in the translated game build;
that build still compiles, lints, and audits. Evidence:
`docs/artifacts/2026-09-05/android/a4-touch-modal-lifecycle-clearing.md`.

SDL activity recreation now works instead of hitting SDL's default process-exit
guard. Real `Activity.recreate()` runs on Pixel 6 and Pixel Tablet clear held A
in the outgoing instance, create a neutral replacement overlay in the same PID,
and restore edited A geometry plus hidden B state. Evidence:
`docs/artifacts/2026-09-05/android/a4-touch-activity-recreation.md`.

Android per-control touch persistence now has real process-boundary evidence on
both canonical emulator layouts. A reloads at normalized `(0.55,0.55)` and
1.25x size after force-stop, while hidden B is absent from the independently
rebuilt accessibility tree. The source fixture restores defaults after the
check. Evidence:
`docs/artifacts/2026-09-05/android/a4-touch-state-persistence.md`.

The full Android Touch Control Settings dialog now has a repeatable visual and
accessibility gate on both canonical emulator layouts. Pixel 6 at 2400x1080 and
Pixel Tablet at 2560x1600 expose all iOS-parity render, opacity, size,
controller-hiding, C-stick, move, reset, and Done controls without clipping;
the verifier also locks the default 1x selection and landscape two-column
composition. Evidence:
`docs/artifacts/2026-09-05/android/a4-touch-settings-visual-contract.md`.

The layout editor's complete control round trip now executes on both emulator
families. The real Move Controls action enters editing, a real touch selects A,
Hide/Show changes and restores its persisted visibility, 1.25x selected sizing
propagates, and the real Back button reopens Touch Control Settings. Evidence:
`docs/artifacts/2026-09-05/android/a4-touch-editor-flow.md`.

The one-second A acceleration lock now has timed real-event replay on both
emulator families. The runs prove pre-threshold unlocked state, cyan locked
state at about 1.1 seconds, one Android virtual-key haptic request, lock after
release, and neutral after a second tap. Physical haptic feel remains open.
Evidence:
`docs/artifacts/2026-09-05/android/a4-touch-gas-lock-replay.md`.

Android's nested Display menu now uses the exact iOS choice wording, including
Original 4:3, explicit Experimental labels for both wider modes, and 1x Native
through 4x render choices. The real Pixel 6 popup/dialog path was traversed and
remained in bounds. Evidence:
`docs/artifacts/2026-09-05/android/a4-display-menu-label-parity.md`.

The touch editor replay now also performs a real down/move/up drag and the real
confirmed per-device reset. Pixel 6 and Pixel Tablet both persist the dragged A
origin, then clear its origin and 1.25x size through the queued reset callback.
Evidence:
`docs/artifacts/2026-09-05/android/a4-touch-editor-drag-reset.md`.

Global Touch Control Settings now also pass a real widget/process-restart flow
on both canonical emulators, and Android's fresh aspect default is corrected
from Fill Screen to iOS's Original 4:3. The selector now matches iOS's exact
vertical spacing, card insets/height, upward offset, and centered symbol/label
groups; stricter phone/tablet raw-frame gates and a real tablet card tap pass.
Evidence:
`docs/artifacts/2026-09-05/android/a4-touch-settings-state-selector-geometry.md`.

The consolidated three-dot menu now has a real reachability/action gate rather
than a source-only inventory. Pixel 6 and Pixel Tablet each expose all 8
top-level, 5 Controls, 2 Display, and 6 Game Data & Saves rows through actual
rendered submenus, then exercise 16 representative actions, including persisted
FPS toggling, the bounded source-build disc-import state, and real DocumentsUI
folder handoff. Its touch, motion, Wii Remote, import, removal, and Mii rows now
use distinct KartPad-owned equivalents of the corresponding iOS symbols, and
the gate requires every actionable icon to render. Evidence:
`docs/artifacts/2026-09-05/android/a4-menu-hierarchy-reachability.md`.

The untouched Android phone layout now gives X and Z a 49 px rendered gap on
the canonical Pixel 6, up from 32 px, without changing sizes, custom layouts,
or the separate iPad-derived tablet geometry. Both visible emulator lanes,
the translated build, strict package audit, lint, and full source suite pass.
Evidence: `docs/artifacts/2026-09-05/android/a4-phone-xz-spacing.md`.

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
   The production Android space probe now has a real controlled low-capacity
   execution on a wiped API 36 ARM64 AVD. A safety-capped 1,121 MiB filler
   reduced the shared app store to 4,186,030,080 available bytes, below the
   profile-derived 4,327,477,355-byte requirement. The probe returned
   `INSUFFICIENT_SHARED_STORE`, no archive cache state appeared, the filler was
   removed, and the emulator stopped. This proves preflight refusal before
   acquisition, not mid-transfer/mid-extraction `ENOSPC` or a production-size
   install. Evidence:
   `docs/artifacts/2026-09-04/android/a3-device-low-space.md`.
   The after-preflight full-disk fault now executes through the real Android
   pipeline on a temporary API 36 ARM64 AVD. A 512 MiB app-private ext4 mount
   accepted 117,440,519 bytes of a validated 402,653,184-byte synthetic file
   before JNI returned `IO_FAILURE`; exact staging was removed and the prior
   validated install remained intact. Cleanup deleted the loop image, host
   fixtures, emulator, and exact temporary AVD, returning host free space to
   46 GiB. This closes the synthetic emulator fault, not the official
   production-size install. Evidence:
   `docs/artifacts/2026-09-04/android/a3-device-enospc.md`.
   The official production-size installer now passes on a wiped API 36 ARM64
   emulator. Its real 1,859,041,899-byte download matched the pinned digest.
   Execution exposed a missing cold-worker JNI load and cached-archive space
   double-counting on Retry; both are fixed with direct host/device regression
   coverage. The patched retry reused the archive, activated 2,110,038,016
   bytes, removed the cache, and revalidated version 6.12.5 after force-stop in
   airplane mode. Gameplay/mode switching and physical acceptance remain open.
   Evidence:
   `docs/artifacts/2026-09-04/android/a3-production-install.md`.
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
