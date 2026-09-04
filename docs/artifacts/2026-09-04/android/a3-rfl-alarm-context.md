# Android A3 RFL alarm context isolation

Date: 2026-09-04

## Scope

This is a bounded API 36 ARM64 emulator regression for explicit Original to
Retro Rewind to Original switching. It covers a translated-runtime callback
failure discovered during that sequence. It is not controller-race,
performance, physical-device, or release acceptance.

## Reproduction and diagnosis

Across eight observed pre-fix Original launches, seven completed: six were
base-only cold-launch controls, while one initial switch-sequence launch also
passed. The return to Original after a successful Retro Rewind launch exited
while initializing Miis. Its private crash record identified a missing target
at `MiiManager::Init+0x134`: the second heap allocation saw r30 changed from the
expected guest heap pointer `0x9011299c` to `0x909999e0`, with a zero indirect
call target. Both the Original and Retro save hashes remained byte-identical.

`RFLiIsWorking_HLE_800bd860` pumped guest alarm callbacks using the translated
caller's live `CpuContext`. A callback could consequently publish its return
registers into the interrupted `RFLInitRes` caller, including its callee-saved
r30 heap pointer. The timing dependence explains why most cold launches passed
and why the earlier save-focused controls could not reproduce the exit.

## Repair

The RFL polling override now seeds `GuestInterruptCallbackContext` from the
current guest thread and executes the alarm queue against that private register
copy. Callback register writes therefore cannot escape into the translated
caller. Scheduler switching is suppressed only while that bounded queue is
pumped, including exception-safe restoration of the disable count.

The source change is carried by
`patches/wiicompiled-rfl-alarm-context.patch`. Both normal iOS preparation and
the G7 preparation path apply it; Android inherits the normal iOS patch stack.
A fresh Android runtime preparation reproduced the changed source byte-for-byte.
The affected Apple arm64 guest-system unity object also compiled successfully.

## Emulator result

- Ten of ten patched Original cold launches remained alive after 28 seconds.
- A subsequent visible-emulator sequence reached and retained Original,
  Retro Rewind, and Original again. The final Original process remained alive
  beyond 40 seconds and continued into the title attract sequence.
- The Original save remained SHA-256
  `708c7a040e0cfe6cd815690e63f46d1678f17899bce0e786f7480030830f1d13`.
- The Retro save remained SHA-256
  `3c4aeacd0356a679f261571b53cddfd371a5dc3ff9602be39ca26bdef06ea40e`.
- No new missing-target crash record appeared during the patched switch run.
- The local-only ARM64 debug APK passed the strict package/privacy audit at
  SHA-256 `2ba4b4acf7a395c3d810ff81c0327ad15f9bfbbcbcd76da026ec37444ff7b7d2`.

## Classification

**Pass for the reproduced RFL callback corruption and this bounded emulator
mode-switch regression.** The evidence changes the earlier unexplained
intermittent Mii exit into a diagnosed and repaired guest-context isolation
defect. A production mode chooser, controller-driven Retro Rewind race and
save/relaunch, trustworthy timing, physical controller/audio/rumble, physical
Android hardware, and release acceptance remain open. No APK, AAB, save, disc,
pack, or private crash record was published.
