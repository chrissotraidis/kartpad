# PGO on an unprofiled course — 14 October 2026

**Result:** the existing PGO experiment also reduces measured game-thread CPU
time on Mario Circuit. It remains a private candidate, not a shipped speedup or
a diagnosis of #470. No production compiler flags or renderer defaults changed.

## Comparison

The 12 October measurement used Luigi Circuit, the same course used to train the
profile. This pass uses **Mario Circuit, 50cc Flower Cup, 12 racers**, with Mario
idle in a standard kart. Both variants use the identical diagnostic APK from
10 October; only the loaded game pack changes. All 29,841 C++ translation files
in the baseline and profile-build trees are byte-identical. The PGO build uses
`-fprofile-use`; its ELF has no profile-counter sections.

Android API 36 ARM64 runs on the M3 Max using `-gpu host`, with the host Vulkan
device confirmed in the emulator log. Each trial starts from a cold emulator
boot without snapshots. Touch-only navigation verifies Flower Cup before the
race, waits 55 seconds after confirmation, and samples game-thread user/system
CPU ticks for 60 seconds. Every window has an unchanged process, roughly 60
presentations/second, and zero queued pipelines. FPS is only the frame-count
denominator here, **not an Android-phone performance result**.

Game-thread CPU milliseconds per frame, including kernel time:

| Order | Variant | User | Kernel | Total |
| ---: | --- | ---: | ---: | ---: |
| 1 | Baseline 1 | 7.633 | 0.172 | 7.806 |
| 2 | PGO 1 | 6.600 | 0.183 | 6.783 |
| 3 | PGO 2 | 6.783 | 0.155 | 6.938 |
| 4 | Baseline 2 | 7.576 | 0.155 | 7.731 |
| 5 | Baseline 3 | 8.523 | 0.158 | 8.681 |
| 6 | PGO 3 | 6.705 | 0.194 | 6.899 |

The first pair is diagnostic only: another local Node job became CPU-heavy
during the PGO window, identified before interpreting the result. The remaining
two pairs reverse order and retain all observations. Host activity was sampled
every two seconds; normal desktop/agent bursts remain, with no sustained build
running during those windows. This is not a claim of a perfectly idle host.

Every PGO result is below every baseline result, including the reversed pair.
The later PGO windows are 6.90–6.94 ms versus 7.73–8.68 ms for the baselines.
The baseline spread is substantial. Screenshots confirm the same course,
character, kart, lap and idle player, but lapping CPU racers can bump the kart
and change its camera. That changes visible work, so **do not advertise a single
precise percentage from this run or treat it as a controlled phone A/B**.

The executable `.text` section grows from 116,395,028 to 126,808,460 bytes
(8.95%). The PGO profiling artifact also retains nonloaded symbol/debug sections;
its raw file-size difference is not the shipping-size comparison. Larger code
can behave differently on a phone's smaller caches.

## What this moves forward

The unprofiled-course smoke/performance check is now covered, with a consistent
directional CPU benefit. The original same-course result is no longer the only
evidence. Keep PGO as the next optimization candidate, alongside the independently
tested vertex-repack change in draft #474.

Still needed before adoption: a broader training profile and Retro Rewind
coverage, rebuilding and validating against the final runtime, matched
affected-phone evidence, and a decision about distributing a profile for
PadMint. Neither this experiment nor the repack microbenchmark establishes
the cause of #470's update regression. No affected Adreno character fix is
confirmed by this pass.

## Tooling corrections found during the pass

- `deploy.sh` now creates the private pack directory and stops if moving the
  pack, repairing ownership or restoring its SELinux label fails. The missing
  directory was reproduced on the reused test AVD; corrected deployment works.
- `build-android-app.sh` recognizes the debug-signed diagnostic release APK
  filename. Production release signing is unchanged. `build-variant.sh` no
  longer ignores a failed build and copies a potentially stale APK; it uses the
  current version with `-perf` and explicitly excludes a bundled game pack so
  the pushed A/B pack is the one being tested.
- `ab.sh` targets its own emulator serial/process, refuses an already-running
  target or a hardware serial, uses true cold boots, and stops on benchmark
  failure. The refusal checks passed without stopping the live test emulator.
- A failing-build fixture exits with the builder's exact status (47), leaves
  the old APK untouched, and cannot produce a new fingerprint receipt.

The repaired wrapper also completed a fresh optimized diagnostic APK and all
208 game-pack build steps against the current candidate runtime. APK audit,
source/fingerprint checks and the pack's export checks pass. The APK is
`0.8.1-perf` / build 263, debug-signed and contains no bundled game pack; the
separate private pack is pushed by the test harness. Related package, builder
and fingerprint contracts pass: **27 tests and 4 subtests**. Shell syntax and
diff checks pass. These are private test artifacts, not a release build.

The public A/B runner then completed two cold starts with that same fresh
variant. Both screenshots show a real Luigi Circuit race, lap 1, Mario visible
in 12th place. The runner reports `DONE` and exits successfully; its emulator
process and ADB target are gone afterward. This validates build/deploy,
navigation, measurement and cleanup, not a performance difference: both sides
use the same build. The separate run log and two screenshots are retained under
`private/followup-20261014/tooling-ab-*`.

Private screenshots, raw ticks, logs, pack hashes, host-activity samples and
the navigation driver are retained in `private/followup-20261014/cross-track/`.
The AVD's pre-test settings and NAND were backed up; game data was preserved.
No hardware iPad was used, and no game/profile/save material is committed.
