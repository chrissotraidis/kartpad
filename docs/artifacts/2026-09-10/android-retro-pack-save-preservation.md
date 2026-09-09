# Preserve redirected saves when replacing the Android Retro pack

Source investigation prompted by [issue #169](https://github.com/chrissotraidis/kartpad/issues/169)
found a reproducible pack-replacement defect. It does not establish the cause of
the reporter's ordinary-exit loss on build 21. No reporter logs or exact lost-data
category are available yet; support remains coordinator-owned.

## Defect and correction

`RetroRewindInstallStorage.activateValidatedStaging` moved the old RetroRewind
root to rollback, activated the staged pack, then deleted rollback. That also
deleted `riivolution/save`, including RetroWFC and RetroWFC2 redirected license
saves. The same implementation exists in v0.4.10-android.1, local build 61 and
origin/main at 19f946d. Successful replacement is the trigger; ordinary chooser
recovery does not delete the active root. Missing redirected saves can subsequently
be initialized or cloned, which is distinct from saving successfully on exit.

The correction copies retained `riivolution/save` into the staged pack before
either root moves. Existing user files override any staged defaults. All save
subdirectories are retained, including Separate Save. Copy failures leave the
active pack untouched; activation rollback retains its previous behavior. Links,
special files and incompatible destination entries fail before activation.
Pulsar records/ghosts/ratings under `NAND/shared2/Pulsar/RetroRewind6` are outside
the replaced pack and remain untouched. No native runtime or Apple source changes.

## Evidence

- Added regression failed on the unchanged implementation: replacement overwrote
  `riivolution/save/RetroWFC/RMCP/rksys.dat` with a staged default. The same case
  also checks the separate profile, another retained save entry, pack replacement,
  startup recovery and an untouched Pulsar sentinel.
- All 13 storage cases pass with the correction on the pinned host JDK and physical
  Android ART. Failure cases cover source/destination links, incompatible target
  type, activation rollback and existing recovery boundaries. Android execution
  used a D8-built test JAR through app_process with disposable shell-owned files
  under a unique /data/local/tmp directory, removed after testing. It did not
  access KartPad data, replace the user's pack or install a test package.
- Existing installation pipeline, content validation, worker policy and storage
  space checks pass. The space check initially failed because its literal total
  was stale by 211 bytes after the pinned archive changed; updated expected total
  to 4,327,477,144 = 1,859,041,688 archive + 2,200,000,000 expanded + 268,435,456
  reserve. The production space calculation is unchanged. Save copying may need
  additional free space; any copy error aborts before active data moves.
- Android compileDebugJavaWithJavac and lintDebug pass with the retained dual-game
  configuration. Existing chooser accessibility deprecation warning remains.
- This is a reliability correction, not an FPS improvement. No real pack update,
  power-loss recovery or reporter-device reproduction is claimed from these tests.

## Remaining paths and next steps

Current native NAND safe/plain close paths already flush and publish shadow saves;
IOS/Pulsar uses a different direct-file path. Ordinary exit before guest save
completion, separate-profile selection and actual I/O errors remain hypotheses.
Do not force save completion or commit an unfinished shadow when exiting. Native
write routines also ignore a fflush return; that merits a separate fault-injected
investigation, not a claim that it caused this report.

Private build/retro-save-preservation contains test JAR, ART result and Android
compile/lint log. Prepare the next local APK using the unchanged accepted native
payload, verify signing/package identity and perform a backed-up in-place update.
Do not exercise pack replacement against the owner's real saves as a regression.
The physical menu-delay profile remains the next performance measurement.

## Independent integration review

The focused commit applies to current main; all 13 storage cases and the space,
pipeline, content and worker-policy checks pass in the integration checkout.
Independent Medium review found no blocker for replacement with guest saves
quiescent. Copy failure preserves the installed tree; activation failure restores
it or retains rollback if restoration fails.

Concurrent gameplay/update safety is not established: storage and worker do not
lock guest writes, and a worker can outlive the installer screen. The healthy
ready-pack UI hides installation, but any future update/reinstall flow needs an
explicit runtime-stop gate. Extra duplicated save bytes are not included in the
space estimate and may cause a safe copy failure. Actual pack replacement,
power-loss recovery and #169 ordinary-exit attribution remain unverified.
