# Android A2 state-trace player race

Date: 2026-09-03

> Subsequent correction (2026-09-03): the cold-relaunch input observation
> below was a cadence false alarm. The same fresh process advanced through
> title, license selection, and Main Menu with normally spaced events. A later
> virtual-controller run also proved SDL button/analog input, disconnect,
> reconnect, and hot lifecycle behavior; see
> [`a2-virtual-controller-hotplug.md`](a2-virtual-controller-hotplug.md).
> The ghost-save failure remains unaccepted as save proof and is consistent
> with the native slow-run ghost-recorder overflow precedent.

## Subgoal

Expose the existing content-free native race-state trace to Android debug
builds through an app-private, marker-gated path, then use only ordinary
Android keyboard events through the shipping Classic/KPAD input bridge to
complete a player race and reach retail results.

## Implementation

`KartPadActivity` now recognizes the debug-only app-private marker
`KartPad/Diagnostics/StateTrace.enable` before SDL starts. When present it
sets `KARTPAD_STATE_TRACE` to the fixed app-private output
`KartPad/Diagnostics/StateTrace.csv`; when absent it clears the variable.
Release builds never inspect the marker. The trace contains only counters,
stage, position, velocity, quaternion, speed, and movement-direction values.
It contains no game content, controller recording, save data, or identifiers.

The exact final game APK is 103,434,784 bytes with SHA-256
`94b7049a855cba90f9040f55fd56c894c989186832b3f63eb67ac29e48d4584a`.
Debug and release Kotlin compilation, lint, the complete private ARM64 link,
and the strict package/privacy audit pass.

## Emulator result

An API 36 / 4 KiB ARM64 AVD cold-launched the Original profile and entered an
ordinary Time Trial on N64 Mario Raceway. A local feedback driver read only
the content-free trace and emitted normal `U`/`M`/`A`/`D` Android key events;
it did not write guest state, force a checkpoint, change lap state, or force a
finish. One supervised recovery spent a legitimately collected mushroom
through the normal Left Shift / Classic L item binding. A second supervised
reverse-and-steer recovery freed the kart from the final outer wall.

The retail game reached stage 4 after all three laps. The private trace has
24,279 total samples and SHA-256
`c25c769fcbf9ceff50c74f4063ce7ee633b72cfab691138a46a98f9724f7a0b7`.
`scripts/summarize-mkw-state-trace.py --require-complete` accepts one
19,032-sample race segment from race time 240 through 19,271 and the following
finish stage. The visible results screen reported:

- total `05:17.517`;
- lap 1 `01:32.876`;
- lap 2 `01:20.695`; and
- lap 3 `02:23.946`.

The finish and results captures remain ignored and private. Their SHA-256
values are respectively
`0b1cdefaa6d1c344d4e122d50b75e7f173e07c2c27d7545154a93f30a8ab2ce5`
and
`69c34998ae3e4bc7f30ed1b6dbe9fc809f77c1c45c5d5870c6771a7e518c9245`.

The runtime stayed alive throughout the extended race. The same test session
also reproduced one silent process exit during an earlier startup/restart;
Android recorded no Java exception, fatal signal, tombstone, or OOM, and a
controlled retry completed the race. This remains unresolved.

## Relaunch and save boundary

The game displayed `Ghost data could not be saved.` after the result, so this
run is not evidence that a new Time Trial ghost or race record was committed.
The staged save did remain byte-identical across a force-stop and cold
relaunch, and the fresh process reached the title screen. Injected keyboard
events then failed to advance the title in that fresh process despite the app
retaining focus. Controller-after-cold-relaunch therefore remains a defect,
not a passing result.

Before shutdown, the exact pre-test in-sandbox save was restored. Its backup
and restored SHA-256 both matched
`aafe8b72a6a3ce823d13095a3237adaae9f540f975e6e04a7f4dd47fba188dd1`.
The RKG, keyboard-steer, trace marker, trace output, and temporary save backup
were removed from the app sandbox. No private file or APK/AAB was published.

## Classification

**Pass** for the debug app-private trace gate and for one complete
normal-input emulator player race through retail finish and results.

**Inconclusive/open** for post-race save creation, controller input after cold
relaunch, attached SDL-controller input/rumble, audible audio, physical Android
hardware, and release readiness. A2 remains open.
