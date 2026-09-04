# Android A3 Retro Rewind controller race/save evidence

Date: 2026-09-04

Branch: `codex/android-a3-retro-runtime`

Target: visible `KartPad_API_36_ARM64`, Android API 36, `arm64-v8a`,
4,096-byte pages, 1280x720 display override

## Falsifiable subgoal

Launch the production Retro Rewind profile, attach an Android-recognized game
controller before gameplay, navigate to a Retro Rewind course, finish a Time
Trial through the ordinary Android InputReader-to-SDL path, persist the
post-results save, force-stop the process, and prove the exact save survives a
cold controller-attached relaunch. Do not count this virtual controller as
physical-controller or physical-device acceptance.

## Exact candidate and input boundary

The run used the unchanged local-only debug APK from the production-chooser
checkpoint, SHA-256
`7088f683c9cc765c77a12203646af6d9ecdb13f1eb77f559b4bfdbc75e1caf94`.
The Android production chooser selected the preserved validated Retro Rewind
6.12.5 installation without a debug profile extra.

An ignored temporary Xbox-compatible `/dev/uinput` device was registered with
Android's documented `uinput` command contract. Android classified it as an
external keyboard/gamepad/joystick and assigned `/dev/input/event12` with the
Xbox key layout. Title, license, mode, character, vehicle, transmission,
course, acceleration, steering, results, and cold-relaunch navigation used
ordinary controller events. The Android chooser itself used its native touch
button before SDL started.

The race feedback loop read only the opt-in content-free native state trace
and emitted analog-axis/button events to `/dev/input/event12`. It did not write
guest memory, alter lap state, force a finish, inject application input, or
stage a replay. The first registration reached its explicit one-hour lifetime
during the race. The runtime recorded a normal controller disconnect and
reconnect before the same live race completed.

## Race, results, and save result

Mario / Standard Kart M / Manual completed Retro Rewind's GCN Baby Park Time
Trial. The result presentation reported total `17:13.562`, best lap
`00:19.742`, and `A ghost has been created for KartPad!`. The deliberately slow
total includes the rejected open-loop steering attempts and is not performance
or trustworthy timing evidence.

The retained ignored state trace contains 24,500 samples, reached finish stage
4 at race timer tick `62191`, and has SHA-256
`03a1f5bc447c22e21fb37a33f2c81e0cbf8aac2f884a2a958895af397bb86127`.
The ignored race console records the canonical Retro Rewind overlay, controller
connection at line 536, the one-hour-lifetime disconnect at line 762,
reconnection at line 765, and no fatal signature. Its SHA-256 is
`1e2ceafea22b33750d2eb5da4b9bdcebd3036a903de9b12d99f593580d190bd6`.

Advancing the retail results changed the isolated Retro Rewind save from
SHA-256
`3c4aeacd0356a679f261571b53cddfd371a5dc3ff9602be39ca26bdef06ea40e`
to
`7279ad4db655b893f8b2dd1a1427512c4d5799efe9047a94e67b35080c600401`.
The Original save remained out of scope and untouched.

The exact pre-race file was later recovered read-only from an ignored emulator
recovery copy and independently matched the recorded `3c4aeacd...` hash. A
byte comparison against the cold-loaded post-race file found only 12 changed
bytes: four single-byte increments and one four-byte distance/statistic value
inside the initialized license's ordinary race-statistics region, plus the
four-byte core CRC-32. No leaderboard entry, personal-ghost bitfield, or ghost
payload byte changed.

## Cold relaunch

With the controller attached, the app was force-stopped and relaunched through
the production chooser as new PID 7432. It reached the branded Retro Rewind
title, retained the exact post-results save SHA-256
`7279ad4db655b893f8b2dd1a1427512c4d5799efe9047a94e67b35080c600401`,
and accepted controller navigation back to the Baby Park ghost menu. The cold
console records the canonical overlay at line 101, controller channel-zero
connection at line 533, active KPAD reads, and no fatal signature; its SHA-256
is `7ea11624c6e1a1982baabb5735e61834440ec7d88fd2001a2e7c9dd28f7426e6`.

The menu continued to surface only one faster packaged Rewind ghost, so the
initial checkpoint did not claim a visible reload of the much slower run.

A follow-up visible-emulator test force-stopped the app again, launched the
production `KartPadLaunchActivity`, selected the validated Retro Rewind choice
on-screen, reached the branded title as new PID 7904, and navigated by the same
Android-recognized controller back to the course ghost screen. It again showed
only `1/1`. The exact cold-loaded 2,867,200-byte save retained SHA-256
`7279ad4db655b893f8b2dd1a1427512c4d5799efe9047a94e67b35080c600401`.
Read-only semantic inspection found valid `RKSD0006`/`RKPD` structures and an
exact core CRC-32 match, but the only initialized license had personal-ghost
bitfield `0x00000000` and no nonzero primary Time Trial leaderboard timers.
At that point this was interpreted as no retained personal record or ghost.
The later custom-track storage inspection below corrects that RKSYS-only
conclusion: Retro Rewind stores expanded-course records under Pulsar rather
than the base game's 32-slot ghost table.

## Rejected fast-fixture follow-up

Retro Rewind's own Baby Park expert streams were tested only as an ignored
debug diagnostic. The primary `01:15.379` stream identifies Peach, Mach Bike,
Manual and 4,759 frames. A visible emulator retry selected that exact
character, vehicle and course, then tested both Retro Rewind transmission
choices. Both live-player runs consumed the complete stream but diverged,
remained at race stage 2, and stopped against the course boundary. The earlier
alternate `01:26.822` Mario/Standard Kart stream likewise diverged. No native
finish was forced and the save remained exactly `7279ad4d...` afterward.

The retained ignored Outside-variant trace has SHA-256
`7fbd18d913818f07731ef602fc1f898ba3c460b5db9c8cfa97184ee124aa1623`;
the bounded fixture console has SHA-256
`b711da419151d366159698113786592d9d10a21827fbec7742ff5a7a91692bdd`.
These attempts are rejected diagnostics, not race, record, or controller
acceptance. The RKG and trace markers were removed from the app afterward.

## Faster live-controller follow-up and storage correction

A revised bounded feedback driver was attached to a fresh, ordinary-controller
Baby Park Time Trial in the same visible emulator. It emitted only accelerator,
brake, and analog-axis events through Android InputReader. The run reached
native finish stage 4 at race timer tick 9,326 and reported `02:31.465`. The
result screen displayed three valid lap splits, the remaining expanded lap
slots as `99:59.999`, and `A ghost has been created for KartPad!`. The next
screen showed `02:31.465` ahead of `17:13.562` in the session leaderboard.

The ignored 702,567-byte state trace has SHA-256
`c3d5a9bbd0d0b03e0c730b74ab281b23d2215840bf8a24e411a4215542518682`.
Advancing results changed the redirected RKSYS from `7279ad4d...` to
`9c6c7b52c0d1ae7c74489be53123d1943a84917f6869119ca319af5c33b58917`.
The latter has valid `RKSD0006`/`RKPD` structures and matching core CRC; versus
`7279ad4d...`, only seven statistic bytes and the four-byte CRC changed. Its
base-game personal-ghost bitfield remains zero and has no primary timer.

That is expected for this expanded Retro course. Read-only inspection found
the actual course-scoped storage at
`NAND/shared2/Pulsar/RetroRewind6/Ghosts/d6cac6a4`: its 4,544-byte `ldb.pul`
identifies `GCN Baby Park` and has SHA-256
`638186a678f60fea6e3c3b6bab03b8745059c57d4c47c21c4ba3dd989a3838f9`.
The `150` directory contains both durable personal streams:

- `2m31s465.rkg`, 368 bytes, SHA-256
  `1858e595a7d79a8aa144a698e6dce144e7017b683eca621a14d5b77a21d19ff3`;
- `17m13s562.rkg`, 460 bytes, SHA-256
  `3f0b33ecd602601b69fbdf0711941b09884a0ed740047d8ea8657f6748946571`.

The app was force-stopped and relaunched through the production chooser as a
new process. The Pulsar database and both RKGs remained present with the exact
hashes above. Controlled controller navigation returned to 150cc Time Trials
and selected GCN Baby Park. The cold-loaded screen displayed the personal
`KartPad 02:31.465` card as `1/2`, and its Replay action visibly consumed the
stored stream through the exact `02:31.465` finish with recorded splits
`00:35.374`, `00:30.012`, and `00:26.009`.

The replay-selection, active-replay, and exact-finish screenshots have
SHA-256 values `2b682429...`, `925c4bf6...`, and `d6e834d3...`, respectively.
After replay, RKSYS remained `9c6c7b52...`, `ldb.pul` remained `638186a6...`,
and `2m31s465.rkg` remained `1858e595...`. The new-process console has SHA-256
`8f456db1ed18ac0624639fb11c691a18d5a1f4a406284505a0801c9c9d91afc4`
and no fatal signature. Durable storage and visible cold personal replay are
therefore both proven on the emulator.

## Retro runtime lifecycle follow-up

With the exact replay result still visible, the emulator was forced from
rotation 0 to rotation 180. Android delivered a same-size `surfaceChanged`, the
Retro frame remained visible, and the process retained PID 12558. HOME then
delivered `onPause`, `surfaceDestroyed`, and `onStop`. Bringing the existing
singleTask forward produced a hot resume with `onStart`, `onResume`,
`surfaceCreated`, and `surfaceChanged`; the exact result returned in the same
process.

The rotation and post-resume screenshots have SHA-256 values `d80c372d...` and
`fccebe13...`. After restoring automatic rotation 0, the intact-result
screenshot has SHA-256 `a04b7709...`. PID-scoped logcat had no fatal signature,
and RKSYS, `ldb.pul`, and `2m31s465.rkg` retained their exact hashes. This closes
Retro runtime rotation and background/foreground surface recreation on the
emulator without broadening the claim to physical hardware.

## Honest classification

**Pass for production-profile Retro Rewind controller discovery, menu input,
live analog gameplay, normal disconnect/reconnect handling, complete race and
results presentation, post-results save mutation, and byte-stable
controller-attached cold relaunch.** It is not physical-controller, physical-
device, tactile-rumble, audible-quality, sustained-performance, trustworthy-
timing, or release acceptance. Durable Retro custom-track personal-record/ghost
storage and visible full replay across a production-path cold relaunch now
pass. No APK, AAB, game data, save, trace, console, or screenshot was published.
