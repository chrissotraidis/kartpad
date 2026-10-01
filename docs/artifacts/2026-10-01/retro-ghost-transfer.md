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
the identity is not an authentication hash. A complete staged file is linked
into place without overwriting an existing entry. A completed link followed by
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
  duplicates, filename collisions, completed-link retry, corrupt/stale requests,
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
correspondence to shipped `Code.pul` remains an inference until native acceptance.

## Build and pack replacement

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

## Remaining acceptance

The official Retro installer is running on the owned test emulator. Continue
with a real ghost picker import, cold-launch discovery
and replay, including a Wii course in Retro and a custom variant. Check modes,
export bytes and pre-existing collection/save snapshots. Keep Original transfer
and a normal race as regression gates. iPhone UI/native acceptance and any
affected physical-device result remain separate. Issue #295 stays open; there is
no app release or claim that the new menus have shipped.

The owned checkout is `codex/retro-ghost-transfer`, stacked on the PowerVR draft.
Public translator/runtime pins stay unchanged. The preserved `bltl` source
candidate remains committed on the owner fork at `1e55229d7f8d`; for the normal
builder's source-pin guard, its identical 33 lines are applied over local
translator HEAD `9d563f98953c`. Do not stage that working change with this feature.
