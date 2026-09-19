# Private diagnostics candidate — 2026-09-17

Update: the owner subsequently authorized publishing diagnostics preview 2 and asking affected reporters to retry their normal failures. The earlier private-stage installation gate below is historical and does not block this preview. See [release instructions](../../releases/v0.4.25-diagnostics.2.md).
Status: implementation complete; final artifact validation is recorded separately
in `build/diagnostic-candidates/`. Physical acceptance remains pending. No publication, installation,
reporter outreach, or affected-device acceptance is authorized for this stage.
Target Android 0.4.25-diagnostics.1/code118; iOS 0.4.25/build50.
The source starts at KartPad `7b663a2`; original dirty checkouts remain untouched.

## Working loop

1. Read the 48 open reports and shipped code/artifact, identify the missing decision.
2. Research platform-supported evidence, then implement the smallest useful capture.
3. Exercise corruption, unavailable-data, privacy, boundedness and symbol identity.
4. Build the actual physical-device products, retain their exact native symbols.
5. Owner installs in place after waking, reproduces and exports; compare overhead.
6. Only after that acceptance, publish and ask selected reporters for ONE named
   reproduction. Correlate returned evidence before another patch or request.

The prior Android117 outreach already happened before this new instruction. No
additional comments are to be sent as part of preparing these private candidates.

## Findings and decisions

* The mobile runtime registered a SIGABRT handler which used locks/allocations/UI
  then `_Exit`, potentially suppressing Android/Apple native crash collection.
  Mobile now retains default abort/terminate semantics. Explicit caught guest
  exceptions still produce the existing crash text and orderly exit; they are
  not relabelled as native signals. Desktop registration is unchanged.
* Android OS exit history was not included in the normal report, raw tombstones
  were only private protobuf, and missing native sessions blocked export. Reports
  now include full bounded exit classification and allowlisted tombstone frames.
  Launcher export remains possible with no console session. Native crash traces
  need Android12+; Android11 supports ANR traces. OS retention is not guaranteed.
* Every native frame includes module basename, relative PC and BuildID. Decode
  rejects malformed/oversized data, skips unknown fields, and omits memory,
  registers, raw paths, process arguments, logs and file descriptors. Keep the
  original protobuf only in the expressly requested private ZIP.
* iOS subscribes to MetricKit and retains eight bounded diagnostic payloads,
  including OS crash/hang/CPU diagnostic stacks when delivered. Export includes
  the executable UUID and the last three native runtime sessions, limited to
  console/crash text. Guest memory, saves and game files are never enumerated.
  iOS Analytics .ips/Jetsam is the fallback when a matching payload is absent.
* Selected coarse functions report inclusive thread CPU and wall time every five
  seconds (up to120 windows per function/thread). Initial probes are audio PB
  processing, frame completion and renderer worker cycles. These timings are
  labelled by function; they are not an all-function sampling profiler and nested
  times must not be summed. Full CPU attribution uses Simpleperf/Instruments.
* Existing Android draw checks could use their budget before reaching the scene.
  Both platforms now sample actual PNMTX draws every128th eligible draw, within
  30-second windows, max2048 checks/window and20 windows/launch. Reports contain
  pipeline identifiers, matrix index validity/nonfinite counts and layout sizes.
  No raw geometry/textures/guest data is exported. A passing sample is not proof
  that every draw or the GPU's execution was correct. Capture screenshot/video
  and the exact scene/time alongside it. A GPU frame capture remains a separate
  developer step if these counters cannot discriminate CPU input vs driver error.
* Private Android is optimized Release, profileable, and retains full native
  symbols, using the existing local signing identity only if it matches the
  installed/public app. iOS is an optimized physical-SDK build with dSYM output.
  Identical BuildID/UUID is mandatory for symbolization; version text is insufficient.

## Issue-to-evidence decisions

| Reports | Needed capture | What it decides |
| --- | --- | --- |
| Launch/race/cup exits, including236/235/216/215/211/193/131/128 | One failing transition, selected-session logs, matching OS reason/time/native frames | Native signal vs self-exit vs memory kill vs ANR; exact symbolized native stack |
| 198/275 (existing warmed CPU-bound logs), 296/278 and remaining slow devices | Warm same course, coarse CPU/wall windows, then30s actual-device Simpleperf/Instruments if unresolved | Expensive runtime/translated functions vs waiting; no further generic log request for198/275 |
| 104/137/166/211/102/120 geometry family | Exact scene screenshot + sampled draw window + GPU/driver/build/settings | Invalid CPU matrices/index ranges vs clean sampled inputs; select a concrete GPU-capture/driver hypothesis |
| 135 A10X remaining performance | Existing launch fix retained; physical CPU profile | Remaining cost; do not reopen old accepted SIGILL subcase |
| 206 cellular86420 | Same known transition, numeric socket/SSL timing and network class, Wi-Fi control | Service/login/matchmaking boundary; not a generic crash or private packet dump |
| 101 aspect/100 external display/119 system bars | Physical screen/output and lifecycle/surface context | Presentation/insets/output ownership; crash logs alone do not explain layout |
| 297/273 input | Controller model/mapping and precise handoff | Delivered mapping acceptance vs unspecified regression |
| 234 save/identity, 295 custom ghosts, 194 updater,90 Original online,91 DSU,5 Wii Remote/Mii | Existing scoped engineering work | Logging cannot implement missing features; preserve private identity/saves |

Do not collapse distinct device/driver/scene observations into one diagnosis.
Intake key: issue + device model + OS/API + GPU/driver + exact binary BuildID/UUID
+ session timestamp/PID + Original/Retro/pack + transition + capture settings.
Unknown fields stay unknown. Returned capture state is: sufficient for a named
next decision / needs one detail / OS unavailable. Issue count is not fix count.

## Platform research (primary sources, checked 2026-09-17)

[Android NDK debugging](https://developer.android.com/ndk/guides/debug) documents
native tombstones and native profiling. [ApplicationExitInfo](https://developer.android.com/reference/android/app/ApplicationExitInfo)
explains API levels and retention; an ANR trace can survive a later different exit.
[AOSP tombstone schema](https://android.googlesource.com/platform/system/core/+/refs/heads/main/debuggerd/proto/tombstone.proto)
(blob9deeeec9e185f79747acf5fb6a7e71586eb7da16) supplies the decoder field numbers.
[Native symbols](https://developer.android.com/build/include-native-symbols) and
[performance measurement](https://developer.android.com/topic/performance/measuring-performance)
support optimized, profileable builds and exact retained symbols.
[AGI requirements](https://developer.android.com/agi/start) mean GPU capture is
not a universal phone-only button or a promise of support on every device.

[Apple MetricKit](https://developer.apple.com/documentation/metrickit) provides OS
diagnostic delivery, with [MXCrashDiagnostic](https://developer.apple.com/documentation/metrickit/mxcrashdiagnostic)
call stacks and termination information. [Apple crash reports](https://developer.apple.com/documentation/xcode/diagnosing-issues-using-crash-reports-and-device-logs)
distinguishes full crash reports from memory-pressure reports.
[Apple crash-reporter guidance](https://developer.apple.com/forums/thread/113742)
explains signal safety; avoid a new hand-written signal unwinder.
[PLCrashReporter](https://github.com/microsoft/plcrashreporter) is a mature option
if local MetricKit/Analytics testing exposes a real collection gap, but it adds a
second crash-handler integration requiring hardware validation; not added blindly.
[Sentry's native Android approach](https://sentry.io/changelog/better-native-crash-reporting-for-android/)
also uses OS tombstones; [Unity diagnostics](https://docs.unity.com/en-us/cloud-diagnostics)
combines crash evidence, symbols and contextual device information. KartPad uses
local user-controlled export instead of adding a telemetry account/upload service.

## Owner morning acceptance (before any publication)

1. Verify installed signer/bundle and back up existing settings/saves as appropriate.
   Update in place. Do not uninstall, clear app data, or substitute a simulator.
2. Confirm version118/50 AND binary identity, then Original and existing Retro boot.
3. Reopen after one controlled native failure on a test session; confirm OS reason,
   stack retention, symbolization against this candidate, and usable launcher export.
   Validate no-session export separately. If OS data is absent, retain explicit
   unavailable status and test the documented OS fallback; do not call it passed.
4. Warm one familiar course; export a report with function windows and draw-window
   markers, identify the session, and compare feel/performance with the accepted
   build under identical settings. Instrumentation/validation can add overhead.
5. Check background/resume, report preview/share/save, controller/touch overlays and
   existing saves. For iOS test a report containing native console + system section.
6. Only then select actual affected Android reporters. No claim that diagnostics
   fix their crashes or graphics; ask for one targeted capture and screenshot/time.

## Build iteration notes

The old private translation shard had an incomplete REL report guard even though
its standalone function was corrected. Copied the private translation into this
worktree and regenerated shards from existing translated functions; the strict
REL guard verifier then passed. Shared private inputs were not edited.

The legacy SunPad verifier incorrectly called three already-maintained files
verbatim copies. It now verifies their existing reviewed hashes and compares the
remaining original files to the pinned upstream commit. This candidate does not
change those adapted source bytes.

## Offline analysis and controlled test

The private game menu has **Test Native Crash…** with a destructive confirmation.
It calls the named `KartPadDiagnosticCrashProbe` on the ordinary UI thread and
then aborts, leaving OS collection in control. Finish the race first. This action
is absent from normal Android versions and gated by the iOS candidate build flag.
A UI-generated test crash proves collection of that test, not another phone's bug.

Android frame analysis is local:

```sh
python3 scripts/symbolize-android-frame.py --symbols /absolute/path/libmain.so \
  --build-id BUILD_ID_FROM_REPORT --relative-pc HEX_PC_FROM_SAME_FRAME
```

The helper refuses mismatched ELF BuildIDs. It has been tested against a real
NDK-compiled fixture with DWARF and a negative mismatched-ID case. Apple uses
`xcrun dwarfdump --uuid` for app/dSYM identity, then `atos` or Xcode with that dSYM.
Never match a stack merely because a file has the same name or version number.

For cooperative Android reporters with a computer, the installed NDK's official
Simpleperf helper can profile the **already running, warmed** candidate:

```sh
python3 "$ANDROID_NDK_HOME/simpleperf/app_profiler.py" \
  -p dev.kartpad.android --disable_adb_root \
  -r '-e cpu-clock:u -f 400 -g --duration 30' \
  -lib /absolute/path/to/exact/unstripped/libraries \
  -o /absolute/private/path/perf.data
```

Do not add `--launch` during a warmed-scene comparison. Capture support and stack
unwinding must be checked on the actual device; preserve the original perf.data
privately. Use Instruments Time Profiler for a development-signed physical iOS
candidate. Attachability depends on that signing/entitlement configuration.

Host checks passed for tombstone privacy/malformed input/bounds (including keeping
the crashing thread when >64 threads exist), export with no session, symlink and
private-file exclusion, actual mobile handler registration, selected-function CPU
versus wall waiting, exact ELF symbolization, and both report-context formatters.
These are tooling contracts, not a substitute for morning device acceptance.

An initial full Android Release APK and physical iOS app compiled. Final packaging
is repeated after adding the crash-test controls. The iOS build script explicitly
runs dsymutil and checks UUIDs because CMake suppressed automatic dSYM generation.
It strips debug symbol-table paths only after saving matching developer symbols.

Signing audit found the default local Debug identity differs from Community
Release. Keep separately named private signing variants; never uninstall to bridge
that difference. Both variants must contain identical native/DEX payloads.
Final artifact paths, hashes, identities and validation receipts belong under
`build/diagnostic-candidates/`, not a public release.
