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
targeting main. Current source `1d00651f` has passing Linux boundary, macOS
mobile-bridge and maintenance-receipt hosted checks.

## Corrected build receipts

Build source `10be3756` contains early Android application storage setup, a single
cold-launch JNI config reload, atomic exclusive publication and the permanent
actual-config-parser regression. Linux boundary, macOS mobile-bridge and
maintenance-receipt hosted checks all pass on that commit and current receipt
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

## Original native transfer regression

On the same corrected Android app and pack, the real SAF picker imports the
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

Replay acceptance fails: the imported downloaded entry remains stationary at
the start line for over 60 seconds with responsive pause controls, while the
same built-in staff replay moves normally. No cause or fix is established yet.
File transfer, save preservation, native discovery and export pass; this does
not establish downloaded replay correctness. The narrower translator patch has
no matching instruction sites in the retained Original DOL/REL executable
sections, so it supplies no direct explanation for this failure.

## Remaining acceptance

Issue #295 remains open and PR #375 remains draft. Native custom-course and
nonbase-variant import/export, the other three modes, and arbitrary/cross-mod replay correctness
remain open. Original transfer/readback passes; downloaded replay fails and a
normal race still requires native regression on the corrected candidate. iPhone picker/native acceptance
and physical-device gameplay remain separate gates. These receipts do not
announce an app release or shipped menus.
