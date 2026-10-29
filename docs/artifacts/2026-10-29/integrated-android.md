# Integrated Android validation, 2026-10-29

This receipt covers a privately built, release-signed, fully rebuilt Android candidate using the new maintained runtime. It supersedes the earlier cached-runtime bloom smoke for integration claims. It is emulator evidence, not physical Android device acceptance.

## Artifact identity and normal build path

- Clean parent source: `c3829dfcf478fec8d57dcb1e63f01f21964d247b`.
- Android runtime: `6e3ce40fba8faab8adbddad7933af67018e3d78c`.
- Translator: `d64053cbce991c13e77731c10dab9fdb5dc7ef98`.
- Pack fingerprint: `720a50dd6a104088e789a840468baf8da0aa3e288f61b07456714aba0067210e`.
- Private candidate: version `0.8.6-integrated-test`, code `271`, APK SHA-256 `dba63cefdc86760fd595e52c6cbbf451c40129e115eee309ebcf6c790acfd6ba`.
- Existing release signer certificate SHA-256: `c1dbe0a0d72d830a5779476b346a750d0a37515adef992cad2f3863058f7f2f2`.

The normal app wrapper rebuilt Classic from staged maintained source. The normal WiiCompiled runtime builder rebuilt Beta. The normal game-pack builder rebuilt all 208 objects with the verified private translation inputs and the retained release PGO profile. The normal combined AAB and APK derivation scripts packaged the matching pack, both runtime libraries, and the existing verified DiscIO library. Source provenance reports a clean tree and the exact revisions above. Packaged Classic and game-pack bytes match their new outputs; Beta matches after the normal NDK strip step.

The build used the supported absolute output path. The separately committed relative-output wrapper correction (`84fcb9cf`) is not part of this candidate's source identity. Cached third-party dependencies and private input/profile data were reused; the maintained Android runtimes and matching game pack were rebuilt.

Separately, the corrected relative-output wrapper at `84fcb9cf` passed a normal invocation (`BUILD SUCCESSFUL`, 1m 9s, 43 tasks), producing the no-game APK stage `20261029-161751`. Its private log is `private/triage-20261029/relative-output-check.log`. That wrapper-only correction adds no runtime or app behavior to the candidate tested here.

Repository AAB and APK audits passed. Current PadMint audit exited 1 solely for the documented Android translated-code exception: 29,063 address-named symbols and the embedded program-sections marker in `libkartpad_game.so`. It reported no key, disc, or private-path finding. This is an explicit exception, not a blanket audit pass.

## Installation and mode checks

A dedicated new API 36 ARM64 emulator used a 16 GiB data partition and host graphics on an Apple M3 Max. Only this task-created installation was changed; no physical device or user AVD was used.

| Route | Observed result |
| --- | --- |
| Official 0.8.6 first launch | Production DocumentsUI ZIP import completed; a test license was created through game UI. |
| Update to integrated candidate | Existing release signer accepted the update. All 2,065 checked durable files were byte-for-byte unchanged before first candidate launch, including game data, settings, license/NAND, saves and preferences. |
| Updated Original / Classic | Luigi Circuit loaded, Mario/kart visible, touch acceleration moved the kart. |
| Updated Original / Beta | Luigi Circuit loaded and moved; native library mapping confirmed Beta. |
| Fresh integrated install | After removing only the test installation, first-launch production DocumentsUI ZIP import completed again and a new test license was created. |
| Fresh Original / Classic and Beta | Luigi Circuit loaded and responded to touch acceleration in both. Retained SDL startup records confirm the selected native libraries. |
| Official Retro Rewind installation | Production download of pinned 6.13.4 completed and KartPad's pinned verification passed. |
| Fresh Retro / Classic and Beta | SNES Mario Circuit 1 loaded with Mario/kart visible and responded to touch acceleration in both. |

These checks cover launch, real import/install paths and short controlled movement. They do not establish complete races/cups, online matchmaking, all characters or phone GPU behavior.

## Same-process session diagnostic

Nine Luigi Circuit visits (initial entry plus eight actual in-game exits and reentries) completed in one process, PID `7954`, start tick `404196`. Every window has seven PSS samples and fresh frame/CPU records; screenshots confirm the operator-labelled course and visible Mario/kart. The separate mixed-course control completed in PID `9814`, followed by an app-only restart into PID `10944`, retaining all disk caches. All 15 measurement windows completed. The first process was alive for 26.0 minutes and the mixed process for 16.7 minutes at their final receipts. Each visit used a five-second acceleration input, a braking input and a stationary warm measurement window; these durations include menus and do not represent continuous driving or completed laps. Fixed settings: Classic, Original mode, native 1x, Original 4:3, bloom enabled, automatic character policy, Mario / Standard Kart M / 50cc / automatic drift, touch auto-accelerate off. Each visit includes actual touch acceleration followed by a warm stationary 60-second measurement window. The sequence exercises in-game exits and reentries; it is not continuous lap driving.


| Luigi visit | PSS start MiB | PSS end MiB | `pipelines_created` at end | DL entries at end | Copy pool MiB |
| --- | --- | --- | --- | --- | --- |
| 1 | 339.6 | 342.4 | 473 | 7203 | 5.4 |
| 2 | 348.2 | 351.3 | 491 | 14593 | 5.4 |
| 3 | 349.8 | 350.4 | 491 | 8359 | 5.4 |
| 4 | 354.2 | 354.5 | 491 | 15272 | 5.5 |
| 5 | 356.5 | 362.9 | 497 | 8419 | 5.5 |
| 6 | 364.3 | 364.8 | 497 | 15006 | 5.5 |
| 7 | 362.9 | 362.3 | 497 | 7467 | 5.5 |
| 8 | 365.1 | 365.2 | 497 | 14830 | 5.5 |
| 9 | 362.6 | 362.9 | 499 | 6474 | 5.5 |

The final five end-of-window PSS samples stayed between 362.3 and 365.2 MiB. This does not show monotonically increasing memory across all nine visits. Display-list entries cycled rather than increasing without bound. Source review confirms the cache clears when insertion would exceed 16,384 entries or 8 MiB of logical command payload; the byte counter excludes per-entry arrays, map metadata and retained allocator storage. The resets therefore fit the existing capacity policy, not a new course-exit cleanup. GP opponents and RNG were not fixed, so each entry does not guarantee identical draw work.

An unrelated BlueWake player-check workload and subsequent compiler workers ran during the captures. Each window has a private host-load sidecar. Timing/FPS numbers are retained as raw diagnostics and excluded from performance conclusions; no quiet-host or phone-speed claim is made.

## Mixed-course return and restart control

The fresh-process control visited three different courses beyond Luigi. A fourth different Grand Prix first course was not available on the fresh license without unlocking progression, so the sequence used the readily available Banana Cup as its final added course. No unlock or save edits were made.

| Course/window | PID | PSS start MiB | PSS end MiB | `pipelines_created` at end | DL entries at end | Copy pool MiB |
| --- | --- | --- | --- | --- | --- | --- |
| Luigi baseline | 9814 | 317.6 | 323.4 | 502 | 7610 | 5.4 |
| Mario Circuit | 9814 | 370.8 | 371.4 | 555 | 15339 | 5.4 |
| GCN Peach Beach | 9814 | 508.6 | 519.3 | 690 | 8367 | 5.7 |
| N64 Sherbet Land | 9814 | 559.4 | 557.3 | 735 | 15902 | 5.9 |
| Luigi return, same process | 9814 | 556.2 | 556.4 | 735 | 7728 | 5.9 |
| Luigi after app restart, disk cache retained | 10944 | 316.7 | 322.7 | 504 | 7834 | 5.4 |

Returning to Luigi after the three new courses retained about 233 MiB more PSS than that process's initial Luigi baseline. An app-only restart, with the disk cache retained, returned Luigi to 322.7 MiB. This is evidence of process-lifetime retention associated with visiting new courses. It is not proof that all retained allocations are leaked or that the pipeline objects account for the full increase. The copy-target pool alone changed by only 0.5 MiB; full Android memory breakdowns are retained privately to guide allocation/resource ownership profiling. No speculative eviction change was introduced from these totals.

For #510, this narrows the next investigation to ownership and retention across different courses, followed by matched full-race physical-device sampling. The nine Luigi reentries did not show sustained growth in their final five windows; the mixed-course return did retain a much larger footprint. Neither result closes a report about slowdown after complete races or cups. The inspected frames showed Mario/kart and the sampled courses; this does not qualify every character, GPU or physical device.

## Retention and remaining gates

The task-owned emulator was checked by its exact AVD name, `KartPad_Integrated_20261029`, and stopped after the final receipt. Its AVD, signed APK/AAB, matching pack, build/provenance/audit logs, import/update receipts, screenshots, settings and 15 raw sample/host-load pairs remain private in the ignored task output directories. The primary checkout and user devices/AVDs were not changed.

Integrated source/build and emulator import/launch/movement gates passed. Physical-device graphics/gameplay acceptance, completed-race endurance, quiet-host timing and the allocation-level cause of cross-course retention remain open.

Private logs, binary artifacts, game-derived screenshots and raw metrics remain in ignored task directories. None are published with this source receipt.
