# Android A2 UID-scoped physical-session capture

Date: 2026-09-04

Branch: `codex/android-a2-cold-input`

Starting commit: `2d3024509198058ecbbbc283f86da8d093402db6`

## Falsifiable subgoal

Make the first physical A2 session collect one strict app-scoped signal matrix
without saving raw logcat on the host, exposing the ADB serial or package UID,
or accidentally combining different sessions. Do not automate or claim the
hands-on race, audible-quality, tactile-rumble, or performance judgments.

## Implementation

`scripts/capture-android-a2-session.sh` has two explicit phases:

1. `start` runs the physical-device preflight, requires the installed KartPad
   package, queries the device's own log timestamp, and stores only that
   timestamp in the ignored `.android-bootstrap/` directory.
2. `summarize` reruns the preflight, resolves the KartPad package UID without
   printing it, requests the volatile Android logs since that timestamp with
   logcat's UID filter, and streams them directly into
   `summarize-android-a2-session.py --require-signal-matrix`.

Only fixed-schema sanitized JSON reaches stdout. Raw logcat is never written
to a host file by the wrapper. Direct ADB failures are replaced with a generic
error because ADB may include the transport serial in stderr; all other ADB
commands pass through the existing serial-redacting boundary.

The timestamp comes from Android rather than the Mac, avoiding host/device
timezone skew. The package UID survives the required force-stop/relaunch, so
one capture window can include the cold-relaunch portion of the same hands-on
test.

## Contract verification

Commands:

```sh
bash -n scripts/capture-android-a2-session.sh \
  scripts/test-capture-android-a2-session.sh
./scripts/test-capture-android-a2-session.sh
```

Result:

```text
Android A2 UID-scoped capture contract passed (start, summarize, redaction).
```

The fake-ADB contract proves that `start` records the device timestamp, the
UID-scoped `summarize` path produces a passing strict matrix, an arbitrary
private game-text line is absent from JSON, and neither successful output nor
a simulated disconnect error exposes the sentinel ADB serial.

The pinned API 36 ARM64 AVD then verified the integration assumptions without
launching KartPad: device-side `logcat --help` advertises `-T TIME` and
`--uid=UIDS`, the installed debug package resolved to a numeric UID, the
device-sourced timestamp matched the required 18-character shape, and the
exact `logcat -d -v raw -T <time> --uid=<uid>` invocation exited successfully.
Neither UID nor serial is recorded here. The AVD was shut down afterward.

Script SHA-256 values:

```text
02af90c46ac50083fa7adfb91e4f99a8225c883c7a62115114bcf3a4b1549f12  scripts/capture-android-a2-session.sh
8dc021015636f91ba316cab54cd1d5291cebce5b465e3715de3ef0bb1f456d58  scripts/test-capture-android-a2-session.sh
```

## Live-host result

No physical ADB target was attached. Before the disposable integration check,
the real `start` command stopped at the preflight without querying a UID or
creating the marker:

```text
ERROR: expected exactly one ready ADB target (ready=0 unavailable=0); no device serial was printed
```

Classification: **Pass for a tested, UID-scoped, raw-log-free physical A2
capture path; physical execution not run.** The actual device/controller,
race/results/save/relaunch, pause/resume, surface recreation, audible output,
tactile rumble, and performance gates remain open. No APK/AAB, raw log, device
identifier, package UID, controller name, save, game data, or private capture
was published.
