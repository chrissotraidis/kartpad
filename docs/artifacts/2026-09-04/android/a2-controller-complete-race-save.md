# Android A2 complete controller race/save evidence

Date: 2026-09-04

Branch: `codex/android-a2-cold-input`

Target: `KartPad_API_36_ARM64`, Android API 36, `arm64-v8a`, 4,096-byte
pages, gfxstream with host lavapipe

## Falsifiable subgoal

On the complete private Original runtime, use Android's ordinary
InputReader-to-SDL controller path to drive a full three-lap race through
results, create a durable post-race save, force-stop the process, relaunch with
the controller already attached, and prove the result survived. Do not count a
virtual emulator controller as physical-controller or physical-device
acceptance.

## Exact candidate and input boundary

The run used the unchanged local-only 103,440,032-byte debug APK from the cold-
input checkpoint, SHA-256
`2c11450996f33a35ba3aa85dcf16c1c467bf6fd4a0943edef966557639d7a6e7`.
Validated ignored RMCP01 data and the isolated test save existed only in the
app sandbox. No APK/AAB was published.

An ignored temporary `/dev/uinput` Xbox-compatible controller entered Android
through InputReader, SDL discovery, Aurora's cached controller snapshot, and
the production Classic/KPAD bridge. A host feedback loop read only the opt-in,
content-free native state trace and emitted ordinary analog-axis/button events
to that controller. It did not write guest state, inject application input,
alter race completion, or force a finish. The single keyboard event used to
leave the title attract loop was test setup only; character, vehicle, drift,
cup, course, all race acceleration/steering, and post-relaunch course
navigation used the controller path. The earlier cold-input checkpoint already
separately proves short controller presses at title/license/menu.

## Complete race and save result

Mario / Standard Kart M / Automatic completed all three laps of N64 Mario
Raceway. The retail results screen reported:

- total: `04:28.063`;
- lap 1: `01:23.445`;
- lap 2: `01:19.112`;
- lap 3: `01:45.506`; and
- `Saved ghost data for KartPad!`.

The state trace transitioned from live race stage 2 to results stage 4 at race
timer tick `16308`. The retained private trace has 20,313 lines and SHA-256
`299afe2b2a2b269341d639fa387a0452b61d193c16f113beaf9356d3d29bba4e`.
It remains ignored and was not published.

The isolated save changed from pre-race SHA-256
`40f5d5ae5ad93c39253559628a34359aa4627ebdc1b04605327cf2c59a5ff7e1`
to post-race SHA-256
`23c15850daace1587661aa07a99f08e450313963b469e683f13ae5dc0d6af005`.
Unlike the earlier slow keyboard run, the retail recorder accepted and saved
this ghost.

## Cold-relaunch proof

The controller remained attached while the app was force-stopped and relaunched
as new PID `10983`. The cold-start console records
`Android SDL controller channel 0 connected` at line 171. Before navigating,
the relaunched process read the same save SHA-256
`23c15850daace1587661aa07a99f08e450313963b469e683f13ae5dc0d6af005`.
Controller navigation returned to Shell Cup / N64 Mario Raceway, where both the
course list and ghost chooser displayed KartPad's `04:28.063` result. The ghost
chooser reported two available ghosts and showed the saved Mario / Standard
Kart M record.

## Verification

- The strict Android package/privacy audit passed again against the exact APK
  and reported the expected SHA-256.
- A retrospective allowlist-only summary of the retained exact-race console
  recorded 32 kHz stereo playback initialization, one non-silent sample event
  with peak 3,988, 194,856,192 submitted bytes across 507,904 queue checks,
  zero post-start empty observations, controller connect/disconnect events,
  and no fatal signature. It intentionally reports the combined automated
  signal matrix as false because this console did not contain the lifecycle
  transitions proved in the separate lifecycle run. This is non-silent stream
  evidence, not a claim that audible quality was judged.
- The repository safety audit and `git diff --check` passed.
- The retained private save copy matches the post-race and post-relaunch
  SHA-256 above.
- Process inspection after cleanup found no emulator, virtual controller, or
  feedback-driver process.

## Test discipline and cleanup

The disposable AVD was reduced temporarily to 1280x720 after the original
2400x1080 surface sustained only about 10--13 FPS; this restarted the activity,
so the accepted race began in a fresh process at the lower emulator resolution.
The override was reset afterward. An earlier `-wipe-data` cleanup mistake
erased only this disposable AVD's prior app sandbox; validated private runtime
inputs and the independent isolated save fixture remained intact and were
restaged. No tracked, published, physical-device, or maintainer save was
affected.

After capture, the app was force-stopped, the virtual controller exited, the
trace marker and live trace were removed, temporary shared exports were
removed, the display override was reset, and the AVD was shut down. Private
trace, console, save, and screenshots remain ignored and unpublished.

## Honest classification

**Pass for a complete controller-driven emulator race, retail results, ghost
save, controller-attached cold relaunch, byte-stable save persistence, and
visible result reload.** The same exact-race console now has a committed,
content-free
[runtime-signal summary](a2-controller-complete-runtime-signals.json). A2
remains open for a real
Bluetooth/USB controller, tactile rumble, audible-output confirmation,
performance acceptance, and the complete run on physical Android hardware.
