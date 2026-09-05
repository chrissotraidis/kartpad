# KartPad status

Updated: 2026-09-05

The physical-phone handoff now rejects devices that do not declare both Vulkan
version and level before any package mutation, and the complete preview session
requires at least 6 GiB free under `/data`. The mocked preflight passes 13
supported/rejected cases, including a device with declared Vulkan but no
available driver JSON and an explicit no-Vulkan rejection. A live negative run
with the latest exact dual APK rejected the visible emulator, kept its installed
APK hash unchanged, and left the selector active. This is stronger intake
safety, not physical execution. Evidence:
[`docs/artifacts/2026-09-05/android/a6-physical-vulkan-storage-preflight.md`](artifacts/2026-09-05/android/a6-physical-vulkan-storage-preflight.md).

Android A4 now owns an iOS-shaped in-game menu instead of relying on the narrow
platform `PopupMenu`. The native 2400x1080 phone emulator renders a rounded,
right-anchored card with the KartPad header, icons, FPS checkmark, submenu
chevrons, separators, bounded scrolling, and compact replacement pages with a
back header. The real emulator walker reached all eight title/top-level rows,
five Controls actions, two Display actions, six Game Data & Saves actions, and
all 16 action destinations. The 110-test suite passes with one intentional
skip. This is phone-emulator menu parity, not physical-device or large-font/OEM
acceptance. The exact audited unpublished dual APK is
`898a03bed41a95af41537f626ffee6928b609aec397bde7643cdc48c136517d7`.
The walker was also made non-destructive after its legacy fixture reset was
found, and the prior 6.12.5 pack/save state was restored exactly. Evidence:
[`docs/artifacts/2026-09-05/android/a4-ios-shaped-menu-surface.md`](artifacts/2026-09-05/android/a4-ios-shaped-menu-surface.md).

The complete release product now passes on the official API 29 / Android 10
ARM64 emulator as well as the pinned API 36 tablet and API 35 16 KiB lane.
Android 10's Goldfish Vulkan transport deadlocked when Aurora raced pipeline
creation with submission; serializing only the priority pipeline-worker pool
on API 29 and lower fixed the stall while retaining asynchronous frame and
presentation workers. Both universal and four-part device-split version 7
packages sustained the runtime, exposed the menu, rendered diverse frames,
and preserved durable state on API 29, then the same exact AAB passed again on
API 36. The local preview is now `0.4.0-android-preview.2`; API 28 remains
provisional because its official emulator exposes no usable Vulkan adapter.
Physical vendor-driver, performance, touch/audio/haptics/controller, thermal,
and lifecycle acceptance remain open. Evidence:
[`docs/artifacts/2026-09-05/android/a6-api29-product-runtime.md`](artifacts/2026-09-05/android/a6-api29-product-runtime.md).

Android A5 now exercises the product runtime's translated guest `/dev/net/ssl`
IOCTLV handler, not only its Mbed TLS session wrapper. An opt-in emulator run
constructed actual guest memory vectors and traversed `SSL_NEW`, guest DER root
CA loading, socket-table `CONNECT`, handshake, write, read, and shutdown. The
visible ARM64 Pixel Tablet consumed the complete 4,797-byte encrypted HTTP
response, observed orderly peer close as guest `-6`, and returned guest error
`-9` for the wrong hostname. Android now fails `SETBUILTINROOTCA` when the
managed Wii NAND lacks the exact hash-verified `rootca.pem`, instead of
acknowledging an unconfigured trust anchor; valid user-owned root loading and
client certificates remain unaccepted. The repeatable runner preserves
app-private game data, places no key on the device, cleans its public fixture,
and returns to the production selector. Fresh runtime patch reproduction, 96
tests with one skip, product-configured lint, and strict package/repository
audits pass. This remains an opt-in pre-guest product fixture, not a retail
Mario Kart/WFC-initiated request. Built-in Wii CA/client certificates,
local/public WFC, interruption recovery, and physical Android acceptance remain
open. The clean reproducible dual-game baseline APK SHA-256 is
`aa227e2b2232c2d36d86044f44a26caa310325f42ca9774216a1a62dde94df89`.
Evidence:
[`docs/artifacts/2026-09-05/android/a5-guest-tls-ioctlv.md`](artifacts/2026-09-05/android/a5-guest-tls-ioctlv.md).

The same translated guest TLS fixture now has a deterministic interrupted-
handshake recovery gate. A one-shot host peer waits until TCP establishment,
then resets the connection during negotiation; the guest IOCTLV path reports
`-5`. The next clean product process completes the verified 4,797-byte response,
observes peer close as `-6`, and still rejects the wrong hostname as `-9`.
The runner also handles Android reusing a timestamped transcript by scanning
only bytes appended after launch. The test preserves game data, copies no key
to Android, cleans its fixture, and restores the selector. This proves cold-
process recovery only; same-process reconnect, network transitions, WFC, and
physical networking remain open. Evidence:
[`docs/artifacts/2026-09-05/android/a5-guest-tls-interruption-recovery.md`](artifacts/2026-09-05/android/a5-guest-tls-interruption-recovery.md).

The interruption gate now also recovers inside the same Android process.
After guest handshake `-5`, the fixture drives production `SSL_SHUTDOWN`,
cleans the Wii/native socket table, restores its guest scratch region, and uses
a guarded second session to complete the verified response and close `-6`.
The later wrong-host case still returns `-9`. Fresh preparation, package-marker
verification, the strict debug-APK audit, and cleanup/state checks pass. This
closes controlled same-process guest TLS session recovery, not Wi-Fi/cellular
transitions, WFC reconnect, or physical networking. Evidence:
[`docs/artifacts/2026-09-05/android/a5-guest-tls-same-process-recovery.md`](artifacts/2026-09-05/android/a5-guest-tls-same-process-recovery.md).

Android A5 now also crosses the translated guest DNS boundary. An opt-in
product request passes through the production deferred `SO_GETHOSTBYNAME`
preparation and worker, then validates the complete Wii `hostent` written back
to guarded guest memory. The API 36 emulator resolved guest `localhost` to
`127.0.0.1`; the exact APK then repeated the same-process TLS recovery gate.
The runner preserved app-private game data, removed its trigger, and restored
the selector. This proves deterministic guest DNS marshalling, not retail
guest initiation, Retro-WFC routing, local WFC, network transitions, or
physical networking. Evidence:
[`docs/artifacts/2026-09-05/android/a5-guest-dns-ioctl.md`](artifacts/2026-09-05/android/a5-guest-dns-ioctl.md).

The isolated local-WFC service boundary is reproducible for Android testing.
A guarded runner uses a digest-pinned PostgreSQL 17 image with tmpfs-only data,
imports the unchanged pinned server schema, builds the clean server revision,
and requires frontend/backend, NAS, GameSpy, QR2, and NATNEG listeners. The
API 36 emulator received the expected NAS response through `10.0.2.2`; cleanup
left no fixture process, container, port, or temporary server state. This is
server reachability only—not translated guest routing, authentication,
matchmaking, racing, or physical networking. Evidence:
[`docs/artifacts/2026-09-05/android/a5-local-wfc-server-boundary.md`](artifacts/2026-09-05/android/a5-local-wfc-server-boundary.md).

The actual translated Retro client now crosses that boundary. A debug-only,
emulator-only product switch routes the Retro profile to fixed host alias
`10.0.2.2` and NAS port `29980`; it accepts no arbitrary destination and
release builds cannot enable it. The visible API 36 phone entered **Retro WFC
— 1 Player**, explicitly permitted its privacy prompt, exchanged a QR2
availability datagram, and made a real `RMCPD00` NAS payload request to the
isolated server. The server deliberately had no executable payload or
production signing key, so it rejected the missing file and the game reported
`20913`. This passes translated guest routing and first local service traffic,
not payload validation, authentication, matchmaking, racing, reconnect, or
physical networking. App-private save state and the visible selector were
restored exactly, and all fixture state was removed. The exact unpublished APK
SHA-256 is
`fdb3cb3c995ddeaf1daef37acfb82dc45f1ffffe41f764fdc6362bcc21ae9a9c`.
Evidence:
[`docs/artifacts/2026-09-05/android/a5-translated-retro-local-wfc-request.md`](artifacts/2026-09-05/android/a5-translated-retro-local-wfc-request.md).

The visible API 36 phone emulator now also repeats production-selector launch
with the complete dual Original/Retro graph and retained validated 6.12.5 pack.
It exposed and fixed safe cleanup before Aurora initialization, then reached
the rendered Retro Rewind title from the installed selector. The Retro install
worker now durably writes its relative runtime root after activation, and the
selector repairs that path for an already-installed pack after an app update.
The exact local-only dual APK is
`9c20099ab98f04dfde1d83e16fcb229936ccf7d1a596dbb0b1245ad1aa5cb4c7`;
110 tests with one skip and the package/privacy and repository audits pass.
This is emulator launch evidence, not physical-device, online, performance, or
release acceptance. Evidence:
[`docs/artifacts/2026-09-05/android/a5-dual-retro-phone-launch.md`](artifacts/2026-09-05/android/a5-dual-retro-phone-launch.md).

Android A6 now has a byte-level clean-build reproducibility result. Two
independent scoped Android app cleans and product rebuilds produced identical
APK bytes at SHA-256
`aa227e2b2232c2d36d86044f44a26caa310325f42ca9774216a1a62dde94df89`.
An incremental pre-clean package had identical 149-file extracted content but a
different outer ZIP order/alignment, so release-candidate hashes must come from
the clean path. Signed reproducibility, update-in-place, physical acceptance,
and release authorization remain open. Evidence:
[`docs/artifacts/2026-09-05/android/a6-clean-apk-reproducibility.md`](artifacts/2026-09-05/android/a6-clean-apk-reproducibility.md).

Android A6 also passes a same-version emulator update-in-place check. Two APKs
with different outer bytes were installed sequentially with `adb install -r`,
without clearing package data. The approved `main.dol` and a private aggregate
of configuration, managed NAND, saves, preferences, and Retro version state
were unchanged, and the runner restored the visible production selector. The
profile contained no retail save, custom touch preferences, or installed Retro
version, so preservation of those populated states remained open at that
checkpoint alongside physical acceptance. Evidence:
[`docs/artifacts/2026-09-05/android/a6-emulator-update-in-place.md`](artifacts/2026-09-05/android/a6-emulator-update-in-place.md).

Android A6 now also passes a genuine forward version-code migration on the
visible Pixel Tablet. Version 1 upgraded to 2, then 2-to-3 and hardened 3-to-4
runs preserved a real `Show FPS Counter=false` preference created through the
product menu along with the complete private state aggregate. The runner
requires the exact KartPad package identity, confirms each installed version,
never clears data, and restores the selector. Retail-save, complete Retro,
signed-release, and physical-device migration remain open. The installed
version 4 migration fixture SHA-256 was
`4efee32c73ba0f5832733d4059316d9c4389c7358f2ff71f8f15dea0e2118ed7`.
Evidence:
[`docs/artifacts/2026-09-05/android/a6-emulator-version-upgrade.md`](artifacts/2026-09-05/android/a6-emulator-version-upgrade.md).

Android A6 now exercises the production save-storage implementation on the
emulator with deterministic synthetic RKSYS images. Exact validation,
export-read bytes, staged restore, atomic activation, prior-save backup,
pending cleanup, and corrupt-checksum rejection pass in an isolated cache
root. The runner never clears app data, verifies the approved game fixture,
and restores the selector. The installed audited version 5 fixture SHA-256 is
`67bc86e5c0e1ad5ea7fa9c93744a78279e046caba6a7336736fcd6d2e68cfd04`.
Document-picker round trips, a real retail save, and physical acceptance remain
open. Evidence:
[`docs/artifacts/2026-09-05/android/a6-emulator-save-storage.md`](artifacts/2026-09-05/android/a6-emulator-save-storage.md).

Android A6 now also passes the actual system document-picker save flow. The
visible Pixel Tablet exported its initialized RKSYS through DocumentsUI,
verified exact bytes privately, re-imported that document through DocumentsUI,
staged it, restarted through the selector, applied it before SDL startup, and
proved both the active restore and KartPad's automatic prior-save backup exact.
The guarded runner retained recovery copies on interrupted attempts and, after
the passing run, removed only its exact private/public fixtures while leaving
the active save and visible selector intact. Physical provider/device
acceptance remains open. Evidence:
[`docs/artifacts/2026-09-05/android/a6-emulator-save-document-picker.md`](artifacts/2026-09-05/android/a6-emulator-save-document-picker.md).

Android A6 now has a deterministic unsigned release AAB path. The initial
debug intermediary was correctly rejected because `resources.pb` embedded
absolute Gradle-cache paths. The release lane excludes resource-source
metadata; two independent clean builds are byte-identical at SHA-256
`f1c107a7b2cf853f77ef245164821fa46e3502a83be8a3881d794edca7cf9e3e`.
Pinned bundletool validation and the new strict bundle audit pass package/SDK/
permission identity, unsigned state, exact ARM64 libraries/assets, 16 KiB ELF
  alignment, dependencies/exports, parser-marker cardinality, and private-path/
data exclusion. Signing, Play-generated device-split testing, physical
acceptance, and publication remain open. Evidence:
[`docs/artifacts/2026-09-05/android/a6-clean-unsigned-aab.md`](artifacts/2026-09-05/android/a6-clean-unsigned-aab.md).

The exact release AAB now also passes a store-derived execution gate. Pinned
bundletool generated a locally debug-signed universal APK at SHA-256
`ebfcbd0c8fc1471451e72b226480b3792c0a217938b482b705790311e143ac2e`.
The independent APK audit accepts only bundletool's exact two-file baseline-
profile materialization, confirms the package is non-debuggable, and retains
the complete existing package/ABI/ELF/asset/privacy checks. On the visible
Pixel Tablet, the APK presented the two-game production selector, entered
Original through its enabled card, and executed `SDL_main` from the installed
ARM64 `libmain.so`. The runner then restored the prior debug APK and proved the
private durable-state aggregate unchanged. Play-generated device splits,
release-candidate signing, physical acceptance, and publication remain open.
Evidence:
[`docs/artifacts/2026-09-05/android/a6-bundle-derived-apk-emulator.md`](artifacts/2026-09-05/android/a6-bundle-derived-apk-emulator.md).

The current Android hardware-preview identity is now
`0.4.0-android-preview.2` version code 7, carrying the API 29 Vulkan
compatibility correction.
Both metadata inputs are validated, and strict APK/AAB audits require the
expected name. Two independent scoped clean builds produced identical unsigned
AAB bytes at SHA-256
`d03f1791989142e109f2a3101a3bca629e80d3b8b1fdde54269b17b21d554f4a`.
The exact derived non-debuggable APK upgraded the populated emulators from
version 5 to 7, executed the native runtime, and preserved durable state before
the debug fixture was restored. Its SHA-256 is
`cfb32065650a15e9d3ddab9aa2705ea62e9930626445c7e568e1ef29b8e53420`,
and the audited 90,477,735-byte local hardware preview is retained ignored
under `.android-bootstrap/hardware-preview/`. Physical testing is now the next
authority; this local debug-signed preview is not a release-key candidate and
was not published. Evidence:
[`docs/artifacts/2026-09-05/android/a6-api29-product-runtime.md`](artifacts/2026-09-05/android/a6-api29-product-runtime.md).

Local Play-style device targeting now passes too. Pinned bundletool queried the
Pixel Tablet device spec and emitted exactly four APKs: base, ARM64, English,
and xhdpi. The runner verified one signer across all splits, 16 KiB-aware
alignment, preview package/version/non-debug state, and byte identity between
every split native library and the audited AAB. Package Manager reported the
four expected installed components; the production selector and installed
ARM64 `SDL_main` then ran before the debug fixture was restored with durable
state unchanged. Actual Play service delivery, release-key signing, and
physical-device acceptance remain open. Evidence:
[`docs/artifacts/2026-09-05/android/a6-device-split-emulator.md`](artifacts/2026-09-05/android/a6-device-split-emulator.md).

The retained hardware preview now has a guarded physical-session installer.
It requires the exact audited APK, runs the API/ABI/page-size/free-space
physical preflight before mutation, refuses emulators, and will not replace a
different KartPad build without explicit update opt-in. It never uninstalls,
clears, or downgrades package data; after install it requires version/name and
the two-game selector, then starts the UID-scoped capture window. A live
negative run rejected the sole Pixel Tablet emulator with the serial redacted
and installed version 5 unchanged. No physical target is connected, so this is
handoff hardening rather than physical acceptance. Evidence:
[`docs/artifacts/2026-09-05/android/a6-physical-preview-handoff.md`](artifacts/2026-09-05/android/a6-physical-preview-handoff.md).

The complete versioned product runtime now executes on Android's 16 KiB kernel
lane, closing the gap between source-fixture/page-alignment evidence and the
actual translated release package. On a disposable API 35 ARM64 Pixel 7 with
16,384-byte pages, both the non-debuggable universal APK and exact four-part
device split retained one process, initialized surface/audio, exposed the
KartPad menu, rendered a diverse frame, and preserved durable state. The same
strengthened gate passed again on the persistent API 36 / 4 KiB Pixel Tablet.
A private game/runtime fixture transfer matched file content exactly and was
deleted with the temporary AVD afterward; no private frame or content was
retained. Physical vendor-driver/performance acceptance remains open. Evidence:
[`docs/artifacts/2026-09-05/android/a6-product-16k-runtime.md`](artifacts/2026-09-05/android/a6-product-16k-runtime.md).

The latest Android A4 checkpoint fixes a real SDL lifecycle gap: KartPad now
enables SDL activity recreation, so Android can rebuild `KartPadActivity`
without SDL terminating the process. Visible Pixel 6 and Pixel Tablet runs held
A through a real `Activity.recreate()` request, proved the outgoing overlay
became neutral, then proved the new overlay started neutral and restored edited
A geometry plus hidden B state. The complete translated APK SHA-256 is
`7e85ffc806a14db2e0954f4da8481f9e8ab9f1728c3e64e2cd74203c82af87d1`;
89 tests with one skip, lint, strict audit, and safety checks pass. Physical
Android acceptance remains open. Evidence:
[`docs/artifacts/2026-09-05/android/a4-touch-activity-recreation.md`](artifacts/2026-09-05/android/a4-touch-activity-recreation.md).

The latest Android A4 checkpoint gives global Touch Control Settings a real
widget/process-restart gate on both canonical emulators and corrects the fresh
aspect default to iOS's Original 4:3. It also tightens the Original/Retro
selector to the iOS spacing, insets, card height, vertical offset, and centered
symbol/label composition. Pixel 6 and Pixel Tablet raw-frame gates plus an
actual tablet Original-card tap pass. The translated local APK SHA-256 is
`a221911feec75a9eb295fa418980635f8811fa64524269e7b7f610cf56391abe`;
85 tests with one skip, lint, strict audit, and safety checks pass. Physical
Android acceptance remains open. Evidence:
[`docs/artifacts/2026-09-05/android/a4-touch-settings-state-selector-geometry.md`](artifacts/2026-09-05/android/a4-touch-settings-state-selector-geometry.md).

The three-dot menu also has a rendered reachability gate on Pixel 6 and Pixel
Tablet. Both expose all 21 required rows across the top level, Controls,
Display, and Game Data & Saves submenus, then pass 16 representative actions,
including persisted FPS toggling and routes into dialogs, managers, or Android
DocumentsUI. Distinct KartPad-owned hand, gyroscope, antenna, refresh, trash,
and Mii symbols now mirror the current iOS menu semantics; the emulator gate
also requires all 20 actionable icons to render. The translated APK SHA-256 is
`a5310650f970ea45ea26d7414392215fb7912915bc601401df162c9c23d4093f`.
Evidence:
[`docs/artifacts/2026-09-05/android/a4-menu-hierarchy-reachability.md`](artifacts/2026-09-05/android/a4-menu-hierarchy-reachability.md).

The untouched phone touch layout now increases the rendered X/Z gap from 32
px to 49 px while preserving saved layouts and leaving the separate tablet
defaults unchanged. Both canonical emulator visual contracts pass. The final
translated APK SHA-256 is
`a1b88fc4f74d860ba97d530f8defff988995d73cd7fd4245617f50f4d79096bc`;
the strict audit, lint, and 86-test suite with one skip pass. Evidence:
[`docs/artifacts/2026-09-05/android/a4-phone-xz-spacing.md`](artifacts/2026-09-05/android/a4-phone-xz-spacing.md).

## Native Android work

Android A0 passes on the authorized second Apple Silicon host. The explicit
bootstrap pins public ARM64 Temurin 17, SDK/Build Tools/NDK/CMake/emulator
components and two disposable ARM64 AVDs. The non-playable SDLActivity shell,
transparent KartPad-owned overlay, SDL/JNI entry, and Dawn Vulkan adapter
fixture build and pass package audit, then install and run on API 36 / 4 KiB
and Android 15 / 16 KiB cold-boot AVDs. The audited local debug APK SHA-256 is
`c28461e09f78ba2dc05ab70d137d1918d2e559c9ec2864ae645d26f3697e22ee`.
This does not prove a presented frame, lifecycle, guest memory, fibers,
gameplay, physical Android hardware, performance, or release readiness; no APK
or AAB was published. Evidence:
[`docs/artifacts/2026-09-03/android/a0-source-only-fixture.md`](artifacts/2026-09-03/android/a0-source-only-fixture.md).
The lowest incomplete goal is A2.

The first A1 renderer slice passes on both pinned page-size lanes. One Dawn
Vulkan device performs an exact 16-pixel GPU clear/readback, presents through
SDL's Android native window, and presents again after an automated
HOME/foreground surface recreation. It now also observes an exact physical
landscape-to-flipped-landscape sensor transition, reconfigures the retained
Dawn surface, and replaces/presents through three consecutive
background/foreground surface generations on both lanes. The ELF AArch64
fixture passes start/resume, yield, sleep/wake, join, cancel, two million
deterministic scheduler operations, and one million native context switches
with the complete callee-saved register set on both lanes. A separate A1
checkpoint reserves a dynamic sparse 4 GiB range and proves two shared
views, cross-alias visibility, and runtime-page-size-aware protection changes
on both 4 KiB and 16 KiB lanes without writable-executable memory. Evidence:
[`docs/artifacts/2026-09-03/android/a1-vulkan-readback-present.md`](artifacts/2026-09-03/android/a1-vulkan-readback-present.md)
and
[`docs/artifacts/2026-09-03/android/a1-lifecycle-stress.md`](artifacts/2026-09-03/android/a1-lifecycle-stress.md)
and
[`docs/artifacts/2026-09-03/android/a1-guest-memory.md`](artifacts/2026-09-03/android/a1-guest-memory.md)
and
[`docs/artifacts/2026-09-03/android/a1-elf-scheduler.md`](artifacts/2026-09-03/android/a1-elf-scheduler.md).

This closes A1's source-only native primitive and Vulkan-surface gate. It does
not prove production-runtime integration, gameplay, physical-device Vulkan,
or performance. The lowest incomplete goal is A2.

The first A2 build/link slice passes. A fresh ignored runtime copy consumes the
current common Apple patch stack plus narrow Android patches, compiles all
29,065 Original translated functions, and links them with the production
4 GiB guest-memory implementation, ELF AArch64 fibers, Aurora, pinned Dawn,
and the official SDL AAR as `libmain.so`. Gradle packages the complete runtime
through the normal app module while fixture mode remains the public default.
The resulting local ARM64 debug APK is 103,425,387 bytes with SHA-256
`5d96c31ef91ead5d7ada0977c1853d39b4fcc7f57ea8f4fe3439c1de89ac9e13`;
its stripped `libmain.so` is 83,529,560 bytes with SHA-256
`a1b15ee74f77fd891f7d885c6602bf23bd73c9b6e4cfcfc56ce1ee2279089165`.
The package passes ABI, dependency, RELRO, non-executable-stack, 16 KiB load,
JNI/SDL export, permission, native allowlist, and private-path/data audits.
This is build and package evidence only: no game data was included or staged,
and boot, gameplay, controller, audio, save/relaunch, lifecycle under the game,
and physical-device rows remain open. A2 remains the lowest incomplete goal.
Evidence:
[`docs/artifacts/2026-09-03/android/a2-original-runtime-link.md`](artifacts/2026-09-03/android/a2-original-runtime-link.md).

The next A2 storage/runtime slice also passes. Game-runtime builds package an
exact 14-file public asset allowlist and atomically install it before SDL loads
at `files/KartPad/RuntimeResources/a2-v1`. Context-derived app-private paths
now own configuration, logs, NAND, and mutable Dawn/Aurora caches without any
storage permission or private content in the APK. A cleared API 36 / 4 KiB
cold launch initializes the dynamic 4 GiB guest mapping, loads the translated
image, executes 43 main-DOL and 192 StaticR constructors, creates the Vulkan
renderer, seeds 1,199 public pipeline rows, and then fails closed at the exact
expected boundary because no DVD root is configured. The audited game APK is
103,429,792 bytes with SHA-256
`49526a79b60bdc0f1b3ca51202f4b95c12b2fef3329a552a125a63f1863011c2`.
This is app-private initialization evidence, not game boot or gameplay. A2
remains open for privately staged `RMCP01` data and the emulator/physical
gameplay matrix. Evidence:
[`docs/artifacts/2026-09-03/android/a2-app-private-runtime.md`](artifacts/2026-09-03/android/a2-app-private-runtime.md).

The first full Original emulator boot now also passes. Ignored validated
RMCP01 data is staged only under the app sandbox; the title, demo, saved
license, non-silent SDL stream, and live Luigi Circuit gameplay render through
the complete translated runtime. Six title/demo and three live-race
HOME/foreground cycles retained their process after a narrow stale-ImGui-frame
repair. Three cold processes restored the saved `KartPad` license. A debug-only
app-private RKG bridge reaches the existing native player fixture, but that
fixture diverges into the wall and does not finish; a separate clean Nintendo
staff replay rendered for more than twelve wall-clock minutes without a crash
but is not player/results/save evidence. A2 remains open for a complete player
race, results, post-race save/relaunch, real controller, and physical Android
hardware. Evidence:
[`docs/artifacts/2026-09-03/android/a2-emulator-boot-lifecycle.md`](artifacts/2026-09-03/android/a2-emulator-boot-lifecycle.md)
and
[`docs/artifacts/2026-09-03/android/a2-debug-input-replay.md`](artifacts/2026-09-03/android/a2-debug-input-replay.md).

An additional Android-only debug marker can now retain fixture acceleration
while routing steering through the existing keyboard stick. It accepts
steering but did not complete a race. Normal fixture steering also diverged on
exact GCN Mario Circuit metadata and on the exact SNES Mario Circuit 3 stream
previously proven through the native macOS player path. No forced finish was
used; the private all-cups test save was restored byte-for-byte afterward.
This is diagnostic capability only and does not narrow A2's remaining player,
controller, or physical-device gates. Evidence:
[`docs/artifacts/2026-09-03/android/a2-keyboard-steer-diagnostic.md`](artifacts/2026-09-03/android/a2-keyboard-steer-diagnostic.md).

Android's discovered SDL controllers now reach the Classic/KPAD path through
a narrow public Aurora snapshot and shared, host-tested mapping contract. A
lone unassigned controller may drive player one until the native settings UI
exists; explicit port assignments remain authoritative and multiple
unassigned pads are never guessed. Both page-size fixture lanes, a clean
private runtime preparation/link, lint, package/privacy audit, and exact patch
reproduction pass. No controller was attached, so live controller,
disconnect/reconnect, rumble, race, and physical-device acceptance remain
open. Evidence:
[`docs/artifacts/2026-09-03/android/a2-sdl-controller-bridge.md`](artifacts/2026-09-03/android/a2-sdl-controller-bridge.md).

Mario Kart's Android `WPADControlMotor` path now drives the same resolved SDL
controller with fail-closed Start/Stop rumble semantics; Apple behavior is
unchanged. The host contract, fresh patch reproduction, full private ARM64
link, lint, storage contract, and strict package/privacy audit pass. The exact
local-only 103,433,440-byte APK has SHA-256
`3044e148e320236b0b71d4cf86ff8a5b158a896c75671f215a5da8c0faf23ad0`.
No controller was attached, so tactile output and controller-driven gameplay
remain unaccepted. A temporary retail-KPAD RKG experiment also diverged with
an exact selectable staff configuration and was removed; it is not a product
or completion path. A2 remains open. Evidence:
[`docs/artifacts/2026-09-03/android/a2-sdl-controller-rumble.md`](artifacts/2026-09-03/android/a2-sdl-controller-rumble.md).

Android surface loss and backgrounding now suspend that shared SDL controller
bridge: snapshots fail neutral, new rumble starts fail closed, and active
rumble is stopped before surface release. Controller add/remove and the
cross-thread lifecycle callback are serialized so a removed pad cannot be
used during shutdown. A corrected API 36 cold launch starts with the bridge
active, and one process retained its PID through four HOME/surface recreation
cycles with exactly four suspend/resume pairs and no Android fatal. One prior
corrected process ended silently after a single cycle and remains an
unexplained non-reproduced exit. Fresh patch reproduction, private ARM64
compile/link, lint, storage and package/privacy audits pass. No controller was
attached, so actual neutral input and motor-stop behavior remain unaccepted.
Evidence:
[`docs/artifacts/2026-09-03/android/a2-controller-lifecycle.md`](artifacts/2026-09-03/android/a2-controller-lifecycle.md).

An app-private debug marker now exposes the existing content-free native
state trace at a fixed sandbox path before SDL starts. On the API 36 ARM64
emulator, a feedback driver consumed only that trace and emitted ordinary
Android keyboard events through the Classic/KPAD bridge. Mario completed all
three N64 Mario Raceway Time Trial laps, reached native finish stage 4, and
displayed retail results for `05:17.517`; the strict trace summarizer accepts
one 19,032-sample race segment from countdown through finish. No guest-state
write or forced finish was used. The game reported that ghost data could not
be saved, consistent with the previously observed native recorder overflow on
a slow unguided run; this is not post-race save proof. A later same-process
cold-input retry advanced title, license, and Main Menu with normally spaced
key events, correcting the earlier stuck-title observation. The original
in-sandbox save was restored byte-for-byte and all debug markers were removed.
A2 remains open for a natural controller race/save, audible audio, and
physical Android hardware. Evidence:
[`docs/artifacts/2026-09-03/android/a2-state-trace-player-race.md`](artifacts/2026-09-03/android/a2-state-trace-player-race.md).

Android's real InputReader-to-SDL discovery path is now exercised with a
temporary emulator virtual gamepad. The first hotplug exposed an ART CheckJNI
abort: game-side SDL queries crossed into Java from a switched Wii guest-fiber
stack. Event-backed controller snapshots, queued rumble, scheduler-only
Android event polling, and removal of the opportunistic Android pump close
both that query path and a separately reproduced reconnect crash. Exact-final
PID `5007` retained button and analog input through connect, disconnect,
reconnect, HOME/background, HOT foreground resume, post-resume input, and
final disconnect without an Android fatal. This passes emulator controller
hotplug and lifecycle behavior, not physical controller, motor, latency, OEM,
or device-performance acceptance. A2 remains open. Evidence:
[`docs/artifacts/2026-09-03/android/a2-virtual-controller-hotplug.md`](artifacts/2026-09-03/android/a2-virtual-controller-hotplug.md).

A controller-only follow-up drove the complete Time Trial setup flow and
entered live N64 Mario Raceway gameplay. Keeping the virtual controller
attached across a force-stop/cold launch then exposed a second scheduler
boundary: guest-fiber polls were safely skipped but never reliably serviced on
Android's original JNI stack. Guest requests are now handed off to the
scheduler fiber after a host-fiber return. Because one safe poll can collect a
short press and release together, event-backed button presses are latched for
one game snapshot so the edge is not collapsed. On the exact uninstrumented
PID `6595`, a 250 ms south-button tap from a controller attached before process
startup advanced to Select License, and another advanced to Main Menu. Fresh
patch preparation reproduces the changed source byte-for-byte; the host
gamepad contract, repository safety, overlay snapshot, diff check, full ARM64
build, and strict package audit pass. The exact local-only APK is 103,440,032
bytes with SHA-256
`2c11450996f33a35ba3aa85dcf16c1c467bf6fd4a0943edef966557639d7a6e7`.
One first launch of the clean scheduler build independently hit the known
intermittent untranslated Mii callback at `MiiManager::Init+0x134`; a controlled
retry and the final latch build remained live. This closes emulator
controller-after-cold-launch navigation, not a complete controller race/save,
physical controller, tactile rumble, audible output, performance, or physical
Android acceptance. A2 remains open. Evidence:
[`docs/artifacts/2026-09-03/android/a2-controller-cold-relaunch.md`](artifacts/2026-09-03/android/a2-controller-cold-relaunch.md).

The exact same APK now also passes the complete controller-driven emulator
race/save/relaunch gate. An InputReader/SDL virtual controller selected the
Time Trial configuration and supplied every race acceleration and analog-
steering input while a content-free state trace provided feedback only. Mario
finished all three N64 Mario Raceway laps at `04:28.063`; the retail results
screen reported `Saved ghost data for KartPad!`, and the trace transitioned
from race stage 2 to results stage 4. The isolated save changed from SHA-256
`40f5d5ae5ad93c39253559628a34359aa4627ebdc1b04605327cf2c59a5ff7e1`
to `23c15850daace1587661aa07a99f08e450313963b469e683f13ae5dc0d6af005`.
After a force-stop and controller-attached cold launch, the save retained that
exact hash, the new process logged controller channel 0 connected, and both the
course list and ghost chooser displayed KartPad's `04:28.063` record. This
closes the emulator controller race/results/save/relaunch slice, not physical
controller, rumble, audible output, performance, or physical-device
acceptance. A2 remains open. Evidence:
[`docs/artifacts/2026-09-04/android/a2-controller-complete-race-save.md`](artifacts/2026-09-04/android/a2-controller-complete-race-save.md).

The first physical-device session now has a read-only, serial-redacting intake
gate. It rejects emulators and unsupported API, ABI, page-size, or free-space
configurations, and reports sanitized model plus controller-source,
installed-package, and Vulkan-inventory state. Its twelve-case fake-ADB contract
passes. The live host had no ADB target, so this is tooling evidence only and
does not change A2's open physical acceptance rows. Evidence:
[`docs/artifacts/2026-09-04/android/a2-physical-device-preflight.md`](artifacts/2026-09-04/android/a2-physical-device-preflight.md).

A bounded Android session-log sanitizer now converts a private capture into an
allowlist-only JSON signal summary. Its self-test passes and strict mode cannot
merge separate logs. Applied retrospectively to the exact controller-race
console, it confirms 32 kHz stereo initialization, non-silent PCM, 194,856,192
submitted bytes with zero post-start empty observations, controller events,
and no fatal signature while retaining 465 dropped blocks. The combined matrix
correctly remains false because that capture lacks lifecycle events; none of
this replaces listening or physical acceptance. Evidence:
[`docs/artifacts/2026-09-04/android/a2-runtime-signal-sanitizer.md`](artifacts/2026-09-04/android/a2-runtime-signal-sanitizer.md).

The physical session now also has a tested two-phase capture wrapper. It keeps
raw logcat in Android's volatile buffer, scopes retrieval to KartPad's package
UID and a device-sourced start timestamp, streams directly into the strict
sanitizer, and emits neither UID nor ADB serial. Its start/summary/redaction
contract passes. No device is attached, so physical execution remains open.
Evidence:
[`docs/artifacts/2026-09-04/android/a2-uid-scoped-capture.md`](artifacts/2026-09-04/android/a2-uid-scoped-capture.md).

Independent source-only A3 work has begun without relabeling the blocked A2
physical row. The Retro Rewind archive member-path policy is now portable C++
and is consumed by the existing iOS/tvOS installer using minizip's explicit
filename byte length. Its contract rejects absolute paths, backslashes,
embedded NULs, empty/repeated components, dot traversal, and colons/drive
prefixes; a direct host test, pinned NDK ARM64 compile, Apple SDK syntax
compile, fresh dual-product patch preparation, and 29 Apple/builder contracts
pass. A full dual iOS link
stopped fail-closed before compilation because the local cached Dawn archive
does not match its pinned hash. This is one shared validation slice, not an
Android installer or A3 acceptance result. A2 remains the lowest incomplete
goal and A3 remains open. Evidence:
[`docs/artifacts/2026-09-04/android/a3-shared-archive-path.md`](artifacts/2026-09-04/android/a3-shared-archive-path.md).

The next shared A3 slice moves ZIP entry policy into a portable stateful scan.
The Apple installer now uses it to reject symlinks, encryption, negative sizes,
invalid paths, excess entries, excess expansion, and 64-bit total overflow;
safe foreign-root entries remain ignored and selected totals drive extraction
progress. Direct host tests, pinned NDK ARM64 warning-as-error compiles, Apple
SDK syntax compilation, fresh dual-product patch preparation, repository
safety, and Apple contracts pass. This still is not an Android installer or A3
runtime proof, and the full Apple link remains blocked before configuration by
the already recorded local Dawn cache hash mismatch. Evidence:
[`docs/artifacts/2026-09-04/android/a3-shared-archive-scan.md`](artifacts/2026-09-04/android/a3-shared-archive-scan.md).

The shared scan now also rejects duplicate selected paths before extraction,
including file/directory spellings that resolve to the same component sequence.
Duplicate failure leaves selected totals unchanged and latches the scan;
foreign-root duplicates remain ignored. Host contracts, the pinned NDK ARM64
compile, Apple SDK syntax compilation, repository safety, and Apple contracts
pass. The extraction-time filesystem check remains defense in depth. This
closes only the shared duplicate-directory rule, not A3. Evidence:
[`docs/artifacts/2026-09-04/android/a3-shared-archive-duplicates.md`](artifacts/2026-09-04/android/a3-shared-archive-duplicates.md).

Android now owns a tested app-private Retro Rewind storage coordinator. It
creates same-volume staging under `filesDir/KartPad`, scopes activation to the
exact generated token/path, atomically moves the prior install to rollback,
atomically activates only caller-validated staging, restores the prior install
after an injected second-move failure, removes stale imports, and restores only
one unambiguous rollback on cold startup. Directory and cleanup operations
refuse or avoid following symlinks. The game-runtime Activity invokes recovery
before SDL startup. Its pinned-JDK fault matrix, fixture debug build, debug and
release compilation, lint, strict 33,675,275-byte APK audit, and private game-
configuration compile pass. This is storage/recovery evidence, not download,
extraction, install validation, or gameplay. Evidence:
[`docs/artifacts/2026-09-04/android/a3-install-storage-recovery.md`](artifacts/2026-09-04/android/a3-install-storage-recovery.md).

Android's release constants are now deterministically rendered from the sole
repository Retro Rewind profile and checked byte-for-byte in the builder suite.
A bounded installed-tree validator enforces strict UTF-8/exact version, safe
relative paths, no symlinked nodes, exact `Code.pul` and XML byte counts, and
streamed SHA-256 before the storage coordinator may activate staging. The
generated contract also carries the already builder-validated production
payload pin; that translated-build input is not redownloaded as pack content.
Valid staging activates and revalidates in the fault harness, while missing,
short, tampered, unsafe, or symlinked content remains inactive. Pinned-JDK
tests, 22 builder tests, public debug/release compilation, lint, private game-
configuration compile, and the strict source-only APK audit pass. Evidence:
[`docs/artifacts/2026-09-04/android/a3-content-validation.md`](artifacts/2026-09-04/android/a3-content-validation.md).

Android now also has a pure, overflow-safe Retro Rewind free-space evaluator
and an Android probe that compares exact filesystem device IDs before applying
shared- or separate-store accounting. The policy retains a 256 MiB reserve and
requires exactly 4,327,477,355 bytes for the current same-store production
profile. Boundary/failure tests, the existing content and recovery matrices,
30 builder/tvOS tests, public build/release compilation, lint, repository
safety, and the strict source-only APK audit pass. No download worker calls the
probe yet, so this is capacity-policy evidence rather than an install or runtime
claim. Evidence:
[`docs/artifacts/2026-09-04/android/a3-space-preflight.md`](artifacts/2026-09-04/android/a3-space-preflight.md).

The next A3 layer adds pinned HTTPS archive acquisition with bounded redirects,
timeouts, identity encoding, exact length/SHA-256 verification, cancellation,
existing-cache revalidation, and atomic publication of only verified bytes.
The manifest requests only INTERNET, and the package audit now enforces that
exact permission set. Transfer faults, all earlier A3 contracts, public/private
source configurations, API-28 lint, builder/tvOS tests, package/privacy audit,
and repository safety pass. The production archive was not downloaded, and no
worker or UI calls the downloader yet. Evidence:
[`docs/artifacts/2026-09-04/android/a3-archive-download.md`](artifacts/2026-09-04/android/a3-archive-download.md).

Android now consumes verified archives through the shared bounded scan and a
pinned minizip-ng extraction core. Directory-relative no-follow/exclusive
writes, strict UTF-8, cancellation/progress, CRC and byte-count checks, scoped
staging cleanup, installed-content validation, and atomic activation are joined
and fault-tested. The JNI path passes on wiped 4 KiB and 16 KiB ARM64 AVDs, and
the actual private game-runtime native target rebuilds with the same graph.
This remains fixture-sized source proof; the production archive, durable worker
lifecycle, process-death injection, and Retro Rewind gameplay are still open.
Evidence:
[`docs/artifacts/2026-09-04/android/a3-archive-extraction.md`](artifacts/2026-09-04/android/a3-archive-extraction.md).

The next A3 layer now joins recovery, capacity preflight, verified download,
bounded extraction, content validation, activation, and cache cleanup behind
one unique AndroidX WorkManager foreground job. It persists phase/byte progress,
updates a data-sync notification, suppresses duplicate enqueue with `KEEP`,
retries transport loss, and exposes cancellation for the future setup UI.
Wiped 4 KiB and 16 KiB AVDs each started exactly one fixture after two
enqueues. A separate API 36 run force-stopped KartPad during active work; the
same persisted UUID restarted at attempt 1 after a plain relaunch and completed.
Package, build/lint, private-source configuration, and all underlying A3
contracts pass. A3 remains open for resumable partial transfer, production-size
installation and fault injection, Retro Rewind gameplay/mode switching, and
physical hardware. Evidence:
[`docs/artifacts/2026-09-04/android/a3-install-worker.md`](artifacts/2026-09-04/android/a3-install-worker.md).

Android's archive acquisition is now restartable rather than throwaway. A
stable version-scoped partial is prefix-hashed and appended only after an exact
HTTPS `206 Content-Range`; a server `200` fallback truncates and restarts,
while malformed ranges fail without modifying the prefix. Network loss and
cancellation preserve partial bytes, but full corrupt/oversized/link state is
reset and final publication still requires the complete pinned digest. The
actual durable-worker fault fixture persisted seven bytes, lost its process,
then resumed the same UUID from byte 7 and completed. Host response/fault tests,
both AVD page-size lanes, builds/lint, and package/privacy checks pass. A3
remains open for the official 1.86 GB server/transfer, the remaining production
fault matrix, gameplay/mode switching, and physical hardware. Evidence:
[`docs/artifacts/2026-09-04/android/a3-resumable-download.md`](artifacts/2026-09-04/android/a3-resumable-download.md).

A debug-only native installer-activity owner now proves the remaining
activity-recreation interruption independently of SDL gameplay startup. On a
wiped API 36 AVD, the activity recreated in the same PID, re-enqueued with
`KEEP`, and the original foreground work UUID started and completed exactly
once. The ADB-only fixture is absent from release builds and protected by the
privileged `DUMP` permission in debug builds. A rejected first experiment
correctly showed that explicitly recreating SDL during native window startup is
not valid installer evidence, so that path was removed. A3 remains open for
production UI observation/cancellation, the official archive/fault matrix,
gameplay/mode switching, and physical hardware. Evidence:
[`docs/artifacts/2026-09-04/android/a3-worker-activity-recreation.md`](artifacts/2026-09-04/android/a3-worker-activity-recreation.md).

The worker's production cancellation facade now passes an Android runtime
fault. A shell-protected debug installer activity cancelled one active UUID
after seven bytes; WorkManager reached terminal `CANCELLED`, the partial
remained nonzero, the worker started once, and no success marker appeared. The
same final wiped API 36 run reconfirmed nonzero process-death resume and
same-PID activity recreation. This proves the control/state boundary, not the
missing user-facing installer screen or cancellation against the official
archive. A3 remains open for that UI, production-size fault/gameplay proof, and
physical hardware. Evidence:
[`docs/artifacts/2026-09-04/android/a3-worker-cancellation.md`](artifacts/2026-09-04/android/a3-worker-cancellation.md).

Android now also has a production-owned Retro Rewind installer/status screen.
It observes the persisted unique work, shows waiting and phase/byte progress,
exposes Cancel and Retry, revalidates installed content off the main thread
before reporting ready, and is the immutable return target for foreground-
notification taps. Install start is gated on Android 13+ notification
permission and requests immediate foreground display on Android 12+. A wiped
API 36 run proved the visible actionable notification and its explicit target,
then activated the real Cancel button through
focus navigation, observed terminal `CANCELLED`, rejected false completion, and
restored the cancelled state after force-stop/reopen. The release activity is
non-exported; only the debug manifest grants privileged `DUMP` launch for the
bounded no-data fixture. A3 remains open because the incomplete Android dual-
mode chooser does not yet route normal game startup into this screen, and the
official archive, production-size fault/gameplay proof, and physical hardware
are untested. Evidence:
[`docs/artifacts/2026-09-04/android/a3-installer-ui.md`](artifacts/2026-09-04/android/a3-installer-ui.md).

The Android install worker now also fails closed on Retro Rewind version
freshness before capacity preflight or archive acquisition. The official feed
URL is generated from the sole profile; its HTTPS client bounds redirects,
timeouts, encoding, strict UTF-8, and a 512 KiB body, and numeric comparison
cannot overflow. A newer valid release produces a specific KartPad-update
requirement, while unavailable/invalid checks preserve all existing install
state and expose Retry. Host fault tests pass, and both the host JVM and a
wiped API 36 AVD reached the official service through their real TLS stacks and
reported the current pinned `6.12.5`. No archive bytes were requested. A3
remains open for the normal dual-mode route/installed fallback, production
archive and fault execution, gameplay/mode switching, and physical hardware.
Evidence:
[`docs/artifacts/2026-09-04/android/a3-version-freshness.md`](artifacts/2026-09-04/android/a3-version-freshness.md).

The existing-valid-install fault now also runs through Android's real
app-private filesystem and JNI extraction pipeline on wiped 4 KiB and 16 KiB
ARM64 AVDs. Bounded synthetic content proves initial activation, rejection of
a corrupt archive before extraction, retention of the validated active pack
after an injected activation failure, and a final atomic replacement that
is moved into the interrupted single-rollback state. Startup recovery restores
that validated pack and removes stale staging without transient state. The
fixture is debug-only; release compile and API-28 lint remain clean. This
strengthens A3 fault evidence but does not substitute for the official 1.86 GB
archive, real storage exhaustion, normal mode routing/gameplay, or physical
hardware. Evidence:
[`docs/artifacts/2026-09-04/android/a3-device-install-faults.md`](artifacts/2026-09-04/android/a3-device-install-faults.md).

Android's production same-store space probe now also has a real low-capacity
execution on a wiped API 36 ARM64 AVD. A guarded 1,121 MiB disposable filler
reduced available app storage to 4,186,030,080 bytes; the probe rejected that
against the exact profile-derived 4,327,477,355-byte requirement and the
harness confirmed zero archive cache state. The filler was removed and the
emulator stopped. This closes the on-device preflight deficit case, not
mid-transfer/mid-extraction `ENOSPC` or the production-size install. Evidence:
[`docs/artifacts/2026-09-04/android/a3-device-low-space.md`](artifacts/2026-09-04/android/a3-device-low-space.md).

The real Android installation pipeline now also survives storage exhaustion
after preflight. A temporary API 36 AVD mounted a 512 MiB ext4 filesystem at
the app-private support root; the JNI extractor wrote 117,440,519 bytes of a
validated 402,653,184-byte synthetic payload before native `IO_FAILURE`. The
pipeline removed partial staging and the previous validated install remained
unchanged. The loop image and temporary AVD were deleted, returning host free
space to 46 GiB. This closes the synthetic emulator full-disk fault, not the
official production-size install. Evidence:
[`docs/artifacts/2026-09-04/android/a3-device-enospc.md`](artifacts/2026-09-04/android/a3-device-enospc.md).

The official production-size A3 installer now passes on a wiped API 36 ARM64
emulator. The foreground worker downloaded and exactly verified the pinned
1,859,041,899-byte Retro Rewind 6.12.5 archive, then exposed and fixed two real
recovery defects: a cold worker had not loaded the JNI extractor, and Retry
double-counted an already cached archive during free-space preflight. The
patched worker reused the verified cache, natively extracted and atomically
activated 2,110,038,016 bytes, removed the archive, and validated the pinned
`Code.pul` and XML. After force-stop and airplane mode, a cold launch again
reported the installed pack ready. This closes official installation and
offline installed-content revalidation on the emulator, not Retro Rewind
gameplay/mode switching or physical hardware. Evidence:
[`docs/artifacts/2026-09-04/android/a3-production-install.md`](artifacts/2026-09-04/android/a3-production-install.md).

The complete Android Original/Retro Rewind graph now also compiles and links as
one `libmain.so`, and the Retro Rewind profile passes an explicit offline
runtime boot on the expanded API 36 ARM64 emulator. The first attempts exposed
and fixed Android product over-building, an accidental standalone-base target
dependency through precompiled-header reuse, and Windows-only section syntax in
generated Retro blob assembly. With airplane mode enabled, the app selected the
Retro Rewind translated profile, mounted 4,878 overlays, reached the branded
title and main menu, preserved its save exactly across force-stop/cold relaunch,
and did not fall back to Original mode. A base-mode control showed the wiped-
NAND system-memory warning was shared; a format-valid diagnostic empty save was
therefore used as a disclosed test precondition. This closes dual linking and
offline title/menu relaunch, not a race, production mode chooser, general
fresh-NAND creation, touch parity, or physical hardware. Evidence:
[`docs/artifacts/2026-09-04/android/a3-dual-runtime-offline-boot.md`](artifacts/2026-09-04/android/a3-dual-runtime-offline-boot.md).

A bounded follow-up now proves that Retro Rewind's native Replay path can load
the official SNES Donut Plains 1 expert card, follow the expanded course, cross
into lap 2, and reach a three-lap finish/results presentation on the API 36
ARM64 emulator. The save hash changed after the result. Running the same RKG
through KartPad's diagnostic live-controller bridge still diverges around 19
seconds even when the base-course metadata override is disabled, so that
override is ruled out and the fixture is not valid A3 acceptance. The replay's
displayed result also differs from the official card time, so timing fidelity
is not claimed. A second exact kart/default-transmission card diverged too,
ruling out Retro Rewind's Inside/Outside bike choice. Delaying fixture
consumption from countdown stage 1 to race stage 2 made divergence earlier
(`00:07.383` versus roughly 21 seconds), so that experimental timing change was
reverted. The remaining fault is still within the diagnostic RKG/player-state
boundary; a controller-driven race remains open. Evidence:
[`docs/artifacts/2026-09-04/android/a3-retro-replay-isolation.md`](artifacts/2026-09-04/android/a3-retro-replay-isolation.md).

The later simulator save-precondition diagnosis was revalidated and corrected.
Guest-address-only instrumentation showed valid Mii-library heap allocations;
with the redirected save absent, Retro populated it from the format-valid
empty base save and reached the branded title. The exact clean build then
remained alive with that byte-identical empty save and no leaderboard, followed
by six of six identical cold-launch passes. Removing the leaderboard alone also
did not reproduce the earlier exit. Those exits are transient evidence rather
than a proven save/settings defect. At that checkpoint, full first-run license
creation was still open; the controller-race fixture conclusion is unchanged.
Evidence:
[`docs/artifacts/2026-09-04/android/a3-retro-replay-isolation.md`](artifacts/2026-09-04/android/a3-retro-replay-isolation.md).

The disclosed format-valid empty-save precondition is now removed for the
fresh Retro emulator path. With `[network] enabled = false`, the runtime had
incorrectly rejected every `/dev/net/*` device before classification, including
the local Wii KD request/time and NCD services required during first-run
system-memory initialization. The common runtime patch now leaves those local
services available offline while continuing to gate only IP and SSL devices.
Two independent fresh redirected-NAND launches visibly reached the Retro
Rewind title and each created the exact 2,867,200-byte format-valid empty RKSYS
with SHA-256 `708c7a040e0cfe6cd815690e63f46d1678f17899bce0e786f7480030830f1d13`;
a cold relaunch also passed. The clean local APK passed package/privacy audit,
and the original emulator saves were restored with exact hashes after the
test. This closes fresh offline Retro system-memory creation on the API 36
ARM64 emulator, not physical hardware/controller, audio/rumble quality,
performance, or release acceptance.
Evidence:
[`docs/artifacts/2026-09-04/android/a3-fresh-save-offline-kd.md`](artifacts/2026-09-04/android/a3-fresh-save-offline-kd.md).

The controller-driven continuation now closes first license creation on that
fresh emulator state. Starting from the exact game-created empty RKSYS, an
Android InputReader-visible virtual Xbox controller selected `NEW`, confirmed
license creation, selected the existing KartPad Mii, and reached `Your new
license is ready.` The resulting 2,867,200-byte save has valid `RKSD0006` and
slot-zero `RKPD` structures, a matching core CRC-32, and SHA-256
`4b83dc4a02dd351d1e594b1c9c13ecd7530e6c80520957d4c576c46c88b0972d`.
After force-stop and a new production-chooser process, the save remained
byte-identical and slot 1 visibly displayed the KartPad license. The original
Retro save was then restored to its exact pre-test `9c6c7b52...` hash and the
clean title relaunched. This is emulator controller evidence, not physical
controller/device or release acceptance. Evidence:
[`docs/artifacts/2026-09-04/android/a3-fresh-save-offline-kd.md`](artifacts/2026-09-04/android/a3-fresh-save-offline-kd.md).

Explicit Original to Retro Rewind to Original switching then reproduced the
previously intermittent Mii exit once across eight observed pre-fix Original
launches (six base-only controls and two within the switch sequence). The crash
record showed an alarm callback had overwritten the
interrupted translated caller's callee-saved r30 heap pointer. RFL alarm
polling now runs callbacks against a private interrupt register context while
briefly suppressing guest scheduler switching. The patched build passed ten of
ten Original cold launches and a visible-emulator Original/Retro/Original
sequence; the final Original process continued through the title attract
sequence, both saves retained their exact hashes, and no new missing-target
record appeared. Fresh patch reproduction, Apple arm64 compilation, and the
strict package/privacy audit pass for local APK SHA-256
`2ba4b4acf7a395c3d810ff81c0327ad15f9bfbbcbcd76da026ec37444ff7b7d2`.
This closes the reproduced callback corruption and bounded emulator switch,
not the production chooser, controller-driven Retro race/save, trustworthy
timing, physical controller/audio/rumble, hardware, or release gates. Evidence:
[`docs/artifacts/2026-09-04/android/a3-rfl-alarm-context.md`](artifacts/2026-09-04/android/a3-rfl-alarm-context.md).

Android now has a production-owned pre-SDL mode chooser. It validates the
pinned Retro Rewind installation off the UI thread, presents Original and
Retro choices together at landscape phone density, routes an unavailable
Retro choice to the existing installer, and passes activity recreation after
a landscape flip. The exact audited APK selected Retro without a debug extra,
reached its branded title beyond 30 seconds, then cold-selected Original and
reached its distinct title beyond 30 seconds. Both saves retained their exact
hashes and no new missing-target record appeared. The production manifest
exports only the chooser; the SDL activity is private, with protected shell
access retained only in debug builds. Build, lint, four installer contracts,
release-manifest merge, and package/privacy audit pass for local APK SHA-256
`7088f683c9cc765c77a12203646af6d9ecdb13f1eb77f559b4bfdbc75e1caf94`.
This closes the emulator production-chooser/mode-selection slice, not the
controller-driven Retro race/save, timing, physical controller/audio/rumble,
hardware, or release gates. Evidence:
[`docs/artifacts/2026-09-04/android/a3-production-mode-chooser.md`](artifacts/2026-09-04/android/a3-production-mode-chooser.md).

The same production Retro profile now passes a complete controller-driven
emulator race/results/save/cold-relaunch slice. An Android InputReader-visible
Xbox-compatible virtual controller navigated the retail menus and drove Mario
through Retro Rewind's GCN Baby Park to finish stage 4. The results reported
`17:13.562`, best lap `00:19.742`, and ghost creation; advancing results changed
the isolated Retro save from SHA-256 `3c4aeacd...` to `7279ad4d...`. A cold
production-chooser relaunch with the controller already attached reached the
branded title as a new process, retained the exact post-results hash, and
accepted controller navigation back to Baby Park. The temporary controller's
explicit one-hour registration expired mid-race; the runtime recorded an
ordinary disconnect/reconnect and the same live race completed afterward.
This closes the emulator controller gameplay, race/results, save mutation, and
byte-stable cold-relaunch slice. A second visible force-stop/relaunch through
the production chooser again selected Retro, reached the branded title, and
returned to the course ghost screen. It still showed only `1/1`; read-only
inspection of the exact cold-loaded, CRC-valid save found a zero personal-ghost
bitfield and no Time Trial leaderboard timer in its only initialized license.
The retained exact pre-race save was then recovered read-only from the emulator:
the pre/post files differ by only 12 bytes, confined to ordinary race/statistic
fields plus the core CRC, with no leaderboard or ghost payload change. Both
variants of a matching packaged Baby Park RKG were rejected after visible
live-player runs diverged and remained at race stage 2; neither changed the
save.

A subsequent ordinary-controller feedback run finished Baby Park in
`02:31.465`, with three recorded lap splits and native finish stage 4. The game
reported ghost creation and showed the new result ahead of `17:13.562` in the
same-session leaderboard. Advancing results changed RKSYS from `7279ad4d...`
to CRC-valid `9c6c7b52...`, again only in ordinary statistics and the core CRC.
Inspection of Retro's actual custom-track storage corrected the earlier RKSYS-
only conclusion: Baby Park is stored under Pulsar course key `d6cac6a4`, whose
`ldb.pul` and `150/2m31s465.rkg` were written beside the already-retained
`150/17m13s562.rkg`. All three survived force-stop and a new production-chooser
process. The base game's 32-bit RKSYS personal-ghost field does not describe
Retro Rewind's expanded course set. This closes durable custom-track record
storage on the emulator. A subsequent controlled cold navigation selected GCN
Baby Park, displayed `KartPad 02:31.465` as personal card `1/2`, selected
Replay, and reached the exact `02:31.465` result with the original three lap
splits. The save, Pulsar database, and RKG retained their exact pre-replay
hashes, and the new-process console had no fatal signature. This also closes
visible cold personal-ghost reload/replay on the emulator. The same PID then
survived a forced 180-degree landscape change and a HOME/foreground cycle that
logged `onPause`, `surfaceDestroyed`, `onStop`, followed by `onStart`,
`onResume`, and `surfaceCreated`; rendering returned to the intact result and
all three persistence hashes remained exact. This closes Retro runtime
rotation/background surface recreation on the emulator. Trustworthy timing,
physical controller/audio/rumble, physical hardware, and release acceptance
remain open. Evidence:
[`docs/artifacts/2026-09-04/android/a3-retro-controller-race-save.md`](artifacts/2026-09-04/android/a3-retro-controller-race-save.md).

The first A4 touch slice now passes on the API 36 ARM64 emulator. A transparent
Canvas overlay presents KartPad's accepted phone geometry with stable
multitouch ownership, full Classic button coverage, two sticks, lifecycle
clearing, and a native short-tap latch. After removing a stale emulator display
override, Android reported a real rotated `2400x1080` application frame. The
complete `KartPadDual` runtime reached the Retro Rewind title with the overlay
visible; a touchscreen A tap advanced to Select License and D-pad Right moved
selection to the adjacent NEW slot in the same live process. The fresh build
also corrected game-runtime preparation so a dual shard graph prepares and
builds the dual product instead of silently preparing a base-only runtime. The
119,090,830-byte local APK has SHA-256
`258f80025ad0b094e577d699d785c5cb4b36a72e30e268b1cfa17ff408473b3b`
and passes the strict package audit. This closes only the first emulator
touch/JNI/KPAD slice. R visibly matches L's compact digital pill; a 1.3-second
A hold turns cyan and stays asserted after finger-up, and the next A tap
restores green/unlocked state. Android input-device hotplug now also clears all
touch state and hides the overlay while a gamepad/joystick is present. A live
emulator sequence proved visible touch, hidden-on-controller, and restored-on-
disconnect states; a second sequence began with A cyan/locked and restored it
   green/unlocked after controller connect/disconnect. Persistent editing,
   presentation controls, configurable handoff policy, right-stick status writes,
   separated X/Z geometry, and an iOS-derived consolidated KartPad menu now run
   in the exact dual APK. The in-game game-version action returns to the isolated
   Original/Retro selector; FPS, aspect, resolution, multiplayer, Retro management,
   and bounded reporting are live. Gravity motion steering now matches iOS
   calibration, dead-zone, inversion, and sensitivity behavior. Emulator
   injection proved neutral, opposite signed tilts, inversion, and preference
   restoration across process restart. The exact local dual APK SHA-256 is
   `ae96d3e2bcd340b64d9b76cb6a05059bef99b90b24ac7111d159b7d4e05f51e5`.
   Custom controller mapping now also replaces the former disclosure-only menu
   item. A/B/X/Y/Z assignments persist app-privately, occupied assignments swap
   instead of duplicating, and reset restores the iOS-equivalent direct map.
   The emulator proved a persisted A/B swap through Android InputReader and SDL:
   physical A left the Retro title unchanged as game B, while physical B advanced
   as game A. The exact clean local APK is
   `30493adced96cad0edcb9d90354596dc59550be0522735f1356758124cb8686a`
   and passes the strict package/privacy audit. This accepts only this emulator
   A4 slice. Virtual accessibility nodes, physical haptic feel, tablet and
   physical touch, game-data/save management, Mii creation, direct Wii Remote
   support, remaining menu-function parity, and physical-device acceptance
   remain open. Android Mii management now lists the live validated database,
   imports standard 74-byte `.mii` documents, stages removals, applies changes
   before SDL starts, retains automatic backups, and refuses to remove the final
   Mii. An emulator import/restart/list/remove/restart cycle returned the database
   byte-for-byte to its original SHA-256. The exact clean local APK for this
   follow-up is
   `24dbe0768dc07fa3d3cf8a27c7fcd163bff5cd53615dce5cddfc51207b580545`.
   The disclosure-only Android game-data/save row is now replaced by direct
   extracted-folder import/reimport, save-preserving removal, Retro management,
   exact RKSYS export/restore, and Mii actions. The isolated launcher validates
   RMCP01 data and presents both Original and installed Retro choices when ready.
   The emulator proved the expanded submenu, real folder picker and invalid-tree
   rejection, removal schedule/Undo, byte-identical save export plus staged
   restore/backup/restart, and Retro-to-selector-to-Original switching. The exact
   local-only APK is
   `6aa904883b174940f728b672bee971a6367dc6008d7c9837eeb7cf684e043203`.
   Android now builds a pinned Dolphin DiscIO JNI library and exposes separate
   raw ISO/WBFS and extracted-folder import actions. Disc imports validate and
   activate through app-private same-volume staging. The final APK retained both
   Original and installed Retro choices after reinstall, and an invalid document
   failed cleanly without a crash, data change, or staging residue. A positive
   full-disc import remains open because no owned source image was available,
   along with multi-controller, tablet/physical touch, and physical-device
   acceptance. The Canvas overlay now exposes 14 bounded virtual accessibility
   children with button, stick-direction, and A-lock actions. UI Automator
   resolved the live nodes and directly performed the A-lock action; its state
   became `Acceleration locked` and the on-screen A turned cyan. The exact dual
   APK for this slice is
   `35ca72fab4c2c3737f373b25e6374daa7edfc13607d23afeaa8091e09b8c3fdf`.
   Touch Control Settings now also includes iOS's live 1x--4x render selector
   and uses two landscape columns, so Render, both sliders, both switches, Move,
   and Reset are visible together. Reset now preserves the independent
   controller-hiding and C-stick preferences. The emulator exercised 2x and
   restored 1x; the exact audited dual APK is
   `0217707c7410afe19923ae868bcc058dd14d9449cf8f03b2fb4c1b60f8db931f`.
   Report a Problem now collects problem, context, and frequency answers and
   includes them in bounded share text or an encoded GitHub issue prefill. The
   emulator exposed every field/action; the test canceled without sending or
   opening anything. The exact audited dual APK is
   `539d9bf73e617c052b4439db0c017d1d5bc425288d2852a7fec6146241e78577`.
   The selector now also matches the iOS first-launch visual system with its
   diagonal navy/purple/wine background, orange mark, centered title hierarchy,
   and equal rounded blue Original and pink Retro cards. The final combined
   selector/disc-import APK SHA-256 is
   `09cdb68124a1e346a003b7c3e42b75b3f6b5f9fa2dcd1a7461500f5e57fd3204`.
   The pinned API 36 ARM64 Pixel Tablet now uses the accepted iPad sizes and
   normalized centers instead of stretching the phone defaults. A source-only
   2560x1600 run exposed all 14 accessible hit targets, kept the 280 dp R pill
   fully in bounds, and passed Vulkan, reverse-landscape, and three lifecycle
   recreations. The fixture APK SHA-256 is
   `25890fbfc3e43a247dc6ebfc6165db37a8ba857e374040229178f5c56219ae62`.
   The Controls submenu now also has persistent Player 1--4 controller setup.
   A visible two-controller source fixture proved independent assignment,
   occupied-slot replacement with the old slot cleared, and explicit clearing
   through the real accessible Pixel Tablet dialogs. A fresh runtime preparation
   and the complete translated dual-runtime build consume the production Aurora
   bridge; its audited local APK SHA-256 is
   `b41b7b3b33a9c3eec2e8a66d0a9d11e8f96d71a4be6d05e727a57fc83ca5a14c`.
   The chooser now also replaces its three legacy Android drawable glyphs with
   KartPad-owned steering-wheel, checkered-flag, and go-backward vectors that
   match the iOS selector's icon language. The visible Pixel Tablet composition
   and accessibility hierarchy pass; the final audited dual APK SHA-256 is
   `0d0dccc38878a9937a09d3b770dad16792654c1d5c86d72edafbd98710b778f7`.
   A new source-only raw-frame verifier now makes the selector visual gate
   repeatable on both canonical lanes: Pixel 6/2400x1080 and Pixel
   Tablet/2560x1600 pass exact blue/pink palette, centered equal-card, full-mark,
   label, RGBA, and gradient-direction checks. The production-gated fixture
   hook cannot bypass real game-data validation in a game-runtime build. The
   resulting audited dual APK SHA-256 is
   `2244ca5d1cf74d85d1b98279f36aa67a165e30dd3510c05612beb48a7b58da94`.
   A production-gated source fixture now also replays four real Android pointer
   IDs through the laid-out left stick, A, R, and Z controls. Both visible
   canonical lanes sustain 0.75 steering with acceleration, drift, and item
   held simultaneously, retain steering through independent button lifts, and
   empty the owner table at neutral completion. The resulting audited dual APK
   SHA-256 is
   `205abbb668872500975e734ca52f3132fb18122e80905c35211883f01b4c5967`.
   A separate real-event hit-map fixture now validates the center and near-edge
   point of all 14 controls on both canonical geometries and proves that empty
   gameplay space remains unconsumed with neutral ownership/state. The final
   audited translated APK SHA-256 is
   `7edb51da87682525093db9cedcd80d1eab795572371443d4aa4a8f857f16ac6e`.
   Virtual accessibility actions now also have repeatable phone/tablet proof:
   focus, B pulse, Move Right and timeout, A lock/state, normal-click unlock,
   four haptic dispatches, focus clear, and final neutral state pass through
   the production node provider. The final audited translated APK SHA-256 is
   `40907268f2b4047e93e8e0e7e7affacc0d02e5f84fa75a7461f81ab9b21d44b9`.
   A real Android sensor flow now also passes on both canonical layouts:
   gravity registration is required, and one injected tilt yields positive
   steering in standard mode and negative steering when inverted. The final
   audited translated APK SHA-256 is
   `79eb1ac8da137b63e9060ae08f688a63bade1fb19777a25d85330bf6d1ef0750`.
   The selector now also matches iOS's two-choice interaction: it has no
   Android-only recovery button, both cards remain actionable without game
   data, and the chosen profile resumes after the shared import flow. The
   three-dot hierarchy has owned action/section symbols on Android 10+, and a
   source-only raw-frame contract now protects all 14 touch targets, accepted
   phone/tablet X/Z ordering, tablet R width, D-pad geometry, and palette. The
   final audited translated APK SHA-256 is
   `5c0554814023e3cd80c035a5b2c21c882e2bfce511e2c780c817e6e53279eaf9`.
   Real `MotionEvent` clearing fixtures now also prove that opening the actual
   menu clears held A on both canonical emulator layouts and that sending the
   Pixel 6 to Home clears held A through `onPause`. Every case transitions from
   `0x10`/one owner to neutral/zero owners. The resulting audited translated APK
   SHA-256 is
   `760b440accaaf430b13f3346cae39632411cb53a678b288c12694059152b43b3`.
   A separate real process-restart fixture now proves per-control persistence
   on both canonical layouts: A reloads at normalized `(0.55,0.55)` and 1.25x
   size while hidden B remains absent from the virtual accessibility tree. The
   resulting audited translated APK SHA-256 is
   `254b2614f7ae17d24a1547563b77f543bafd996f0f7030a7d3cad3266d70df61`.
   The complete Touch Control Settings surface now also has a repeatable
   raw-frame/accessibility contract. Visible Pixel 6 and Pixel Tablet runs keep
   all 13 required labels and seven actions in bounds, retain native 1x as the
   default, and preserve the landscape left-slider/right-action composition.
   The resulting translated APK SHA-256 is
   `188c235d9a324a84e0fee38cc37ec192687741da4273616f83028a9ab5b8ff93`.
   A second source-only flow now executes the real Move Controls action, selects
   rendered A with a touch event, verifies its Hide/Show transition, propagates
   a 1.25x selected size, and requires Back to reopen Touch Control Settings on
   both canonical emulator layouts. The resulting translated APK SHA-256 is
   `8d4bf7f24fd411edfa1a957dada33dfd425de495bbf6a53e2ce9570493c66c40`.
   Timed A-button replay now also passes on both layouts: pre-threshold held A
   is unlocked, about 1.1 seconds produces cyan/accessibility-locked A plus one
   virtual-key haptic request, release retains the lock, and the next tap
   returns neutral. The resulting translated APK SHA-256 is
   `f970b77c37030d2f0d4eb48ed770bb7309ccd866fbae18e4d7553465f510c505`.
   The nested Display popup now uses iOS-equivalent choice labels: Original
   4:3, both wider modes explicitly Experimental, and 1x Native through 4x.
   Real Pixel 6 popup/dialog traversal passed. The resulting translated APK
   SHA-256 is
   `3a14664a60a3f656a0f46e669ef575b9f2a67d0797c099fbb3e5f08bb9ce1934`.
   The editor replay now also sends real down/move/up events, requires the
   normalized A origin to persist, and invokes the real reset confirmation.
   Pixel 6 and Pixel Tablet both clear the dragged origin and 1.25x selected
   size back to device defaults. The resulting translated APK SHA-256 is
   `8cc43a1f0ab1889caaeee4010322e48295bc5b599f36658d52d9e2b12c6cab33`.
   Evidence:
[`docs/artifacts/2026-09-04/android/a4-touch-settings-menu-checkpoint.md`](artifacts/2026-09-04/android/a4-touch-settings-menu-checkpoint.md).
[`docs/artifacts/2026-09-04/android/a4-controller-mapping.md`](artifacts/2026-09-04/android/a4-controller-mapping.md).
[`docs/artifacts/2026-09-04/android/a4-mii-management.md`](artifacts/2026-09-04/android/a4-mii-management.md).
[`docs/artifacts/2026-09-04/android/a4-game-data-save-parity.md`](artifacts/2026-09-04/android/a4-game-data-save-parity.md).
[`docs/artifacts/2026-09-04/android/a4-touch-accessibility.md`](artifacts/2026-09-04/android/a4-touch-accessibility.md).
[`docs/artifacts/2026-09-04/android/a4-touch-settings-visibility.md`](artifacts/2026-09-04/android/a4-touch-settings-visibility.md).
[`docs/artifacts/2026-09-04/android/a4-reporting-parity.md`](artifacts/2026-09-04/android/a4-reporting-parity.md).
[`docs/artifacts/2026-09-05/android/a4-disc-image-selector-menu-parity.md`](artifacts/2026-09-05/android/a4-disc-image-selector-menu-parity.md).
[`docs/artifacts/2026-09-05/android/a4-tablet-overlay-parity.md`](artifacts/2026-09-05/android/a4-tablet-overlay-parity.md).
[`docs/artifacts/2026-09-05/android/a4-controller-player-setup.md`](artifacts/2026-09-05/android/a4-controller-player-setup.md).
[`docs/artifacts/2026-09-05/android/a4-selector-owned-icons.md`](artifacts/2026-09-05/android/a4-selector-owned-icons.md).
[`docs/artifacts/2026-09-05/android/a4-selector-visual-contract.md`](artifacts/2026-09-05/android/a4-selector-visual-contract.md).
[`docs/artifacts/2026-09-05/android/a4-multipointer-replay.md`](artifacts/2026-09-05/android/a4-multipointer-replay.md).
[`docs/artifacts/2026-09-05/android/a4-touch-hit-map.md`](artifacts/2026-09-05/android/a4-touch-hit-map.md).
[`docs/artifacts/2026-09-05/android/a4-motion-sensor-flow.md`](artifacts/2026-09-05/android/a4-motion-sensor-flow.md).
[`docs/artifacts/2026-09-05/android/a4-selector-menu-touch-visual-parity.md`](artifacts/2026-09-05/android/a4-selector-menu-touch-visual-parity.md).
[`docs/artifacts/2026-09-05/android/a4-touch-modal-lifecycle-clearing.md`](artifacts/2026-09-05/android/a4-touch-modal-lifecycle-clearing.md).
[`docs/artifacts/2026-09-05/android/a4-touch-state-persistence.md`](artifacts/2026-09-05/android/a4-touch-state-persistence.md).
[`docs/artifacts/2026-09-05/android/a4-touch-settings-visual-contract.md`](artifacts/2026-09-05/android/a4-touch-settings-visual-contract.md).
[`docs/artifacts/2026-09-05/android/a4-touch-editor-flow.md`](artifacts/2026-09-05/android/a4-touch-editor-flow.md).
[`docs/artifacts/2026-09-05/android/a4-touch-gas-lock-replay.md`](artifacts/2026-09-05/android/a4-touch-gas-lock-replay.md).
[`docs/artifacts/2026-09-05/android/a4-display-menu-label-parity.md`](artifacts/2026-09-05/android/a4-display-menu-label-parity.md).
[`docs/artifacts/2026-09-05/android/a4-touch-editor-drag-reset.md`](artifacts/2026-09-05/android/a4-touch-editor-drag-reset.md).
Accepted evidence:
[`docs/artifacts/2026-09-04/android/a4-touch-overlay-input.md`](artifacts/2026-09-04/android/a4-touch-overlay-input.md).
[`docs/artifacts/2026-09-04/android/a4-controller-handoff.md`](artifacts/2026-09-04/android/a4-controller-handoff.md).

## Native tvOS work

The maintainer-owned `codex/tvos-retro-rewind` branch contains the first
independent native tvOS implementation slice: a `KartPadDual` tvOS build graph,
focus-driven setup host, Extended Gamepad requirement, Mac-side private game
data staging, official hash-verified Retro Rewind installation, and a fail-closed
artifact audit. The complete dual Original/Retro Rewind graph now compiles and
links as an unsigned arm64 tvOS 17 app, and that app passes the native bundle,
platform, dependency, symbol, privacy, and private-data audit. No Apple TV is
paired with the current Mac, so signing, installation, execution, gameplay,
performance, and save recovery remain untested. Apple TV support is therefore
not accepted. The candidate includes an original three-layer tvOS icon and Top
Shelf image compiled into its audited asset catalog. It remains explicitly
experimental in the `v0.4.0` hardware-bring-up build. The next
gate is a small outside cohort using the exact audited candidate and tester
checklist. The
authoritative scope, build procedure, storage boundary, and external-testing
gate are in
[`docs/TVOS.md`](TVOS.md).

## Current goal

**0.4.0 is published as KartPad's second stable community release.** The
`v0.4.0` tag points to source commit
`369159153bef0d045edf5cc1cf3b1b444b36a284`. Its iPhone/iPad app 0.4.0 build
15 IPA has SHA-256
`af80c2bc6fcabdb4eee84aed05254eccef76d7e6bbf83f2c7f21101168c665c8`;
its experimental tvOS app 0.4.0 build 3 IPA has SHA-256
`9ee2a9b05bff56261d4d4986eca54840e98ade8ae0abd3ac623c1f2393dcf5cc`.
The physical iPhone passed Retro Rewind 6.12.5 launch, per-control hiding, and
the editor's Back path. Exact merged-source builds, double deterministic
packages, local and fresh hosted audits, hosted byte comparison, checksums,
and remote tag/main verification pass. Physical Apple TV acceptance remains
open, so that included artifact is still explicitly experimental.

**0.4.0 Preview 2 is published.** `v0.4.0-preview.2` points to source commit
`e9fa6058ee09fff0b16481ebe4a78d61cea69c87`. Its app 0.4.0 build 14
iPhone/iPad IPA has SHA-256
`a796cd0e29bfd47d78afc50989a959803f9eff434252a3a455af85308b380fe6`;
its app 0.4.0 build 2 tvOS IPA has SHA-256
`3f8f529a93cc3f1ddfe9e9b71171ba56ead5a49ae3598c449a42f00eed6c5a9a`.
It advances the pinned Retro Rewind input and translated graph to 6.12.5, adds
a daily upstream version watcher and deterministic profile updater, and repairs
the universal iPhone/iPad three-dot menu after inherited settings refreshes.
Exact merged-source builds, deterministic double packages, hosted byte
comparison, checksums, fresh hosted audits, and the daily workflow pass.
Physical 6.12.5 gameplay and tvOS acceptance remain separate gates.
The established physical 6.12.4 iPad result is not relabeled as 6.12.5 proof.

**0.4.0 Preview 1 is published.** `v0.4.0-preview.1` points to source commit
`4d32dfac683966ea1cb4f72963deffbe936404da`. Its app 0.4.0 build 13
iPhone/iPad IPA has SHA-256
`5b959d7a6abba43db3d557bbba3dc3a1ab913650f0717cdf8600afa06fcb32c1`;
its app 0.4.0 build 1 tvOS IPA has SHA-256
`78dcdf28c947330d480fcc789f0b81b95bafe94497c56f9c26bb6249c5362df1`.
Both exact merged-source builds, deterministic double packages, local audits,
hosted byte comparisons, checksums, and fresh hosted audits pass. The Apple TV
artifact remains a physically unaccepted tester build, not a supported-platform
claim; the external Apple TV matrix is still open.

**Preview 5 is published.** `v0.3.0-preview.5` points to source commit
`8e57ac49c161ff576d6eff198ade2ee9b21f575e`. Its unsigned app 0.3.0 build 12
IPA has SHA-256
`9b7b8c586ddd04b639dda5634e72e88dc91ccefb93762f1afde6e8006d274d14`.
The exact source passed fresh native macOS and physical-iOS builds. Both local
packages were byte-identical, and the freshly downloaded hosted IPA and
checksum matched and passed a new audit. Reporter acceptance remains open.

**Preview 4 is published.** `v0.3.0-preview.4` points to source commit
`3e43c002d60378bd4975c4637a8e3a149f2d733e`. Its unsigned app 0.3.0 build 11
IPA was packaged twice byte-identically; the local and freshly downloaded
hosted files match byte-for-byte and pass checksum, ZIP, app, privacy,
provenance, signing-residue, and private-data audits. The hosted IPA SHA-256 is
`6bd4a3bd6a8582dd193093dda7471cecee2cafd7450f51ea59454329a1529b9e`.

Preview 4 adds experimental Mii import/management on Mac, iPhone, and iPad plus
an experimental macOS-only direct Wii Remote/Nunchuk pairing path and
controller preset. The exact merged-main macOS build compiles, links, packages
with Bluetooth permission, and passes audit. A real exported Mii and physical
Wii hardware remain external acceptance gates. Issue #5 now contains the
bounded tester request and remains open for results.

The preceding in-place iPad candidate preserved the complete 5,745-file,
4.8-GB KartPad Application Support/NAND tree byte-for-byte, launched, and
remained running. Earlier hands-on testing accepted Retro Rewind, ordinary
controller input, the stable three-dot button and reorganized menu,
exit/reopen lifecycle, Original Mario Kart Wii, and the existing license.
Folder-scan diagnostics and a direct Files fallback were built and
contract-tested; Preview 5 removes the intervening failure alert. The exact
Feather-signed environment remains the final acceptance gate. The release rollup is in
[`docs/releases/NEXT.md`](releases/NEXT.md).

**The provider-compatible import hotfix is published.** `v0.3.0-preview.3`
points to source commit `452af2dde3d19508a5e6ced6c03deb0e24b8b509`. Its unsigned
0.3.0 build-10 IPA, checksum, embedded release notes, provenance, licenses,
privacy boundary, and freshly downloaded hosted artifact all pass. The hosted IPA
SHA-256 is
`e839c115a97867949b16fa1c4a2a3472dce4eb3da6c69fff6f40c3eca2abbdcf`.
The build asks iOS Files providers for a local picker copy, removes only that
temporary copy after import, and scans app-folder disc extensions before
provider package/directory metadata. Issue #1 remains open for confirmation on
the reporter's exact iPad; build and audit proof are not that confirmation.

**Local Apple-to-Apple online flow passes.** Native macOS and the exact iPad
Simulator completed login, matchmaking, room formation, Luigi Circuit race
traffic, the retail online finish/results path, rating updates, and return to
the shared lobby. The accepted run exchanged more than 3,500 UDP packets in
each direction per client and consumed the complete 5,001-frame fixture. The
test-only finish trigger is documented in `docs/ONLINE.md`; public-service,
physical-device online, impairment, and external-client rows remain open.

The exact released dual-mode build also reaches production Retro WFC NAS
authentication. It then receives `61070` because the public GameSpy
gameplay-login endpoint times out. Retro Rewind's official documentation lists
the service as in testing/maintenance mode, and its status page has no live
room data. Production online acceptance is waiting on Retro WFC recovery. That
external outage does not block the accepted Retro Rewind installation, launch,
or offline-gameplay support in the current KartPad build.

The same source produced a fresh signed KartPad `0.3.0` physical-iOS build. It
was installed over the existing app on the attached iPad without
an uninstall, launched successfully, and visibly reached the Original / Retro
Rewind chooser. That is physical build, install, launch, and chooser evidence;
it is not production Retro WFC matchmaking or gameplay evidence. The latter
remains queued behind service recovery.

Two physical-iPad attempts to download the official 6.12.4 full pack then
failed identically after transfer: both device crash reports show `Thread stack
size exceeded` in `KartPadSHA256ForLargeFile`. The verifier had placed a 1 MiB
streaming buffer on a dispatch worker's smaller stack. Current source moves that
buffer to heap storage, makes download and install percentages separate, checks
Retro Rewind's official version feed before launch, and fails closed when a
newer pack requires a new ahead-of-time KartPad build. Physical build 7
established the hardware acceptance gate: its full-width dual-mode chooser was
visually accepted on the iPad, then a fresh hands-on run downloaded the official
6.12.4 pack, completed verification and installation without a crash, launched
Retro Rewind, and reached a playable single-player match. Build 8 is installed
in place without removing KartPad's data and carries the final iPad
multiplayer-guidance polish, which is validated in the exact iPad Simulator
candidate. This closes physical pack installation, Retro Rewind launch, and
initial offline-gameplay acceptance. Production Retro WFC matchmaking and
online gameplay remain unaccepted while the external service is in maintenance,
but they are not a blocker for this build.

## Goal ledger

| Goal | Status | Evidence / next gate |
|---|---|---|
| G0 Workspace/evidence | Pass | Safety audit passed; checkpoint `2f3bf40` pushed |
| G1 Inputs/pins | Pass | Full source/disc verifier passed; checkpoint `94f6e79` is on GitHub |
| G2 Baseline oracle | Pass | Translator 570/570; isolated Dolphin boot/license/menu/race/staff-ghost oracle in `docs/artifacts/2026-08-28/dolphin-oracle/` |
| G3 Host portability | Pass | Native arm64 host library/contracts pass; Darwin graph contains no Win32/x86-only link token; manifest recorded |
| G4 Guest memory | Pass | Checked Darwin path passes conformance, lifecycle, randomized stress, microprogram, ASan/UBSan; safe Mach VM feasibility probe passes |
| G5 Guest scheduler | Pass | Explicit state machine passes lifecycle/priority/VI/register tests and two deterministic million-operation runs under Release and ASan/UBSan |
| G6 PPC/AArch64 semantics | Pass | 250,227-check arm64/x86 hashes match; Dolphin oracle, sanitizers, translator 582/582, translated scalar/paired state, scheduler/callback persistence, and all 10,836 title units pass |
| G7 Native Metal frame | Pass | Real PAL wrist-strap frame visible at 60 FPS; reproducible Apple runtime patch and capture evidence recorded |
| G8 macOS boots/input | Pass | Full DOL+StaticR intro/title/menu, audible output, A/directional/1 navigation; evidence under `docs/artifacts/2026-08-28/g8-title-menu/` |
| G9 first race/save | Pass | 100cc VS standings/result/menu cycle, changed save hash, clean quit/relaunch with `Player` intact, and `Nin★sato 01:29.670` replay; evidence under `docs/artifacts/2026-08-28/g9-race-save/` |
| G10 macOS offline compatibility | In progress | Row 22 passes all 32/32 retail tracks with every cup subset complete; ghost sync, save safety, vehicles/drift, items/AI/collisions, Time Trial row 26, Battle rows 27–28, two-player row 29, four full-range keyboard/controller slots, explicit GameCube-adapter limitation, privacy-safe obsolete-service fallback, and a two-hour representative audio-continuity run also pass their stated subcases. Continue honest Grand Prix progression, three/four-player standings cycles, and subjective/final audio acceptance |
| G11–G18 | Gated | Await G10 |

## Finish-line order

The project is no longer blocked on proving that the game can run or on
packaging a public Retro Rewind preview. The shortest credible path to full
engineering completion is to close the remaining evidence gaps in dependency
order:

1. **Close G10 honestly:** finish representative Grand Prix progression,
   complete three- and four-player race/standings cycles, and perform the
   remaining subjective audio acceptance. Do not spend more time re-proving
   already accepted tracks or modes.
2. **Make G11 measurable before optimizing:** add bounded frame/pipeline
   telemetry, establish reversible cold/warm fixtures, then attack the ranked
   bottleneck. Shader-cache guesses without p99/worst evidence are not a plan.
3. **Separate automation from hands-on gates:** run long stress, save, package,
   cache, diagnostics, and Simulator work autonomously; reserve subjective
   touch, motion, audio, thermal, and live-service checks for hardware.
4. **Close targeted hardware rows:** general iPad/iPhone execution and Retro
   Rewind installation pass. Continue sustained performance, thermals, motion,
   controller feel, and broader touch-race coverage against exact builds.
5. **Finish the application boundary:** automate clean-checkout provisioning
   and complete updater/notarization infrastructure without bundling private
   data. Native WBFS import and update-in-place preservation already pass.
6. **Retest public online when available:** the complete local Apple-to-Apple
   WFC flow passes. Resume production NAS, GameSpy, matchmaking, race, results,
   and reconnect only after Retro WFC service recovery.
7. **Cut one full candidate:** rerun the full 67-row matrix, package/privacy/
   license audits, source self-build, and zero-P0/P1 review against the same
   immutable commit and artifact hashes.

The practical change in approach is to stop treating broad successful gameplay
as the scarce resource. The scarce resource is now controlled evidence:
repeatable multiplayer completion, frame-time instrumentation, reversible cache
experiments, physical-device interaction, and a reproducible legal build path.

## Known-good state

- Repository checkpoint: exact branded macOS gameplay-package source `325d5f3` is on `origin/main`. Its ignored 80 MiB arm64 package passes installed-storage, configured title/menu/live-race input, save-preservation, and normal-close checks with bundle-content hash `12e827fdaf206df3689ab0fe0b73fa7ebe20fe3827b538d8fe7c21e8ac25e3db`. Source `5781b99` adds the native data/cache/diagnostics menu without changing the gameplay core. Source `bed127f` adds the native display/audio Settings panel. Source `a5ee9fe` adds the native first-run extracted-data gate, reconfiguration action, complete fallback application menu, and safe menu-Quit route. Source `ac89225` exposes the existing in-game controller-mapping UI from that native menu. Source `c6f94b7` adds bounded technical context to the privacy-safe diagnostics report. Source `df98779` adds persistent clean/unclean session classification and capped/redacted current/previous tails; its exact package passes export, privacy scan, clean relaunch, and audit with bundle-content hash `893095ac96d66d036c61cbfa8af79b58eac3bdbf9d24b5da4fa44066111afcb6`. Source `d6e3202` adds the one-command WBFS-to-macOS self-build; its fresh extraction, 29,637-function translation, 857-step build, exact package audit/title/audio/clean-quit exercise, and byte-identical function/shard comparisons pass with bundle-content hash `bc53f9e82e2e7656d86170e59426b9ab79b4553366946b684824739fd9f0fc92`.
- Performance checkpoint: source `2cfb7e1` adds bounded p50/p95/p99/worst presentation telemetry, effective-motion FPS, pipeline queue counts, and strict summary parsing. Its exact package reaches the title, emits valid records, audits, and quits cleanly with bundle-content hash `dc6ecdca64df7a031fde00ab63472f0130674e8705bd27196483d6a0005615de`. A reversible empty-cache/warm-cache title pair quantified the cold failure at minimum 51.958 effective FPS, 83.783 ms maximum p99, 85.094 ms worst, and 20 audio drops versus warm minimum 59.963 effective FPS, 17.264 ms maximum p99, 25.966 ms worst, and zero drops. A counterbalanced one-vs-six priority-worker sweep proved that application-cache emptiness does not control all machine-level Metal/Dawn state: both policies ranged from poor to essentially perfect as that state changed. Warm Moonview profiling now rules out steady GPU saturation (12.15% union occupancy, no drawable waits) and ranks exact scalar-FP exception bookkeeping on the main thread. Direct arm64 FPSR access passed correctness and a microbenchmark but failed a paired production CPU comparison, so it was reverted. Source `2282e2c` corrects hidden FPSCR effects in ABI/liveness analysis and passes the complete semantic surface; its exact package held 60 FPS with zero audio drops, but a paired attract-race profile was CPU-neutral (candidate/control total 10.432/10.813 seconds, main thread 7.527/7.402 seconds). Correctness is retained; no speedup is claimed, and safe FPSCR-state elimination remains the ranked CPU direction.
- The first exact `2282e2c` automated macOS soak was operator-stopped after
  4:10:10 and is not row-38 acceptance. Its partial trace strongly rejects
  monotonic memory/thread growth (257,120--1,125,792 KiB RSS, negative
  post-warmup slope, 23--28 threads) and preserved the exact save, but 480
  audio blocks / 184,320 bytes were dropped in scene-transition bursts. The
  fixed 120 ms queue ceiling is now the ranked pre-soak fix. The Simulator
  application shell had also remained visibly open despite zero booted
  devices; future launches require both zero booted devices and zero competing
  visible runtime applications. Evidence:
  `docs/artifacts/2026-08-30/g11-interrupted-macos-soak.md`.
- Simulator state: no Simulator is booted. The disposable iPhone 17 Pro devices used for clean-import/rollback and scheduled-removal testing were terminated, shut down, and deleted; the preserved iPhone container was not modified.
- Buildable KartPad targets: host, memory, scheduler, semantic contracts, native subsystem smoke, translated semantic fixture, and provisional translated-frame app.
- Input profile: WBFS containing clean PAL `RMCP01`, revision 0; original is read-only. Physical keyboard holds retain the full normalized Classic-stick range. Accessibility-generated GUI taps use a bounded 0.35 level for 250 ms; acceleration/reverse retain their 500 ms gameplay holds. Physical controllers and future touch input are unaffected.
- WiiCompiled baseline: required commit/tree verified in a detached, push-disabled partial clone.
- Translator baseline: immutable upstream remains 570/570; KartPad's reproducible FPSCR lowering patch passes 582/582 on native arm64 with .NET SDK 8.0.130. Stateful scalar/paired FP, comparison, FPSCR move, and exception-control helpers now expose their hidden FPSCR reads/writes to ABI and interprocedural liveness analysis instead of masquerading as pure calls.
- Gameplay baseline: hashed Dolphin 5.0-17995 arm64/Vulkan/HLE binary boots `RMCP01`, creates an isolated license/save, reaches Luigi Circuit and its official staff ghost, and recovers to 60 FPS/VPS after shader warmup.
- Portability baseline: `kartpad_host` and its contract suite compile/link/run natively for arm64 macOS; manifest is under `docs/artifacts/2026-08-28/`.
- Memory baseline: checked/table guest memory is the accepted correctness path; evidence is `docs/artifacts/2026-08-28/g4-guest-memory.md`.
- Scheduler baseline: explicit cooperative state machine, deterministic hash `0x7287563387fb1677`, plus translated CPU-context/NI/FPSCR persistence across yields and host callbacks; evidence is `docs/artifacts/2026-08-28/g5-guest-scheduler.md`.
- Native subsystem preparation: validated Metal/CoreAudio/GameController/storage/network smoke; useful for G7 and later gates.
- Semantic subset: arm64/x86_64 complete 250,227 checks with state hash `0xccd5757c4c0643d4`; the translated fixture additionally proves VE-enabled paired invalid arithmetic still writes both lanes while aggregating causes. Evidence is `docs/artifacts/2026-08-28/g6-ppc-semantics.md` and `docs/SEMANTICS.md`.
- Full title surface: user-owned PAL DOL and StaticR translate into 29,637 functions; the native runtime executes both constructor graphs through the title and license menu.
- Original icon: editable default/dark/tinted SVG masters and opaque exports exist; 1024 px and 16 px visual QA passed. The iPhone/iPad appearance variants now pass Simulator and physical-device asset-catalog builds.
- Full mobile game app: the freshly serialized controller integration compiles all 29,065 base translated functions into an Xcode-produced arm64 `IOSSIMULATOR` app. SDL owns the UIKit scene lifecycle; the real SDL/Metal window receives the byte-identical SunPad overlay. The first physical controller takes Player 1, clearing/hiding touch by default on hardware; Players 2–4 publish independent states into their matching retail KPAD channels and disconnect clears stale input. The resolved iPhone/iPad bundle, original compiled icon catalog, privacy/runtime resources, system-only linkage, twelve-file exact snapshot, and forbidden-private-data audit pass. The latest full FPSCR-effect-model Simulator candidate has executable SHA-256 `bdb805b933e9cbce3e921dba11063af18fd6b18eaebdb36c447bbae24f71f2d8`; its exact FPS, aspect-ratio, and render-resolution menu actions all update the runtime immediately without relaunch. A normal twelve-racer iPad Simulator Luigi Circuit scene held 57.003–60.082 effective FPS across 35 retained race records and advanced 10.615 guest seconds across a roughly ten-second wall-clock bracket, ruling out a repeated-frame-only 60 Hz result for that stationary scene. Sequential iPhone/iPad launches preserve exact saves; the iPhone regression reaches live gameplay, discovers the Simulator extended controller, exposes its assignment/setup through Multiplayer, contains fitted output with opaque-black bands, opens the real system folder picker, completes a validated 2.5 GiB private import/swap, restores the old copy byte-for-byte under an injected swap failure, and recovers a stranded rollback on its next launch. With no installed game data, a native gate now runs before emulator initialization and can import the supported WBFS or extracted fixture and continue directly into gameplay in the same process. Destructive removal is explicitly scheduled, undoable until relaunch, and applied before emulator startup; its full-size regression removed only game data while preserving the exact save. A fresh post-motion source preparation completed the full 853-step serialized graph from immutable pins; its standalone Simulator link is `06238bd24c37235524375b7a12fbb0ca522b156b51936bf5be97049f5da5e500`. A Simulator-only one-worker pipeline policy corrects the observed Metal compiler scheduler crash without changing device/macOS policy. KartPad-owned configurable CoreMotion steering now compiles for Simulator and device, passes its deterministic input contract, presents an accurate Simulator-unavailable fallback, and survives the final candidate's background/foreground cycle; physical motion play remains open. Evidence: `docs/artifacts/2026-08-30/g14-full-game-app.md`, `docs/artifacts/2026-08-30/g14-full-game-simulator/`, `docs/artifacts/2026-08-30/g14-controller-multiplayer/`, `docs/artifacts/2026-08-30/g14-opaque-letterbox/`, `docs/artifacts/2026-08-30/g14-game-data-import/`, `docs/artifacts/2026-08-30/g15-native-wbfs-import/`, and `docs/artifacts/2026-08-30/g15-motion-steering/`.
- Physical mobile build: the same integrated source and all 29,065 base
  translated functions now compile and link against the pinned physical-iOS
  Dawn archive as a complete unsigned arm64 `IOS` 16.0 app. The 75 MiB bundle
  passes the strict full-game package/private-data/system-dependency audit at
  executable SHA-256
  `b02c1c94dee58526169a08e73bbbe671e6f6ee31c1870517ef244e2651e9de92`.
  A new source and build directory exposed and corrected an undercounted
  serialized KPAD patch hunk, then rebuilt both the complete Simulator graph
  and the complete physical-device graph from the corrected patch stack. The
  source verifier rejects any declared/actual line-count mismatch across the
  complete tracked unified-diff stack before a costly build begins. The final
  audit additionally requires the native WBFS-import contract and rejects
  Dolphin JIT/cached-interpreter execution-core symbols.
  The reproducible `scripts/build-ios-device-game-app.sh` rerun is incremental
  on an existing build directory. This closes fresh-directory and incremental
  full device compilation, not signing,
  installation, execution, performance, thermal, audio, or touch-feel rows.
  Evidence: `docs/artifacts/2026-08-30/g16-full-device-build.md`.

## Active risks and blockers

- The 0.3.0 menu removes the inherited Sunshine-specific 90%-clock and GMSE01
  60 FPS no-op rows, replaces remaining product-facing SunPad wording with
  KartPad, keeps Report a Problem visible, fixes the transient blank ellipsis,
  and presents Multiplayer guidance with a visible Back action on iPad. The
  pinned upstream component remains byte-identical; these adaptations live in
  KartPad's owning layer.

- The current touch-control candidate keeps the pinned twelve-file SunPad
  snapshot byte-identical while adapting two behaviors in KartPad's owning
  overlay: Classic R is a compact digital pill matching L, and an uninterrupted
  one-second A touch changes to a cyan held-acceleration state until touch-up.
  The focused Classic adapter passes. A Simulator-only end-to-end probe now
  drives the real SunPad touch-down/up targets and observes the mapped Classic
  state inside the live app: held `0x00000010`, released `0x00000000`. The full
  Simulator app audits at
  executable SHA-256
  `7c3c6a4ddda8a2d89d42e4a867dfc6c1e43aadd4635c28a2870e302e525956be`.
  Sequential iPhone and iPad visual/accessibility regressions both pass: R
  matches L, A enters `Acceleration held`, and release restores its normal
  state while retail rendering continues underneath. Each device and the
  Simulator shell were shut down before the next launch; zero runtimes remain.
  The exact updated UIKit host also compiles as an arm64 `IOS` 16.0 object with
  SHA-256
  `58df58a0577dd6c3276ec67c93bbf67955c6e1531a3912323cbb5881b72d4a55`;
  the reproducible check proves every Simulator-only test contract is absent.
  The unsigned physical-device shell and original icon catalog independently
  rebuild and pass their `IOS` package audit.

- About 14 GiB of host storage remains after private disc extraction, the full translated runtime build, and native trace evidence. Large generated products remain ignored; capacity must be checked before additional build graphs.
- Direct mobile WBFS import passes its complete Simulator integration boundary.
  A fresh no-data launch opened the supported `RMCP01` revision-0 WBFS,
  extracted and atomically activated the full 2.5 GiB/2,043-file tree,
  reproduced the accepted DOL/REL hashes, continued into retail rendering in
  the same process, accepted touch input, and reached the title again after a
  warm relaunch. The app links the narrow import graph rather than Dolphin's
  execution core; the package audit rejects JIT/cached-interpreter symbols.
  A supported physical import has completed. Injected interruption under real
  device pressure and detailed import thermals remain narrower hardware gates.
  Evidence:
  `docs/artifacts/2026-08-30/g15-native-wbfs-import/`.
- No human-only prerequisite currently blocks G0 or the independent parts of G1.
- Public Retro WFC, external-client interoperability, account, and remaining
  hands-on performance/audio/motion rows remain open and are not claimed.
- WiiCompiled's bundled `MAP.txt` may be used as an ignored local reference, but independent provenance for republishing it is not established; do not copy it into public KartPad sources/artifacts.
- The exact 2008 Classic ABI is live and the game recognizes it. A/accelerate, analog steering, D-pad, and B/reverse are proven. Three-player gameplay switches to the retail 30 FPS cadence documented by the Dolphin oracle; a complete live-input three-player race remains open.
- Two content-private three-player automation attempts rendered all expected panes and exited normally but failed to complete because the synthetic driver left the course at both the accepted `0.35` and rejected `0.18` steering levels. The `0.18` experiment was reverted; these attempts are not runtime-defect or standings evidence.
- A normal three-player stationary-player experiment registered three independent channels and held the retail four-pane 30 Hz mode for about 310 live seconds, but CPU completion did not trigger FINISH/DNF/results while every local player remained unfinished. The shortcut is rejected: row 30 still needs at least one local finisher through sustained physical input or a separately proven normal input-driving method. The same run accumulated 29 dropped audio blocks / 11,136 bytes, so three-player audio remains an explicit fail signal. Evidence: `docs/artifacts/2026-08-30/g10-three-player-stationary-timeout.md`.
- A deterministic second-race crash after returning from a three-player race was traced to a reclaimed camera node retained by the global race-camera list. A broad slot-`0xff` guard was itself regressive because three-player retail mode uses a legitimate slot-`0xff` overview camera. The corrected generated-source guard additionally requires the observed `0x55440003` scene-heap poison; the exact formerly failing sequence now preserves all four panes and reaches live second-race gameplay in the same process. Full three-/four-player standings cycles remain open.
- The opt-in RKG player fixture matches native stream expansion and the exact 240-frame countdown cadence but later diverges through the live-player path. It remains a diagnostic harness, not evidence for staff-ghost synchronization or a completed track.
- Both private disc-derived staff sets pass a strict content-free preflight: 32 files, exactly one structurally consistent input for every retail course ID `0..31`, and matched per-stream frame counts. This establishes a complete oracle inventory only; native row 22 execution remains open.
- A guarded private all-cups fixture derived from the user's own backed-up save now exposes the remaining row-22 tracks. It validates magic/version/CRC and changes only GP-completion flags plus CRC. It is a test precondition, not row-23 progression evidence; representative Grand Prix and honest unlock progression remain open.
- Two-player split-screen PRD row 29 passes: P1 completed three live-keyboard laps, both panes reached the retail finish transition, and the full standings table retained distinct Mario/P1 and Luigi/P2 rows. The successful log contains zero fixture entries; evidence is under `docs/artifacts/2026-08-29/g10-two-player-race/`. Three/four-player full races remain open.
- Time Trial PRD row 26 passes: an exact `01:38.880` personal ghost was recorded, saved, loaded after relaunch, replayed completely, and then authentically replaced by a normal live-input `05:01.445` personal best. A second fresh process loaded the replacement; evidence is under `docs/artifacts/2026-08-29/g10-time-trial-record/`.
- The initial visual interpretation of an N64 Mario staff-ghost overrun was false: the observation crossed into an automatic replay loop. A changed frame-end trace proved identical `240..8319` race segments and zero mismatches across 137,360 watched words. Ghost timing must be accepted from guest state, not wall-clock screenshots.
- Balloon Battle PRD row 27 passes: all ten retail arenas boot, and a complete 6-v-6 Block Plaza match reaches results and Main Menu. Instantaneous capture-time labels ranged from 43.2–60.0 FPS; deterministic cadence measurement remains a G11 gate and is not inferred from screenshots.
- Coin Runners PRD row 28 passes: all ten retail arenas boot, and complete 6-v-6 Block Plaza matches reach per-player results, team outcome, and Main Menu.
- Forced-exit save safety PRD row 20 passes at the stable Main Menu boundary: pre-exit, post-`SIGKILL`, and post-relaunch saves are byte-identical, and the existing `Player` license remains selectable.
- Vehicles/characters/drift PRD row 24 passes representative native coverage: Baby Mario light bike Manual completes via the bit-exact staff replay, Mario medium kart Manual completes both Battle modes, and Bowser heavy bike Automatic completes a full Balloon Battle.
- Items/AI/collisions PRD row 25 passes across complete 12-racer VS, Balloon Battle, and Coin Runners fixtures with item effects, collisions, AI, scoring/standings, results, and clean exits.
- GameCube adapter PRD row 32 passes by explicit limitation: the Darwin product deliberately uses a no-device WUP-028 stub and does not advertise raw USB adapter support; ordinary controllers remain mandatory separately.
- Four controller slots PRD row 31 passes: P1–P4 independently register as Classic controllers, channel-specific disconnect raises the correct interruption state, reconnect restores assignment, and pending/previous held input is cleared.
- G2 audio evidence is limited to emulator execution; subjective audio quality is a future hands-on row and is not claimed.
- G8 playback is proven by both the runtime's non-silent host-stream telemetry and an independent system-output loopback level capture. Subjective audio quality and latency remain hands-on G10/G11 rows.
- Audio continuity instrumentation is bounded and cumulative. Its first uncontended diagnostic sample recorded 104,960 queue checks and 40,304,256 submitted bytes with zero post-start empty observations or drops. Replay pause/resume passes with zero empty observations and a bounded eight-block pause burst. Default-output migration also passes: two live route changes caused a bounded 101-block stale-data burst, then zero further drops through 98,304 checks; the original output was restored and gameplay remained live. A separate 2:00:18 representative run completed 22 exact replay segments with zero empty-before-push observations through 2,408,448 checks; 175 stale blocks (67,200 bytes, about 0.0073% of submitted bytes) were discarded without sustained starvation. Subjective listening remains open, and this two-hour run does not replace the G11 eight-hour soak. Evidence: `docs/artifacts/2026-08-30/g10-audio-two-hour.md`.
- The fresh-process Time Trial replacement check added a normal-load sample through 49,152 queue checks and 18,873,984 submitted bytes with zero post-start empty observations or drops. It strengthens ordinary menu/gameplay continuity but does not replace pause, default-device migration, or long-session acceptance.
- The portable development app intentionally stores writable `UserData` beside its executable and is not distributable. The exact branded arm64 package contains no writable/private state, links only Apple system libraries, declares macOS 14.0, and uses the original icon. The `325d5f3` gameplay candidate reaches configured live Grand Prix gameplay and keeps durable state in Application Support and rebuildable cache state in Caches; the save and bundle remain unchanged. The native shell provides Show Data, Show Cache, bounded Save Diagnostics, a standard display/audio Settings panel, and an entry into the existing F10 controller-mapping UI. Schema-3 diagnostics identify exact build/runtime, product/renderer/memory/scheduler strategies, selected safe settings, validated data, yes/no storage health, clean/unclean session state, and capped/redacted current/previous structured tails while excluding private content. An unconfigured launch validates a supported user-owned extracted RMCP01 folder before runtime initialization, writes and reloads `dvd_root`, and reaches the game in the same process; unsupported selections preserve the prior config, and both first-run and application-menu Quit routes exit without fatal teardown. Replacing an older signed app bundle with the current package preserves byte-identical external config/save state and boots retail rendering. The public Mac command-line workflow now accepts the pinned user WBFS, performs a fresh validated extraction, emits the complete private title graph, builds/audits the app, and reaches retail rendering/audio with clean input and shutdown; its function/shard trees are byte-identical to the prior graph. Automated fresh-clone reference provisioning, native image-generation progress/resume/cache management, and public updater/notarization infrastructure remain open. Evidence: `docs/artifacts/2026-08-30/g13-exact-macos-package.md`, `docs/artifacts/2026-08-30/g13-macos-native-menu.md`, `docs/artifacts/2026-08-30/g13-macos-settings/`, `docs/artifacts/2026-08-30/g13-macos-first-run/`, `docs/artifacts/2026-08-30/g13-macos-controller-menu.md`, `docs/artifacts/2026-08-30/g13-macos-diagnostics-v2.md`, `docs/artifacts/2026-08-30/g13-macos-update-in-place.md`, `docs/artifacts/2026-08-30/g13-macos-clean-rebuild.md`, `docs/artifacts/2026-08-30/g13-macos-session-diagnostics.md`, and `docs/artifacts/2026-08-30/g13-macos-wbfs-self-build.md`.
- Moonview Highway first use sampled at 1.3 FPS and recovered to roughly 46 FPS within 20 seconds, then remained around 46–54 FPS during focused checks. Exact guest completion passed, but G11/G36 must compare a controlled warm-cache rerun and resolve sustained frame pacing before performance acceptance.

## UI reference commitment

The local `ref/sunpad` checkout remains the direct implementation reference for
the mobile touch interface and persistent three-dot menu. Its pinned twelve-file
snapshot, including controller slots and mapping, remains byte-identical. A
KartPad-owned layer adds product-specific Multiplayer, motion, reporting, game
data, and display behavior without modifying that snapshot.

The current runtime applies aspect ratio, render resolution, FPS visibility,
touch-layout editing, reset behavior, held-input clearing, and four stable
controller slots in process. Original 4:3 and bounded 16:9 clear to opaque
black. The Game Data & Saves flow validates, stages, swaps, rolls back, and
removes private data without touching saves. Dynamic fill remains experimental
because it can expose the game's overscan or scratch area.

The app boots, races, backgrounds, resumes, and preserves saves on accepted
iPhone and iPad builds. Broader touch-driven race coverage, physical finger-drag
ergonomics, additional controller and motion calibration, sustained performance
and thermals, and subjective touch/audio acceptance remain open. Evidence:
`docs/artifacts/2026-08-30/g14-simulator-shell/`,
`docs/artifacts/2026-08-30/g14-full-runtime-link.md`,
`docs/artifacts/2026-08-30/g14-full-game-app.md`,
`docs/artifacts/2026-08-30/g14-full-game-simulator/`,
`docs/artifacts/2026-08-30/g14-controller-multiplayer/`,
`docs/artifacts/2026-08-30/g14-opaque-letterbox/`,
`docs/artifacts/2026-08-30/g14-game-data-import/`,
`docs/artifacts/2026-08-30/g14-ipad-current-race-profile.md`,
`docs/artifacts/2026-08-30/g15-native-wbfs-import/`,
`docs/artifacts/2026-08-30/g15-motion-steering/`,
`docs/artifacts/2026-08-30/g15-touch-modal-input-clear/`, and
`docs/artifacts/2026-08-30/g15-touch-layout-editor/`.
