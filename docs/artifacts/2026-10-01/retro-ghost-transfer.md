# Retro comparison ghost transfer, 1 October 2026

Issue [#295](https://github.com/chrissotraidis/kartpad/issues/295) has affirmative
Original export acceptance. The remaining request includes Wii courses played
in Retro. This pass extends the existing ghost menus with a separate Retro file
collection; it does not replace the Original license/downloaded-slot path.

## Source contract

Read the installed expanded v3 `ConfigRT.pul` and `ConfigCT.pul`, including their
English BMG labels. Exclude battle and alignment records. The pinned 6.12.8 pair
resolves 304 race tracks, 341 base/variant entries and 1,364 mode destinations.
Wii Luigi Circuit is expanded ID `0x158`, with CRC folder `95ab4053`; the RKG's
retail course field does not identify this destination.

Both mobile menus require an explicit track, variant and mode (`150`, `200`,
`150F`, `200F`). The destination is the shared managed NAND collection
`shared2/Pulsar/RetroRewind6/Ghosts/<CRC>/<nonzero variant>/<mode>`. It has no
license component. Neither Retro RKSYS profile, Original save, leaderboard,
favorite, trophy, rating nor identity is a transfer destination.

The catalog identity detects changed picker selection. Pending imports also
retain the exact RT/CT bytes and compare them before cold-launch application;
the identity is not an authentication hash. A complete staged file is renamed
into place without overwriting an existing entry. A completed publication followed by
interrupted request cleanup is retryable. Failed requests remain cancellable.
Exports preserve the complete validated input bytes, including bounded trailing
compressed padding. Seven of the retained 373 expert files have such padding.

The independent review caught a native path constraint missed by checking the
filename alone. Eight hexadecimal digits plus `.rkg` fit the 12-byte filename
limit, but a nonbase feather-mode full path can reach the 64-byte IPC buffer and
truncate. New comparison filenames therefore use six digits plus `.rkg`, with
collision checks and an explicit full guest path below 64 bytes. Existing files
outside those native path limits are excluded from the export selection.

The importer rejects duplicates, the bundled expert's stored RKG CRC, crowded
folders (37 entries), symbolic-link redirects, malformed data and stale pending
requests. The native header predicate permits year 0–99 and month 0–12;
zero dates are valid. Shared RKG validation now enforces those upper bounds
alongside its existing checksum, length and bounded Yaz/input checks.

## Checks completed locally

- Strict warnings and ASAN/UBSAN on the synthetic catalog and transfer tests.
  Hash-verified private pinned configs pass all 1,364 full-path selections.
- Filesystem tests cover all four modes, nonbase variants, compressed and
  uncompressed exact round-trip, unchanged save/leaderboard stand-ins,
  duplicates, filename collisions, completed-publication retry, corrupt/stale requests,
  expert exclusion, capacity and symlink guards.
- All 373 retained Retro experts and 64 Original staff ghosts pass the stricter
  bounded RKG validator under ASAN/UBSAN. Their bodies remain private.
- The production JNI runs in a real JVM: catalog labels, filenames and support
  paths with supplementary Unicode survive both directions. Import, export,
  cancellation, stale selection and input-size rejection pass.
- Apple Foundation tests execute the shared manager's catalog conversion,
  stage/apply/export, pending Original conflict, duplicates and cancellation.
  Existing Apple identity and Android save/identity/rating tests remain passing.
- CMake registers Original ghost, Retro catalog, Retro transfer and Apple manager
  tests. Their focused five-test run, including existing Apple identity, passes.
  The existing shared-runtime workflow now runs the portable tests on Linux and
  the actual JNI/Apple manager contracts on macOS.
- The actual empty Android debug app builds and passes repository and PadMint
  content audits with zero game functions. It has a new pack fingerprint; no
  compatibility check is bypassed.

Private config/RKG bodies, translated code, game packs and app-data snapshots
remain local. Retained Pulsar source establishes the architecture; its exact
correspondence to all shipped `Code.pul` behavior remains unverified. Native
evidence below covers the specified destination and control replay.

## Historical build and pack replacement

These first build receipts predate the cold-config and publication fixes. The
corrected artifacts used for native acceptance are recorded below.

The actual empty Android debug APK builds with SHA-256
`73db23ce8291b13eb634facb994cbb9b011ed0b70f495fa1053d37d11450cad8`.
The unsigned empty iPhone IPA builds with SHA-256
`41520a4eae8340c32d2a68f45cbc9214361a141227a152664df3790623445336`.
Both pass repository and PadMint content audits with zero game functions.

The normal Android CLI builds the compatible private pack from the retained RVZ:
all 208 compile/link steps, app-state checking and packaging pass. Its private
library is 133,639,008 bytes, SHA-256
`fd2ba155f0126edc556fc681b28e064af35d7817ea58fb220ac7199879cf8ed9`.
It has interface fingerprint
`83a924cefb3f8ac6674cfa47bd5f4fffed808ed080a13fdd246bb96424a92c47`.
The actual app requests that new pack and accepts it through the system picker;
installed bytes match, and the pre-existing test-license save hash is unchanged.
Native Original startup reaches the game overlay. This is not a race completion
or iPhone gameplay result.

The owned checkout is `codex/retro-ghost-transfer`. Draft PR #375 targets main;
#372 and #373 are merged.
Public translator/runtime pins stay unchanged. The preserved `bltl` source
candidate remains committed on the owner fork at `1e55229d7f8d`; for the normal
builder's source-pin guard, its identical 33 lines are applied over local
translator HEAD `9d563f98953c`. Do not stage that working change with this feature.

## Historical native failures and their correction

The official Android installer downloaded and validated 6.12.8 successfully on
the owned API 36 emulator. Before the fix, its immediate first game launch
reproduced an initialization fault: the extraction worker loaded `libmain`
before Activity exported app-storage paths, caching an empty config. Native diagnostics reported
an overlay rooted at `/system/bin/RetroRewind6` and no DVD root despite the
correct app config. Force-stop and cold launch reached a stable Retro title.
An early Application context-path export and one guarded cold config reload
correct this boundary. The permanent actual-header early/late initialization
regression passes; same-process post-install acceptance is recorded below.

The real Retro ghost picker reached the explicit Wii Luigi Circuit / 150cc
selection and validated the chosen staff RKG. Before the publication fix, it
failed safely because Android SELinux denied `{ link }` on app data. No pending import or comparison
file was created, and Original plus Retro save hashes remained unchanged. The
hard link was replaced with atomic exclusive rename:
`renameat2(RENAME_NOREPLACE)` on Android/Linux and `renamex_np(RENAME_EXCL)` on
Apple. The updated ASAN/UBSAN transfer and production JNI tests pass; corrected
native stage/application acceptance is recorded below.

The first two focused PRs are merged: #372 at `be68ed1f`, and #373 at `ae83d0fe`.
The feature is retained as draft [PR #375](https://github.com/chrissotraidis/kartpad/pull/375),
targeting main. Runtime source `bf31f33a`, including the Original format fix, has
passing Linux boundary, macOS mobile-bridge and maintenance-receipt hosted checks.

## Corrected build receipts

Build source `10be3756` contains early Android application storage setup, a single
cold-launch JNI config reload, atomic exclusive publication and the permanent
actual-config-parser regression. Linux boundary, macOS mobile-bridge and
maintenance-receipt hosted checks all pass on that commit and historical receipt
source `1d00651f`, which changes documentation only. The following corrected
artifacts and native checks use runtime code built from `10be3756`.

- Empty Android debug APK SHA-256:
  `17234c28be8fd9feb8e42e70ed5bf653d3375b11dabab58fcf6ea6afc8f8d59f`.
- Empty unsigned iPhone IPA SHA-256:
  `b2e613a5d66d6fb68deaccd554b1ad8db63bc7987d5937d51d2c309957aa5354`.
- Both actual builds pass repository and PadMint 0.2.8 content audits with zero
  game functions. The iPhone result is a build, not physical UI/gameplay proof.
- The matching normal Android CLI build passes all 208 compile/link steps,
  state checking and packaging. Private pack SHA-256:
  `95e73526636267288fd61f2ced4982fd112111f2c66099f3bf529cc23abfab97`;
  133,639,008 bytes; interface fingerprint
  `003613b0048272855a7862a6c87054d1f2895e65f899be9b9d6a845d75ce7adc`.
- Real system-picker replacement accepts those bytes and preserves the existing
  Original save. Fresh code and its changed header fingerprint were rebuilt;
  no compatibility guard was bypassed.

For the targeted immediate-install regression, the owned installed Retro
directory and save/config snapshots were preserved privately, and only its
config-root line was removed. The retained official ZIP was seeded into the
normal verified archive cache. The actual worker revalidated and installed 6.12.8;
this second run proves cached installation, not another network download.
The preceding run already covered the actual network download. The primary
checkout remains unchanged by status inventory.

The corrected targeted post-install launch keeps the worker's process ID `9937`
and reaches the Retro title. Native diagnostics load the real app config with
both `dvd_root=GameData` and `retro_rewind_root=RetroRewind/RetroRewind6`, activate
the canonical Retro overlay and its save redirect. No force-stop or process
replacement intervenes between installation and game start. This passes the
reproduced startup boundary; it is not a full Retro race or service result.

## Native transfer, discovery and replay

On the corrected Android app and matching pack, a real system document picker
import of a retail staff ghost into Retro Wii Luigi Circuit / `150` stages
`PendingRetroGhost.bin` at 351,352 bytes. Restart Now performs cold application,
clears the pending request and publishes
`shared2/Pulsar/RetroRewind6/Ghosts/95ab4053/150/fe524d.rkg` with bytes matching
the selected source, with SHA-256
`30c4ec21c2c8324c6180ef3e806df10a36ce14b1c641494acfb40fef911d5ed2`.
The cold ghost application runs in process `10694`, distinct from process `9937`
used for the earlier same-process installer/startup check.

The native comparison list discovers the import as entry 1/2, `Nin★sato`,
`1:29.670`. Entry 2/2 is the distinct bundled expert, `Agent`, `1:13.114`.
Their stored RKG CRCs are respectively `7CFE524D` and `A8CB6941`; the import
does not replace or duplicate the expert.

Both the Original and current Retro `rksys.dat` retain SHA-256
`6d58f798e3669b26c63e304525d53ef6ae97117901ad9dc430bdfcedf5e9c419`
after staging, cold application and replay. This passes the native transfer
and save-preservation boundary for this destination. Native navigation creates
`ldb.pul` in the shared ghost collection; these checks do not claim that
gameplay leaves leaderboard or settings files unchanged.

The imported retail staff replay diverges off course on lap 1 and remains there
at `01:38` and later. Replay correctness therefore fails this acceptance gate.
As a control, Watch Replay of the matched bundled expert completes all three
laps at exactly `1:13.114`, with splits `24.465`, `24.415`, `24.234`. This narrows
the failure to the imported replay case without establishing its cause or
proving arbitrary or cross-mod RKG replay compatibility. The control expert has
SHA-256 `a1b95be407f1ef65158a4604b992a651218d35a989783c0eda30fb326fba253c`.
Native captures remain ignored under `work/retro-ghost-transfer/native-*`; no private replay bodies or
app-data snapshots are published.

Real SAF export selects `fe524d.rkg` and saves a new document. After the export
completion dialog, readback is 2,016 bytes with the same `30c4ec21…11d5ed2`
SHA-256 recorded above. Both existing saves remain unchanged.

A controlled Retro-compatible fixture changes only the exact bundled expert's
year metadata from 24 to 25 and recomputes its RKG checksum. Driving inputs,
vehicle, drift, transmission, lap times and Mii remain identical. Production
validation passes. Its checksum is `9BC5DFBA`, and SHA-256 is
`60df82808ee26b640e983495174fccd6a6cfeed0d09309d457f86e75540b04c4`.
The real SAF import and cold application add `150/c5dfba.rkg` with those exact
bytes and clear the pending request. The native list grows to three entries.
The two `Agent` entries have equal comparison keys, so their order cannot
identify the imported file. Watch Replay of both entries 2/3 and 3/3 completes
all three laps at `1:13.114`, with the same three splits. This covers the
controlled imported file without guessing its list position. Both saves retain
their preceding hash. This is a metadata-only test control, not evidence that
an arbitrary Original ghost is compatible with Retro physics.

## Normal iOS player build

From source `1d00651f`, the normal CLI uses the corrected empty IPA, the retained
RMCP01 revision-0 RVZ and a fresh iOS pack cache. It reuses and revalidates the
existing extraction; this does not measure fresh extraction. At four jobs,
translation covers 29,637 base and 4,102 Retro functions in 78.10 seconds.
All 208 native steps, the pack-state check and packaging pass. Native compilation
takes 368.471 seconds, including 0.459 seconds for linking; total CLI time is
456.794 seconds. These are one-machine measurements, not a performance gain.

The private unsigned personal IPA is 64,373,852 bytes, SHA-256
`581536f99fa923ec421b12e71ee5fb9ede4721733bd074e0e29323a72fdb1870`.
ZIP CRC passes; all 26 original empty-IPA entries stay byte-identical, and only
the private ARM64 game dylib is added. That pack is 142,163,504 bytes, SHA-256
`b9131293a9e348d87f70d8aded98929b19372eb39a4952b4e4aa3017faa7a684`,
with interface fingerprint
`eaba6fa29aa44f5f8734208e8405a3a0fa6917bf8fb2d30d5aeb9afb14e89fb3`
present in both app and pack. The exported data contains 2,043 files totaling
2,685,875,808 bytes, each identical to its validated extracted counterpart;
DOL/REL identities match the profile. Public pins stay unchanged. Private
packaging and signing preparation do not establish installation or gameplay.

## Original native transfer regression before format correction

On the startup-corrected Android app and pack, the real SAF picker imports the
retail Luigi Circuit staff ghost into Original license 1. Cold launch replaces
only the downloaded comparison slot and its presence/checksum metadata. The
entire resulting save is byte-identical to production `Import` applied to the
retained baseline: 1,923 expected changed bytes, zero unexpected changes.
Personal-best and unrelated save data are preserved; the Retro save stays
byte-identical. Original save SHA-256 changes from
`6d58f798e3669b26c63e304525d53ef6ae97117901ad9dc430bdfcedf5e9c419` to
`ff6cd93c56e8cd851d2cfb63a1924af0598f641ff908719af7c0e293b38b3b00`.

The native list discovers the downloaded entry separately from the built-in
staff ghost. Real SAF export produces 2,016 bytes, SHA-256
`3abf0627493ae51ca0b6739cd3ee00fa2c1e62159213b0688d9558c3812bbf66`,
exactly matching production `Export`. Unlike standalone Retro transfer,
Original comparison import intentionally normalizes staff type 37 to downloaded
type 7 and recomputes its CRC (`dac24284`); source-file identity is not expected.

Before the format correction, replay acceptance fails: the imported downloaded
entry remains stationary at the start line for over 60 seconds with responsive
pause controls, while the same built-in staff replay moves normally. The format
mismatch and its correction are recorded below.
File transfer, save preservation, native discovery and export pass; this does
not establish downloaded replay correctness. The narrower translator patch has
no matching instruction sites in the retained Original DOL/REL executable
sections, so it supplies no direct explanation for this failure.

## Original downloaded replay format correction

Commit `bf31f33a` corrects a native boundary exposed by the control above.
Original staff replay decompresses its `.rkg` before setting the race ghost;
Original downloaded replay copies the saved slot directly and consumes the
input table at offset `0x88`. The earlier importer left the compressed
container there. Its apparent stream counts were `0 / 1872 / 22881`, giving
an empty acceleration stream. Import now uses the existing bounded validation
and Yaz decoder to store the expanded native slot, clears compression, retains
recorded inputs and metadata, assigns comparison type 7 and computes the full
slot checksum. Retro standalone transfer continues to preserve source bytes.
The regression fails before the change and passes under ASAN/UBSAN afterward.
Real staff inputs produce native counts `59 / 1030 / 4` without changing their
expanded bytes; Retro's exact-byte mode/variant checks still pass.

Both corrected empty apps pass repository and PadMint 0.2.8 content audits.
Android APK SHA-256 is
`7f11e645ac0d3e614d9882bbe7f73caa1103aa0d126feff6735069423f6b0fb1`;
its matching normal-CLI private pack passes all 208 native steps and the state
check, SHA-256
`9bc3246c7e25ce5fcdd91a5e269eb8eb86f5c7e807a3088c08ba81e75e64af08`.
Interface fingerprint is
`a623451d48192e9518d048a7c0baf69bdf22903e116e30c213b53d90870fd381`.
In-place installation preserves all 402 quiesced backup files byte-for-byte
before activation. The app correctly rejects the prior incompatible pack;
the real SAF picker accepts the newly matching pack with exact readback hash.

Repeating the real compressed-staff import yields a save exactly matching
production `Import`, SHA-256
`2361b5be3bd1005813370d9314cd6c315f7651c65cdb8df45dcc4203f118467d`.
Replacing the earlier downloaded slot changes 2,127 expected bytes with zero
unexpected changes. Real SAF export is now a native uncompressed 10,240-byte
RKG, SHA-256
`5fa99ef00a532521cb9a78b29c3381e3be4f9f1be60ad8152e999a76c068534a`,
CRC `870c707e`, exactly matching production `Export`. The selected downloaded
entry now accelerates and drives through Luigi Circuit in native Watch Replay.
This resolves the reproduced stationary-start failure; the observation is a
replay segment, not measured completion time or arbitrary-ghost acceptance.

The corrected publishable empty iOS IPA SHA-256 is
`afffc5cc4558cd026f54a75695a8f9771913c5b254ed742c8cc235e6b3700bc0`.
Its matching private personal IPA is
`b7d63f548493f0c6fa100a37beadfa63b563b7ada3b206534f60971c89c8e100`,
with game dylib
`799b8219ec1d5509282ba55a8cf5b18f266e1d959f6a8661eab8cc8463f6aee0`
and interface
`1ad96f44c101b5772da0dfe2c944715cc4184b24ba45b846cc473c6eb7315a37`.
All 208 native steps complete and 2,043 exported files match validated data.
Our incremental validation recipe initially omitted the normal publishing
script's mandatory `strip -x`. The unchanged state guard rejected local
compiler exception metadata. Applying that existing step to a preserved app
copy and rerunning the normal CLI reuses native objects (`no work to do`) and
passes validation/package/export. No state guard was changed or bypassed.
Separate private signing passes deep/strict verification and preserves code
sections and retained entitlements. No iPhone installation was performed:
KartPad and a historical test runner were active, so device ownership remains
an external gate. Old artifacts, symbols and backups remain preserved.

## Corrected Original race control

A confirmed cold launch of `dev.kartpad.android`, followed by direct Solo Time
Trial rather than Watch Replay, renders Mario, Luigi Circuit and the countdown.
Immediate acceleration moves Mario away from the start line with the course
still visible at `00:06.984`. This passes a short race/input regression on the
corrected candidate, not a full race or sustained rendering gate.

A separate longer observation develops a white scene while the timer and
minimap continue updating. It appears after replay's Start Race and also during
a longer direct Solo observation, so it cannot yet be attributed specifically
to replay transfer. Source review finds no import or renderer-reset call in the
bounded transition handlers. A matched baseline and first-white-frame capture
are needed before changing renderer behavior. Both saves remain byte-identical
after quiescing the app: Original `2361b5be…18467d`, Retro `6d58f798…e9c419`.

## Historical acceptance after the 6.12.8 checks

Issue #295 remains open and PR #375 remains draft. Native custom-course and
nonbase-variant import/export, the other three modes, and arbitrary/cross-mod
replay correctness remain open. Original transfer/readback/export, downloaded
replay movement and the short cold Solo race segment pass after correction.
Longer Original rendering stability, iPhone picker/native acceptance and
physical-device gameplay remain separate gates. These receipts do not announce
an app release or shipped menus.

## 23 October integration with current main

Merged main `d136cd60` into the draft. Android's soundtrack import and Retro
ghost export had both assigned request code `4322`; soundtrack import keeps
that published code, while Retro ghost export/import use `4323`/`4324` and
separate result handlers. Apple document-picker cancellation now clears both
the Retro ghost selection and the soundtrack-import flag.

Independent review also found that the existing Apple save-restore picker did
not attach its delegate. Completion/cancellation therefore left a stale save
selection that could capture a subsequent ghost import. Separate commit
`f30dc179` attaches the delegate only to the save-opening picker; export pickers
keep their existing behavior and do not receive import callbacks.

Validation on the merged source passes:

- Four ghost Python tests, including production JNI import/export and Unicode,
  Original save preservation, and a new request-code uniqueness check. Injecting
  the original collision makes that regression fail.
- Catalog, Original/Retro transfer and early/late Android config tests under
  ASAN/UBSAN; Apple Foundation ghost and existing player-identity contracts.
- Seven existing Android/iOS document-picker contract tests and Android
  `:app:compileDebugKotlin` with the verified locked dependencies. The first
  Kotlin invocation lacked the required dependency-root environment variables;
  the configured invocation succeeds.
- The new Foundation harness executes the production picker methods with small
  UIKit stand-ins: save completion/cancellation followed by Original/Retro ghost
  import, music cancellation followed by ghost import, and export delegate
  isolation pass. It reproduces the missing delegate on unmodified main and
  passes with the standalone save fix. This checks callback routing, not UIKit
  presentation or device behavior; the six existing iOS picker checks also pass
  after the fix.

At that point, these were source and host checks. The earlier native receipts
used Retro Rewind 6.12.8 and did not establish acceptance on current 6.13.4.
Current-pack native transfer/replay, custom courses, variants, the other modes,
sustained Original rendering and physical iPhone picker/gameplay remained open.
PR #375 stayed draft and issue #295 stayed open; that integration created no
release.

Later on 23 October, merged main `46dc3535` after #506–#508: the standalone
save-picker fix, bounded Mii reads with Apple picker CI, and Android diagnostic
session labels. The only conflict was the shared picker harness; main's newer
version was retained and passes with this draft's Retro path enabled, including
the Mii read bounds. The six existing iOS picker contracts and production
Android `:app:compileDebugKotlin` also pass. Ghost storage and replay behavior
were unchanged, and the native/device acceptance gates above remained open.

## 23 October validation before device testing

Two additional defects were reproduced and fixed in `b08301af`:

- If an exclusive rename published a comparison but directory synchronization
  failed, the next attempt previously cleared the request without retrying that
  synchronization. Retries now retain the request until synchronization succeeds.
  Injected directory-only `EIO` reproduces the old false success and verifies
  repeated failure followed by exact-byte recovery under ASAN/UBSAN.
- Apple license edits used a duplicated pending-change check that omitted Retro
  imports. They now use the existing aggregate check. A valid synthetic license
  demonstrates that rename is blocked without side effects while a Retro import
  is pending, then succeeds after it completes. The old manager fails this test.

The optional private-pack checks now recognize both 6.12.8 and 6.13.4 config
hashes. The retained 6.13.4 archive matches the builder profile's SHA-256
`586b929de36018e5fc3f7ee73b0aba407730d38470d7a54b8a455dca14be7002`;
both configs and all 394 extracted experts byte-match that archive. No config,
ghost body, game pack or player snapshot is included in this PR.

`scripts/test-retro-ghost-catalog.py --pack-root <private-RetroRewind6-directory>`
passes with strict warnings and ASAN/UBSAN:

- 316 tracks, 362 track/variant entries and all 1,448 mode destinations pass
  catalog/path validation and stage/apply/export in fresh temporary storage.
- All 394 experts validate. A date-only comparison of each preserves driving
  inputs and round-trips exactly; importing the unchanged bundled expert is
  rejected. Coverage includes 46 nonbase experts and seven padded files.
- Saves and leaderboard sentinels remain unchanged after every transfer.
  Expected expert counts and exact catalog coverage reject incomplete packs.
- The actual experts cover 362 destinations in `150` and 32 in `200`.
  `150F`/`200F` and custom nonbase variants retain synthetic coverage; there are
  no matching real experts in this pack. These are transfer checks, not replay.

The default script also runs a fully synthetic 40-destination pack test in CI.
The expanded real-JVM JNI checks cover compressed/uncompressed transfers across
all four modes, a Retro variant and a custom course; invalid selectors, null or
oversized inputs, changed configs, cancellation and save/leaderboard isolation
pass. Production Android Kotlin compilation passes.

A deterministic temporary parser stress run (seed `0x37520261023`) completes
7,388 catalog cases and 25,784 RKG cases, including 12,800 checksum-repair
attempts, without ASAN/UBSAN findings. This checks bounded parsing and memory
safety, not replay physics or native game acceptance.

The normal iPhone no-game-code build completes against the actual UIKit SDK,
including the overlay and shared manager. Its app content audit and PadMint
audit pass with zero address-named game functions. Unsigned IPA SHA-256:
`583314c3c310cab8bbbc0bccdf34b63743ff06ee841ab5e795379c03a1cfc782`.
This candidate at `b2be86f3` was rebuilt with the final import wording; its
configured and embedded pack fingerprint both match the current source:
`28b128f965135ce96b8f503ca19ab195e419b7a4e42e9dad412b9ab0979f49b9`.
The draft differs from the pinned 0.8.5 release, so it is not a release-qualified
artifact. Nothing was installed on physical hardware or released.

The matching private iPhone game pack completes all 208 native build steps,
passes the shared-state check and resolves all 130 app imports; its other 52
imports are supplied by system libraries. Pack SHA-256:
`2fbabe7cc694be263d7ef243d6befc89232000ef062189af15806e86070a6e93`.
Normal personal packaging preserves all 22 original app payload files exactly,
adding only the game library. Private unsigned IPA SHA-256:
`bf176f582a286a954e85e858c9c1dc6a792ba365237612bdfb881eaef1c42d19`.
This resolves build/import/fingerprint validation; installation and full-game
Apple transfer/replay remain unverified.

A focused XCUITest on a fresh iPhone 18 Pro / iOS 27.0 Simulator executes the
exact production picker-presentation helper with real UIKit. Tapping the alert
action opens the system picker; Cancel reaches the delegate, clears the mode
and returns to an interactive root controller. The suspected presentation race
did not reproduce, so no presentation change was made. This is a focused UIKit
check, not full KartPad picker or game acceptance. The dedicated Simulator was
removed after retaining the test source, log and result bundle privately.

Both mobile import confirmations now ask for a recording from the same Retro
version, track, variant and mode, and explain that transfer does not convert
ghosts between games or modes. Matching-recording replay remains an acceptance
gate; cross-game conversion is outside this byte-preserving transfer feature.

### Android 6.13.4 native transfer and control replay

A fresh, isolated Android emulator runs the final clean-source `b2be86f3`
app with its matching private game pack. The no-game-code APK passes repository
and PadMint content audits; SHA-256:
`36d8c88c7139ad63fa337fa7b41139662bf8904ada5fae7e9363ec7683d06a7a`.
The private pack completes all 208 native build steps and passes its shared-state
check; SHA-256:
`c1ec53c593efae0b432859c2353de6d68a245d17801d9a19cc1dd7b31e7effa1`.
App and pack fingerprint:
`ec0762ae5aebba5bc294023a3f6b511ce10131fa753657549c2370d47684461d`.
The actual system picker imports the pack, and installed readback matches.
Retained, verified game files were copied into the fresh fixture; this does not
validate the game-data installer or first-time player setup. All 19 NAND/config
files remain exact across the final app update.

For Wii Luigi Circuit / base variant / 150, the actual system picker imports a
1,376-byte comparison derived from the matching bundled expert by changing only
the valid date and checksum. The 1,552-byte expanded driving input is unchanged.
Staging leaves both initialized saves and the original expert exact; the
comparison is absent until restart. Restart Now followed by Retro launch changes
the process, consumes the pending request and publishes
`Ghosts/95ab4053/150/c5dfba.rkg`. Native system-picker export returns the exact
1,376 bytes, SHA-256:
`60df82808ee26b640e983495174fccd6a6cfeed0d09309d457f86e75540b04c4`.
Both saves and the bundled expert remain unchanged through export. The game's
native list discovers two entries with the expected name and time. Because the
imported control and bundled expert have identical list labels, both distinct
entries (`1/2` and `2/2`) were selected through native Replay and watched to
completion. Both finish in `1:13.114`, with laps `24.465`, `24.415`, `24.234`.
Selection, Replay-menu and result screenshots plus recordings remain private.
This establishes replay of the matching date-only control on this one destination;
it does not establish arbitrary downloaded-ghost or wider mode compatibility.

Save preservation is scoped to transfer/export, before entering native replay
menus. Native navigation/replay subsequently changes one Retro save byte at
`0x5688` (`0e` to `00`) plus its four checksum bytes; the checksum remains valid.
The retained save-layout source calls that bitfield unknown, so this observation
does not establish its semantics or whole-save identity after replay. Original
save data remains unchanged. The game also creates a 4,544-byte `ldb.pul`; its
44 records are inactive and its trophies/favorites are empty. This is consistent
with the retained Pulsar source's missing-file initialization path at commit
`93ba8c8a`; exact correspondence to the shipped `Code.pul` remains unverified.
Quiesced readback confirms these changes, the original expert and imported file
remain exact, and no additional RKG was created despite the result banner. The
dedicated emulator was shut down; its fixture, before/after files and logs remain
private for reproduction.

Wider native mode/course/variant import/export and matching-recording replay,
sustained Original rendering, full-game Apple transfer/replay and physical-device
picker/gameplay remain open. Earlier native receipts above describe 6.12.8; this
section records the narrower current 6.13.4 check. PR #375 remains draft and issue #295 remains open.

## 29 October: current-main integration

Merged main through `b624689d`, including the 0.8.6 runtime pins and the newer
Android GPU-driver picker. The activity-result conflict retains both the Retro
import/export branch and the GPU-driver branch, with separate early returns.
The picker request-code regression now checks the GPU-driver request as well as
the activity's existing music, save and ghost requests.

On this merged source, the five ghost Python/JVM checks, synthetic catalog
check, strict-warning ASAN/UBSAN ghost and Retro transfer tests, Apple Foundation
identity/Retro manager tests, production Android Kotlin compilation and both
Android cold-configuration cases pass. Kotlin compilation uses the release's
cached dependencies and excludes packaging/provenance generation. All five
submodules were advanced to the exact merged gitlinks before the cold-config
check.

This removes the merge conflict and checks the current code paths; it does not
replace the earlier build, native picker or replay receipts with new gameplay
acceptance. The wider course/variant/mode and Apple gameplay gates above remain
open. No artifact or release was published.
