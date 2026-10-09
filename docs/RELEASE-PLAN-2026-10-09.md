# KartPad compatibility release plan

Owner: Chris. Working date: 9 October 2026, Japan time.
Target: KartPad 0.7.15, build 260, subject to a final version check.
Baseline: main `91c208ef9b98467b3f5e3ba92324c0446daac6f1`; public 0.7.14/build 258.
Status: implementation and candidate builds complete; draft PR #440; release acceptance pending.

Restore compatibility with Retro Rewind 6.13.1 and include small corrections
with reproduced defects. Release today only if the exact packages preserve
player data and complete the gameplay and production-online checks. Optional
changes must not displace those checks.

## Selected scope

| Work | Exact boundary | Acceptance |
| --- | --- | --- |
| Retro Rewind 6.13.1 | Verified official full pack plus required official update; pins, updater, builder, mobile installers and matching translation/pack metadata | Fresh installation and 6.12.8 replacement; exact final code/XML/version; Original and Retro race/relaunch; production login, matchmaking, race, results and reconnect |
| Android save and ghost writes | Isolated correction from `9f82633d`, not the later identity/Mii refactor | Staging/backup/active-write failures reject success, retain recovery and preserve other profiles; retry succeeds |
| Android ghost recovery | Chooser action calling existing `cancelPendingGhost`, only with no paused game; explicit confirmation | Failed import blocks launch; chooser cancellation clears only its pending request; save/backup bytes survive; launch works again |
| Apple motion correction | Existing callback correction from `4ac13dc7`: neutral steering when flat, continue shake sampling; rearm after settling | Production callback before/after control, native motion checks and physical tilt/shake/resume/controller takeover |
| Original compressed ghost repair | PR #436 / `9810a1f0`; no Retro ghost transfer | Valid expanded replay table, checksums and unrelated-save preservation; exact new pack import/restart/replay/export and a normal race |
| iOS Sound controls | PR #420, `439f2902` plus persistence correction `e279e6d5` | Actual music/effects controls, default behavior, background/Done/relaunch and other-app audio on hardware |

Every non-Retro item can be excluded if its required check fails or cannot be
completed. Sound and Original ghost repair are the first optional scope to drop.
Keep a separate commit per correction so a failing optional change can be
removed without dropping Retro compatibility. Do not remove it by rewriting
another task's branch.

## Deliberately separate work

Do not merge draft #416 wholesale: it includes an upstream runtime/translator
sync and broader identity/Mii recovery changes. Keep new Android shake UI,
custom icons, Retro ghost transfer (#375/#295), graphics experiments and CPU
optimizations separate. #437 already contains a next-build commitment; flag
its rescheduling in the release decision rather than silently claiming it done.
No fix here establishes complete identity migration (#234), affected-GPU
resolution, or a performance improvement.

## Retro inputs and implementation boundaries

The official version feed reports 6.13.1. At 09:27 JST the official install
manifest points to `6.13.0-full.zip`; `6.13.1-full.zip` returns HTTP 404. The
6.13.1 incremental ZIP is available. The current updater invents the full URL
from the latest version and therefore cannot complete this update unchanged.

Read the official install/version/deletion manifests. Pin complete archive
bytes and SHA-256 values, final `Code.pul`, XML and version, and verify the
production WFC payload signature. The reviewed full pack's Code.pul differs
from 6.12.8; the 6.13.1 patch contains no Code.pul. Recheck all downloaded bytes.
Do not relabel 6.13.0 as 6.13.1, disable version checks, or publish a repack of
the third-party asset archive.

Prefer an official complete 6.13.1 archive if one appears. Otherwise add only
the pinned base-plus-update support required for this release, with ordered
staging and one final validation/activation. A rejected update must not replace
the working pack or its saves. Downloads remain official; runtime acceptance
is tied to the release profile rather than arbitrary future updates.

Review these consumers together:

- `scripts/update-retro-rewind-profile.py` and `builder/profiles/mkwii-rmcp01-rev0.json`.
- `builder/kartpad_builder/retro_rewind.py`, release-header and Android-contract generators.
- Android Retro download, worker, extraction, pipeline, validation and storage classes.
- `apple/ios/KartPadRetroRewindInstaller.mm` and other users of generated constants.
- Translation scripts, measured function/dispatch gates, dependency source provenance.
- `padmint.json`, including the hard-coded Mac extracted Retro version path.

Do not advance unrelated dependency pins. If the new code requires a translator
correction, reproduce the failure and port the smallest supported fix. Preserve
strict archive/path/expanded-size bounds and payload signatures.

## Execution order

1. Finalize and review this plan against current source, release instructions
   and upstream input availability. Record corrections in the log before edits.
2. Obtain and inspect inputs in ignored private storage. Review new executable
   content and implement the smallest matching install contract. Initial
   decision checkpoint: 60–90 minutes. If a broad redesign is necessary, record
   it and remove optional scope before reconsidering the release schedule.
3. Integrate the narrow corrections as separate commits. Reproduce before/after
   behavior where feasible; reuse existing regression suites. Do not repeat
   passing tests unless code changes or a new risk warrants it.
4. Run focused and repository checks, verify maintained source pins, regenerate
   translation and matching packs. New counts must be measured and reviewed,
   never accepted just to make a check green.
5. Build final Android and Apple/PadMint artifacts from clean exact source.
   Validate app/pack fingerprints. Use current signing identities and forward
   version/build numbers. Preserve public source/license/provenance boundaries.
6. Validate exact fresh and upgrade paths. Android: 0.7.14 update and fresh data
   import both reach a race. Apple: back up/read back Documents and Library
   before any in-place physical install; verify save/identity/settings afterward.
   Never uninstall or reset a player app to make an update pass.
7. Exercise Original and Retro, a completed race/results and cold relaunch,
   touch/controller handoff and each included correction. Test production
   Retro WFC login, matchmaking, race, results and reconnect with another client.
   A login or emulator-only pass is insufficient for the online release claim.
8. Review final diff, tests, source/package provenance and release copy. Publish
   only after the required acceptance gates; download hosted assets afresh,
   compare checksums/signature, re-audit and verify the actual Android updater.

## Release delivery and unresolved gates

Latest 0.7.14 delivers an Android APK, a game-code-free iOS IPA for PadMint,
recipe, source, notices and checksums. Current `AGENTS.md` still lists additional
ready-to-play Apple artifacts under an older 4 October decision, while the
5 October release/README says Apple builds use PadMint. Reconcile the stale
release instruction before publication; do not silently broaden public assets.
Prepare the established 0.7.14 delivery set first. Preserve the existing Android
ready-to-play exception and never publish disc files, private keys or saves.

Source tests, compilation, package audits, emulator gameplay, physical gameplay,
production online and reporter acceptance are separate results. Missing hardware
or peer/service availability does not turn a candidate into a verified release.
Do useful source/package work first and identify the exact remaining gate.

No issue is closed merely because code was included. #411 can close after the
requested audio behavior is accepted; #377 needs the real upgrade path. Original
ghost repair does not close #295, and storage hardening does not close #234.

## Plan review checklist

- [x] Every selected change has a concrete source boundary and regression gate.
- [x] Official input layout and every version/profile consumer are accounted for.
- [x] New recovery actions preserve live state and cannot run over a paused game.
- [x] Optional fixes can be excluded without an upstream-wide merge.
- [x] Exact package, physical and online requirements remain explicit.
- [x] Dirty and concurrent work is preserved; no new sibling clone under GitHub.

## Execution log

Append dated decisions and results here. Keep raw logs, game inputs and generated
code in ignored private/build directories, not this document.

- 09:27 JST: confirmed main unchanged, new full 6.13.1 archive still unavailable,
  official install manifest still 6.13.0. Created an isolated managed worktree
  because the primary checkout is dirty and other candidates have broader scope.
- Earlier focused review: save/ghost and identity/Mii host/JNI suites passed with
  synthetic data. Apple callback probe reproduced flat-device steering/shake
  failure before the existing correction and passed afterward. These are
  starting evidence, not validation of a future combined release.

- 09:33 JST: plan double-check complete. Verified the save correction can be
  taken without the identity/Mii refactor; verified the chooser recovery gap
  exists in main and must recheck paused state at confirmation. Found the Mac
  PadMint recipe also hard-codes 6.12.8 and added it to the update boundary.
  Reviewed the generated Apple/Android contracts and installer staging paths.
  Corrected the plan so any unaccepted non-Retro item can be dropped. The
  older ready-to-play Apple instruction conflicts with current release delivery;
  that publication decision remains explicit, without blocking implementation.

- 09:48 JST: the candidate includes the five narrow corrections as independent
  commits. Android save/ghost JNI fault tests, Original compressed ghost tests,
  sound persistence and native Apple motion checks passed. The current chooser
  compiles and exposes recovery from Help while no game is paused.
- Verified both official archives completely (ZIP CRCs and SHA-256). Full pack:
  1,938,862,721 bytes, SHA-256
  `2d6fa8bce76ee056d3d1e4370296a89af71685b57909978c52ff167d4c6248c2`;
  patch: 29,403,976 bytes, SHA-256
  `ee32da6fde457700cb60ad173e163ecd05a9ed61b41e39bea6b003406be3e6ce`.
  Selected expansion is 2,189,509,451 plus 35,908,480 bytes; the base keeps its
  existing 2.2 GB limit and the update is bounded separately to 36 MB.
- Implemented one pinned base plus one pinned update in the builder and mobile
  installers. Each archive retains verification and extraction bounds. Final
  version/code/XML validation precedes activation. Updater reads the official
  installation manifest and stops for multi-update chains or content deletions.
  Both builder and native Apple extraction accepted the actual official pair.
  Android download, extraction, pipeline, space and worker-policy tests passed.
- Fresh translation passed without changing dependency pins: 29,637 generated
  base functions, 29,065 retained base functions, 4,124 Retro functions, zero
  translation failures. Both native-overridden mod patches match the prior
  build; no new override was accepted. Production payload signature passed.
- The 347-test Python suite exposed two old-version assertions and one absent
  local JSON test JAR. After updating the assertions to measured release pins
  and supplying the dependency, all affected tests passed in a 23-test rerun.
  Kotlin compilation and an initial Android app build passed. Full Android pack
  and iOS app builds are running; physical and production-online gates remain.


- 10:28 JST: Android and iOS application and matching game-pack builds completed
  from clean source `daf662ec704fec7700326e80d72f01b225822036`. Both game packs
  passed their state checks. The app manifests record that exact source revision
  with `source_dirty: false`. Documentation updates after that revision do not
  change the built product. Draft PR: https://github.com/chrissotraidis/kartpad/pull/440.
- GitHub regression CI passed on that source. Repository Android APK/AAB and
  private iOS candidate audits passed. The game-code-free iOS IPA passed PadMint
  audit with zero address-named functions. Android PadMint audit reports 29,064
  address-named symbols and the embedded-program-section marker. The verified
  public 0.7.14 APK produces the same two findings. This is **not** a clean PadMint
  pass: reconcile the second finding with the repository's ready-to-play exception
  before publication. No signing key, disc-file or private-path finding occurred.
  The historical `audit-public-unsigned-ipa.py` is tied to the 0.5.3 release record
  and is not evidence for this candidate; it was not weakened to accept it.
- Fresh owned Android emulator: installed the test APK, imported game data through
  the actual Files picker, created a license, entered Original Luigi Circuit and
  accelerated. No player device or existing app was reset. Emulator audio was
  disabled, so this supplies no audio acceptance.
- Android ghost recovery: injected a synthetic invalid request only into this
  disposable test installation, confirmed launch was blocked, confirmed Keep
  Import retained it, then cancelled through Help. Save SHA-256 values before
  and after matched; the request and recovery button disappeared. Retained-backup
  preservation is covered by host fault tests, not this fresh emulator fixture.
- Android Retro worker: reused the fully verified official base archive in its
  cache, downloaded the actual 6.13.1 update over the network, extracted/merged
  both and passed final installation validation. This checks a cached-base install,
  not an end-to-end 1.94 GB network download or a 6.12.8 replacement. Retro reached
  SNES Mario Circuit 1 and responded to acceleration. After force-stop and explicit
  cold launch, the chooser retained both ready states and 6.13.1; Retro reached its
  title again. Neither test completed a race/results. Horizontal menu bands were
  visible in both modes, while race scenes rendered; comparison against the prior
  build on this emulator remains necessary before classifying that observation.
- Saved local screenshots, checksums and logs under `build/release-0715/`.
  Stopped only the task-owned emulator (`emulator-5580`) after testing. Its private
  AVD and candidate artifacts remain for follow-up. The dirty primary checkout
  was untouched. The managed `kartpad-0715` worktree remains attached to this
  chat and contains the branch plus needed ignored build inputs/artifacts.

## Candidate artifacts and next actions

These are private test/build outputs, **not published release assets**. Paths are
relative to this worktree. Complete SHA-256 values are retained in
`build/release-0715/candidate-sha256.txt`.

| Artifact | Location | Current use |
| --- | --- | --- |
| Android test APK | `private/release-0715/KartPad-v0.7.15-test-only.apk` | Debug signer; fresh owned emulator only; never publish or install over a player's release |
| Android unsigned bundle | `private/release-0715/KartPad-v0.7.15-unsigned.aab` | Input to the established release signing path |
| iOS PadMint IPA | `build/ios-app/20261009-094516/out/KartPad-v0.7.15-ios-unsigned.ipa` | Game-code-free; audit passed |
| Private iOS device candidate | `private/release-0715/KartPad-v0.7.15-ios-device-candidate.ipa` | Matching game pack included; needs device signing/install/acceptance |

Proceed in this order when the required inputs are available:

1. Obtain the existing Android Community Release keystore path, password-file
   path and alias. Never create a replacement key. Sign, re-audit, then exercise
   an actual update over public 0.7.14 and a fresh import with the final package.
2. Unlock the attached iPad. Back up and read back Documents and Library before
   signing/installing in place. Verify identity/saves and test motion, controller
   takeover, sound/background/relaunch and compressed ghost import/replay/export.
   The connected physical Android device is currently unauthorized; no physical
   acceptance was claimed. The request to unlock/provide signing paths is pending.
3. Test old Retro pack replacement and complete offline races/results/relaunch.
   Compare the emulator menu rendering observation with 0.7.14 or real hardware.
4. With a second current Retro client, complete production WFC login, matchmaking,
   race, results and reconnect. Peer availability was requested and is pending.
5. Drop any optional correction whose acceptance cannot be completed, rebuild
   the changed platforms and repeat the affected gates. Resolve the delivery
   instruction and Android audit-exception questions above; then review exact
   assets and release notes, publish, and verify hosted downloads and updater.

No release, merge or issue closure has occurred. The candidate is ready for
these acceptance steps, not yet approved as a working public online release.

- Follow-up, 10:56 JST: physical iPad became accessible. Backed up Documents and
  Library (9,397 files, 9,682,622,210 bytes), hashed the full backup, and independently
  read back 34 save/Mii/identity/settings/retained-backup files. Installed the signed
  0.7.15/build 260 candidate over private 0.8.0/build 257 without uninstalling;
  all 34 critical hashes matched after install. Actual gameplay remains pending.
- The attempted launch-argument shortcut was rejected by the runtime's existing
  no-command-line-options guard. Relaunched normally; this was a test invocation
  error, not evidence of a game crash. QuickTime screen mirroring is available;
  device taps were requested for the physical update path.
- Found a real Apple pack-upgrade defect during preservation review: activation
  replaced the entire RetroRewind parent, including `riivolution/save`. Android
  already preserves that directory. Added equivalent Apple copy-and-verify before
  activation; a copy error leaves the active installation intact. The exact old
  activation reproduced save loss in an isolated native fixture. The fixed path
  passed preservation of RetroWFC/RetroWFC2 saves, ghosts, unrelated NAND/backups,
  destination-conflict rejection, symlink rejection and fresh installation. This
  is required release scope. Earlier Apple binaries are superseded and must not
  be used to update an existing Retro pack; rebuilt Apple candidates are required.
- A separate owned emulator with public 0.7.14 imported game data and reached the
  title, but injected controls did not advance reliably into its menus. Therefore
  the menu-band comparison is inconclusive; no baseline-equivalence claim was
  made. That emulator was stopped, retaining its private state. Preparing a fresh
  iPad simulator for direct UI validation while physical interaction is pending.
