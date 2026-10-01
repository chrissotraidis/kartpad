# Updating WiiCompiled and Retro Rewind

KartPad keeps its Apple host, WiiCompiled base, and Retro Rewind release inputs
as separate, explicit layers. Updating one layer must not require copying or
forking an upstream tree into KartPad.

## Pins and ownership

- `dependencies.lock.json` pins the WiiCompiled source baseline and the Retro
  Rewind Pulsar, WFC patcher, and WFC server references used for implementation
  and local protocol testing.
- `builder/profiles/mkwii-rmcp01-rev0.json` is the single release-input pin. It
  records the Retro Rewind version, official version-feed URL, archive URL,
  byte counts, hashes, expansion limit, `Code.pul`, Riivolution XML, and signed
  production RWFC payload.
- `vendor/wiicompiled` pins the maintained translator (fork branch `kartpad-translator`).
  `vendor/runtimes/{macos,ios,android,tvos}` pins the maintained runtime forks
  (including Aurora) with Git submodules. Edit these sources and deliberately
  advance their gitlinks; staging scripts do not replay the old patch stack.
  The detached upstream reference and archived patches retain provenance.
  See [source maintenance](source-maintenance/README.md).
- `builder/kartpad_builder/release_header.py` generates the iPhone/iPad
  installer's release constants from the profile. There is no second manually
  maintained version or download URL in the app UI.

## Update loop

Advance one upstream at a time on a dedicated branch.

1. Run `python3 scripts/check-retro-rewind-version.py`. The daily GitHub Actions
   watcher runs the same check and opens one deduplicated compatibility issue
   when the official feed advances beyond KartPad's pinned profile.
2. Run `python3 scripts/update-retro-rewind-profile.py --latest`. The helper
   resumes or reuses the official full archive in ignored private storage, then
   validates the official archive layout and writes the version, URL, byte
   counts, and SHA-256 values for the archive, `Code.pul`, and Riivolution XML.
   An already-downloaded archive can still be supplied explicitly with
   `python3 scripts/update-retro-rewind-profile.py PATH_TO_ARCHIVE OFFICIAL_URL`.
3. Update the relevant lock entry and replace only its detached reference
   checkout. Record the new commit and tree.
4. Validate the production payload signature and its pinned size and hash.
   Never weaken a hash or signature check to accept a new release.
5. Review upstream changes against the maintained translator and each runtime
   fork. Port only reviewed changes to those sources, commit the runtime forks,
   and advance their gitlinks. Stage fresh source with the maintained-source
   scripts and verify it before building. Source-based maintenance does not
   automatically import later upstream commits.
6. Regenerate both the shared base graph and the Retro Rewind graph. Function
   counts and dispatch closure are profile gates, so an upstream change fails
   closed until the new graph is reviewed and pinned.
7. Run builder/unit tests, maintained-source verification, fresh platform prepares, and the
   dual-mode regression: Original boot, Retro Rewind install/boot, mode switch,
   save isolation, controller reconnect, and relaunch.
8. Run the isolated WFC login/race harness. When the production service is
   reachable, separately prove NAS authentication, GameSpy login, matchmaking,
   a live race, results, and clean reconnect before making an online-support
   claim or deploying the candidate for physical acceptance.

At runtime, KartPad compares its pinned version with Retro Rewind's official
version feed before that mode starts. A newer feed entry intentionally blocks
the old app: maintainers must advance the profile, regenerate the translated
graph, validate the new hashes, and ship a compatible KartPad build. Never
silently accept an unpinned `Code.pul` or asset archive merely because its
version string is newer.

This keeps normal updates mechanical: automatic detection, one local update
command, a source pin, regenerated private outputs, and the same acceptance
gates. It cannot eliminate the native rebuild when `Code.pul` changes: that file
contains changed PowerPC program code, and KartPad's no-JIT Apple targets must
translate it ahead of time into a newly signed ARM64 executable. Automating a
public release from GitHub Actions would require placing the user's private game
input or generated retail graph in hosted CI, so KartPad deliberately automates
detection and preparation while retaining the audited local build boundary.
No Nintendo game data, Retro Rewind asset pack, translated retail graph, save,
credential, or local test key belongs in Git or a public artifact.

## Payload-only changes and current review

The production Retro-WFC payload URL is mutable independently of the Retro
Rewind pack version. A fresh download can therefore fail its pin even while
`Code.pul` and the pack archive remain unchanged. Preserve the accepted cached
file on rejection; validate the new payload's size, hash, header and production
RSA signature before promotion. Then translate old and new payloads with the
same translator, review new overlays/continuations, regenerate shards and update
`expectedRetroFunctions` to the measured graph. Regenerate the Android release
contract from the same profile. Do not bypass identity or signature checks.

The [19 September review](artifacts/2026-09-19/cross-platform-stabilization.md)
records the payload fix, local builds, upstream gaps and remaining device gates.
The source migration retained upstream base `1912292c804f`; the checked upstream
head is `83463764b8ac` (114 commits later). That count describes ancestry, not
114 missing fixes: maintained source already includes selected backports.

## 22 September all-platform integration candidate

The candidate now integrates upstream `83463764b8ac` in the translator and all
four maintained runtimes, retaining KartPad platform adapters. The previous gap
above describes the 19 September state. See the [current integration record](artifacts/2026-09-22/upstream-all-platforms.md) for tests, packages and remaining
acceptance gates. Updating a source pin alone does not validate a release.

## 1 October 2026 upstream audit

This audit uses public KartPad `main` at `978a9f1c8132`, not the older dirty
primary checkout. Its translator pin is `9d563f98953c`; runtime pins are Android
`18685d137e7d`, iOS `8892a3612568`, macOS `fa2f3d393385` and tvOS `70001a185633`.
All five share upstream base `83463764b8ac`. The checked WiiCompiled head is
[`75886669bcf3`](https://github.com/patchzyy/Wiicompiled/commit/75886669bcf3e2848b054d4f0f630ee8f9b159bc),
dated 30 September. The [comparison](https://github.com/patchzyy/Wiicompiled/compare/83463764b8acda394e058b0c689a10b8561fc380...75886669bcf3e2848b054d4f0f630ee8f9b159bc)
contains 18 later commits. This counts ancestry; it does not mean 18 missing
fixes. Compare the actual maintained source before porting or making a claim.

### Changes already contributed or adapted

| Change | Current disposition |
| --- | --- |
| [Upstream #244](https://github.com/patchzyy/Wiicompiled/pull/244), `6f14bde26a4e` | Merged upstream by patchzyy, adapting KartPad alarm/context, offline services, shared LR dispatch, renderer/batching/readback, cache, compiler wakeup, Metal ownership and split-screen fixes. Record their upstream identities instead of submitting them again. The PR deliberately excludes KartPad's floating-point ABI changes. |
| [Upstream #251](https://github.com/patchzyy/Wiicompiled/pull/251), `85f250155f8f` | Merged upstream by DarthMDev, adapting KartPad controller platform/player-index and socket-error fixes. Compare platform variants before importing the upstream adaptation. |
| [Upstream #252](https://github.com/patchzyy/Wiicompiled/pull/252) | Still open at this audit. Already adapts KartPad anonymous Mach guest-memory aliases. Follow that PR and supply relevant evidence or regressions; avoid a duplicate submission. |
| [Upstream #267](https://github.com/patchzyy/Wiicompiled/pull/267), `77a86234165c` | Exact changed operations already present in pinned macOS `runtime/include/isa/ppc_isa_quantized.h`: paired-float fallback uses `Memory::Read64` and `Memory::Write64`, as this upstream fix requires. Its absent commit ancestry is not a missing Mac THP fix or a new performance result. Other platform headers were not checked for this equivalence. |

### Review of all 18 later commits

"Missing" below means a checked source operation is absent. "Review" means the
consumer or equivalent platform implementation still needs inspection; it is
not an instruction to merge the change wholesale.

| Upstream commit / change | KartPad disposition and next check |
| --- | --- |
| `6f14bde26a4e` / #244, KartPad fixes | Already contributed upstream; see ledger above. Compare any differences before importing the adaptation. |
| `b59e035b8727` / [#144](https://github.com/patchzyy/Wiicompiled/pull/144), non-Windows TLS | Review against KartPad's existing platform TLS integrations, pins and certificate validation. |
| `583e702547d0` / [#254](https://github.com/patchzyy/Wiicompiled/pull/254), `bltl` lifting | Missing from pinned translator `PpcLifter.cs`. Port the narrow lifting case and regression; verify LR on both branch outcomes and inspect generated control flow. |
| `c92e45c2e74a` / [#255](https://github.com/patchzyy/Wiicompiled/pull/255), early Linux linker probe | Review actual builder consumers and supported platforms before carrying Linux setup code. |
| `a9c9c0de2636` / [#256](https://github.com/patchzyy/Wiicompiled/pull/256), forced 16:9 viewport | Review against KartPad aspect-ratio settings and external-display behavior. |
| `85f250155f8f` / #251, controller/socket fixes | Already contributed upstream; compare existing platform variants. |
| `e409d9f99ba5` / revert black-kart fix | Review the reverted renderer hunk against maintained source and known geometry reports. Do not infer a new fix from the revert subject. |
| `e164af9ff466` / shader wait screen | Review startup/prewarm UI and input lifecycle; not evidence of lower frame time. |
| `82991ec33745` / version centralization | Review existing KartPad profile-generated release constants before adding another version source. |
| `a05c89739d60` / [#264](https://github.com/patchzyy/Wiicompiled/pull/264), payload refresh with fallback | Review against KartPad's explicit size/hash/signature and translated-graph pins. A mutable payload cannot be accepted just because a download succeeds. |
| `10ab54adeea1` / [#266](https://github.com/patchzyy/Wiicompiled/pull/266), special-character build paths | Review Windows builder consumers, then exercise a real build with apostrophe/ampersand paths. |
| `77a86234165c` / #267, Mac THP memory | Exact changed read/write operations already present on macOS; see ledger above. |
| `6b853ca37144` / [#265](https://github.com/patchzyy/Wiicompiled/pull/265), Wii certificates | Missing in checked macOS and Android `runtime/include/wii_es_crypto.h`: they reject scalars at or above subgroup order. Upstream reduces modulo that order and rejects zero. Test canonical, reducible and zero keys with synthetic data; inspect iOS/tvOS before sharing the port. |
| `d0d58072d1f5` / [#272](https://github.com/patchzyy/Wiicompiled/pull/272), Linux Mbed TLS prebuilt | Review whether KartPad uses this prebuilt path; preserve its own dependency/archive verification. |
| `a88b7b502b62` / [#271](https://github.com/patchzyy/Wiicompiled/pull/271), xxHash 0.8.4/CMake layout | Review maintained dependency pins and CMake consumers together. |
| `9b7b9913e4ab` / [#275](https://github.com/patchzyy/Wiicompiled/pull/275), extra Mbed TLS archives | Review only with the affected packaging/link consumers. |
| `a50bad297078` / [#276](https://github.com/patchzyy/Wiicompiled/pull/276), extraction timestamps | Review incremental rebuild behavior and current dependency extraction policy before porting. |
| `75886669bcf3` / [#270](https://github.com/patchzyy/Wiicompiled/pull/270), reproducible non-Windows prebuilts | Toolchain overrides, disconnected configure and `SOURCE_DATE_EPOCH` flags are absent from the pinned translator's `Launcher/Prepare-NativePrebuilt.sh`. Trace KartPad builder consumers before porting; this is upstream Linux prebuilt work, not a demonstrated KartPad compile-time improvement. |

### Contribution and measurement loop

The local 1 October `bltl` candidate is on submodule branch
`codex/kartpad-bltl-lifting`, based on translator pin `9d563f98953c`. It copies
only the two hunks from upstream
[`583e702547d0`](https://github.com/patchzyy/Wiicompiled/commit/583e702547d0347d4634d48a314fc8dd3de75db2):
16 lifting lines and 17 regression lines. Adding the upstream regression first
reproduced `UNIMPLEMENTED 0x80004394: bltl 0x800043BC (0x41800029)` on the pinned
code (one failed test). After the lifting hunk, all seven focused coverage tests
and all 658 default translator tests passed on .NET 8. The regression checks LR
assignment precedes the conditional branch, with the correct destination and
fallthrough. Logs are retained locally in ignored
`work/bltl-lifting-20261001/{baseline,focused,full}.log`. The identical candidate source is now preserved on the owner fork at
[`1e55229d7f8d`](https://github.com/chrissotraidis/wiicompiled/commit/1e55229d7f8def89f34ec3ea433809f9e98cb1d0);
KartPad's gitlink and lock pin are unchanged. Real RVZ translations passed the pinned graph: 29,637 generated, 29,065 base
and 4,102 Retro functions. One Android cache-miss build then passed all 208
compile/link steps, app-state checking and private pack packaging against the
published 0.7.3 APK, with four jobs. Total time was 854.82 seconds; native build
was 751.319 seconds. This is one host build, not a performance comparison.
The resulting native pack (SHA-256
`45759bf7f03f0f3c0dae7d9eed92161bf14ea3c4ba9498d9a3dd8b5cb2d635e6`)
imports through the real system picker into the corrected release-style empty
APK and plays a Luigi Circuit race segment on the owned ARM64 emulator, with
acceleration, changed steering orientation and pause. The replaced pack matches
its built hash and retains the same interface fingerprint. The test license save
is byte-identical immediately after replacement. After gameplay, only byte
`0x5688` and its four-byte save CRC differ; all ghost data and the remaining save
bytes are unchanged, and the checksum is valid. This played segment is not a
completed race, Retro or service acceptance, or a weak-phone performance result.
The native build predates the candidate commit and used the same 33 source/test
lines atop `9d563f98953c`. Other native platforms and Retro acceptance remain
open before promoting the pin.

For each shared change, record the KartPad source pin, upstream equivalent or
gap, affected consumer, focused regression and acceptance result. Prepare new
upstream fixes on an upstream-based fork branch, one behavior per PR. Keep
platform-specific adapters in KartPad. Do not resubmit changes in #244/#251 or
duplicate the open #252 work.

[WiiCompiled's contribution rules](https://github.com/patchzyy/Wiicompiled/blob/75886669bcf3e2848b054d4f0f630ee8f9b159bc/CONTRIBUTING.md)
require contributors to understand and explain every submitted line and say:
"PR descriptions and responses must be written by you, **not** generated."
Chris writes upstream submission text; automation can prepare code, tests,
measurements and review evidence. Game-behavior changes need evidence of
agreement with the original hardware.

[Issue #339](https://github.com/chrissotraidis/kartpad/issues/339) sets approximate
targets of 10% lower CPU frame time on weaker hardware and 40% shorter final
compilation. These are goals, not measured gains. Establish a repeatable
same-machine baseline first: separate translation, shard generation, Clang and
link durations for clean and incremental builds; report average and worst-case
CPU frame times under the same scene and settings. Let the profile select a
small optimization, then repeat that comparison and reject regressions. Local
source/build proof does not establish affected-user, physical-gameplay or online
acceptance, and does not justify repeated requests for reporter testing.

### Imported Wii ES scalar follow-up

The four maintained `wii_es_crypto.h` files still reject noncanonical nonzero
private scalars accepted by the identity loader. A narrow ignored copy carrying
upstream #265's modulo policy passes actual-header Crypto++ certificate,
signature, tampered-message and zero-residue checks on macOS ARM64 and the owned
Android emulator. [Exact pins and evidence](artifacts/2026-10-01/es-key-scalar-policy.md)
separate this synthetic native proof from authentic imported identities, service
login and release acceptance. No runtime pin or identity data is changed by
this review; no duplicate upstream contribution is proposed.
