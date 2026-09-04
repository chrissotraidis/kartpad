# Android A2 runtime-signal sanitizer

Date: 2026-09-04

Branch: `codex/android-a2-cold-input`

Starting commit: `669dee44f0b2809fbd3f415b9e20a234a0ee401b`

## Falsifiable subgoal

Turn a private Android session log into deterministic, content-free evidence
without copying arbitrary lines, paths, device identifiers, game text, or
controller names. Strict mode must not pass unless one capture contains the
minimum automated controller, audio, lifecycle, and crash-free signals. It
must not convert those signals into subjective audible, tactile, gameplay, or
performance acceptance.

## Implementation

`scripts/summarize-android-a2-session.py` scans without retaining raw lines and
emits only a fixed JSON schema containing:

- SDL host playback event count, sample-rate/channel sets, non-silent event
  count and maximum peak;
- validated bounded queue counters and the most advanced sample;
- controller channel-zero connection/disconnection counts;
- SDL surface create/destroy and native pause/resume counts;
- standard-gamepad suspend/resume counts; and
- counts for an explicit fatal-signature allowlist.

Malformed queue telemetry fails closed. `--require-signal-matrix` accepts only
one capture or standard input and exits nonzero unless that capture includes a
controller connection, playback initialization, non-silent PCM, submitted
audio, one complete surface pause/resume cycle, the standard-gamepad
suspend/resume pair, and no fatal marker. It does not assert a completed race,
save, tactile rumble, audible quality, or acceptable performance.

## Verification

The embedded self-test passed a complete synthetic signal set, verified that
an unrelated private line did not appear in serialized output, rejected a
fatal signal, and rejected malformed queue telemetry. A separate missing-file
check confirmed that errors do not echo the supplied private path:

```text
Android A2 session summarizer self-test passed
```

Strict mode correctly exited 1 for the retained exact-race console because it
has no lifecycle markers. It exited 2 rather than combining that console with
a separate lifecycle log into a false single-capture pass.

The exact-race private console remains ignored and has SHA-256
`1feeec9301ac8d7817e5b6030f871565faffd23df23c5b0f53673126ebfac27f`.
The deterministic sanitized JSON is
`a2-controller-complete-runtime-signals.json`, SHA-256
`1192ecaa9bff6bdd9f6047b167b3fceee6583b724b78632b5a4a8fb7f8361b0e`.
It records:

- 32 kHz stereo host playback initialization;
- one non-silent event with peak 3,988;
- 194,856,192 submitted bytes and zero post-start empty observations through
  507,904 queue checks;
- 465 dropped blocks / 178,560 dropped bytes, retained as a performance
  observation rather than hidden;
- two controller connections and one disconnection; and
- no allowlisted fatal signature.

The combined automated matrix is correctly `false` because this exact-race
console did not contain the separately tested lifecycle transitions. The
sanitizer has SHA-256
`f4423cbc1d849c5e5ed287bf6391182591ff7aa8924d9e024cb191a0c5f867bc`.

Classification: **Pass for deterministic allowlist-only Android runtime-log
sanitization and retrospective exact-race non-silent stream evidence; not a
physical-device, audible-quality, tactile-rumble, race, save, lifecycle, or
performance acceptance result.** No APK/AAB, raw log, device identifier,
controller name, save, game data, or private capture was published.
