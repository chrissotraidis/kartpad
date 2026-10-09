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
recipe, source, notices and checksums. The draft follows that six-file delivery
set. The release-paradigm review reconciled the stale 4 October ready-to-play
Apple instructions with the newer published distribution model. Personal Apple
packages remain private. Preserve the Android ready-to-play exception and never
publish disc files, private keys or saves.

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
| iOS PadMint IPA | `private/release-0715/save-fix/KartPad-v0.7.15-ios-unsigned.ipa` | Corrected Apple installer; game-code-free; audit passed |
| Private iOS device candidate | `private/release-0715/save-fix/KartPad-v0.7.15-ios-device-candidate.ipa` | Corrected installer; signed copy installed in place; gameplay acceptance pending |

Proceed in this order when the required inputs are available:

1. Obtain the existing Android Community Release keystore path, password-file
   path and alias. Never create a replacement key. Sign, re-audit, then exercise
   an actual update over public 0.7.14 and a fresh import with the final package.
2. Complete physical iPad gameplay acceptance on the corrected candidate now
   installed. Documents/Library backup, independent critical-file readback and
   in-place installation are complete. Verify motion/controller takeover,
   sound/background/relaunch and compressed ghost import/replay/export. The
   connected physical Android device remains unauthorized; no physical Android
   acceptance was claimed. Physical iPad interaction was requested and is pending.
3. Complete offline races/results/relaunch. Actual 6.12.8 pack replacement and
   save-marker preservation passed in the iPad simulator; physical replacement
   remains open. Android menu-band comparison against 0.7.14 was inconclusive.
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

- 11:03 JST: corrected Apple product source is `d97eadfc4110be38cce1aca0387c8516cca06a28`.
  Rebuilt the physical app, rechecked the existing game's pack state against it,
  repackaged and passed repository and game-code-free PadMint audits. The native
  full installer accepted the real official base and live-downloaded patch over
  a synthetic 6.12.8 installation and preserved its save bytes. Installed the
  corrected signed copy on the iPad; 34 critical hashes matched both immediately
  before and after that install. CI passed on d97eadfc. Android binaries are
  unchanged by this Apple-only correction.
- Corrected iOS PadMint IPA SHA-256:
  `bba58a5a579c3a82ffa2b0ec01bb2cf6610d72c13ba513424982061c97ace71f`.
  Corrected private iOS IPA SHA-256:
  `b7ada9f062869d262b5e92014a8f4cc150b6cc6e2d774b03e108c131b9828d45`.
  Both reside under `private/release-0715/save-fix/`. Earlier iOS packages are
  retained as superseded evidence only. Full backup and readback manifests are
  private under `private/release-0715/`; nothing containing player data was pushed.

- 11:10 JST: fresh iPad simulator build passed its application audit. Seeded only
  game assets plus an actual old 6.12.8 pack (no player identity), added a synthetic
  save marker, and invoked the existing simulator installer entry point with the
  pinned base ZIP. The real iOS installer downloaded the patch, completed upgrade
  and final validation, reported 6.13.1, and retained identical save-marker bytes.
  Logs/screenshots are in `build/release-0715/`. The local Xcode installation has
  simulator CLI/runtime support but no Simulator.app UI, limiting interactive
  simulator control; do not count this as touch, motion or audio acceptance.

- 11:13 JST: the iPad simulator reached the Retro title after upgrade using its
  ordinary preferred-game setting. No command-line arguments or synthetic game
  input were used for that launch. The historical simulator build target retains
  old default version metadata, so the private simulator test copy was stamped
  from current version.json before continued testing. This does not affect the
  physical or PadMint candidates, already verified as 0.7.15/build 260.

- Original also launched into its opening/attract presentation on the iPad
  simulator. This is launch/rendering evidence, not a driven race. Stopped only
  the owned simulator after the bounded checks; its installed app/data remain.
  Corrected physical iPad candidate remains installed for hands-on acceptance.

- 12:34 JST, release preparation: located the existing Community Release identity
  in the maintainer's private Android signing directory. Its certificate matches
  published 0.7.14 (`c1dbe0a0d72d830a5779476b346a750d0a37515adef992cad2f3863058f7f2f2`).
  No key was created or rotated. Derived the final universal APK twice from the
  audited AAB; both are byte-identical, 65,329,029 bytes, SHA-256
  `0b8fc9cca8929379fbcaff0570c4dfe59aa1d038a5e760a26a49198277267f56`.
- Installed this APK over the verified public 0.7.14 APK on the owned baseline
  emulator. All 2,077 existing files in files/shared_prefs matched SHA-256 before
  and immediately after installation, including rksys.dat, configuration and
  controller settings. No uninstall was used for this upgrade. A separate fresh
  owned emulator imported the extracted-game-data ZIP through Android's picker.
  The fresh emulator had one system_server/WifiHandlerThread crash during initial
  boot; Android recovered and import completed. This was not a KartPad crash.
  A cold application relaunch resolved the earlier inconclusive title-input test;
  both signed-APK fixtures then accepted controls and created a licence normally.
- Assembled the established six-file delivery set under ignored
  `build/release-0715/publish/`: release APK, corrected game-code-free PadMint IPA,
  recipe, deterministic tracked-source snapshot, notices and SHA256SUMS. Source
  snapshot uses d97eadfc plus every exact runtime/translator gitlink; it includes
  both platform app sources, with Android's binary still built at daf662ec before
  the Apple-only preservation correction. Final merge/source reconciliation is
  still required before publication.
- Audits: repository APK audit passed on local and downloaded draft copies.
  PadMint IPA, notices and recipe passed. APK has only the two translated-code
  findings explicitly accepted in RELEASE-CHECKLIST step 6. Source findings were
  reviewed: the data-section marker is the translator's source string, and
  address-named definitions are small synthetic translator test fixtures in
  BaseManifestBuilderTests.cs and TranslatedBuildShardEmitterTests.cs. The latter
  has two pinned-source variants differing in test assertions and direct-call
  lowering expectations; no generated game source was added. No private/ref/
  bootstrap members exist in the source archive. Preserve raw audit findings;
  do not describe this as a blanket PadMint PASS or weaken the scanner.
- Created GitHub **draft** release v0.7.15 with all six assets and explicit open
  acceptance gates. Downloaded every draft asset with maintainer authentication:
  all five SHA256SUMS entries matched, and GitHub asset digests match local files.
  Anonymous download verification must follow actual publication. Public latest
  remains v0.7.14. Draft URL:
  https://github.com/chrissotraidis/kartpad/releases/tag/untagged-75cebedb4218bd623e96
  Nothing has been published, merged or closed.

- 12:40 JST: both exact release-signed APK fixtures reached Original Luigi Circuit
  (50cc Mushroom Cup), accepted acceleration and rendered the race. Fresh install
  used the real system-picker ZIP import; upgrade used the public 0.7.14 app and
  preserved its existing rksys.dat/configuration before launch. Screenshots are
  public-5584-race.png and public-upgrade-race.png in the ignored evidence folder.
  This satisfies the Android fresh/upgrade race-start gate, not completed-race,
  production online or physical-device acceptance. No source change was needed
  to recover input after the cold relaunch. Retained both emulator data sets.

- 12:49 JST: final signed APK also passed the real Retro installer and reached
  SNES Mario Circuit 1, accepting acceleration. Only the verified official base
  archive was pre-positioned in the owned emulator cache; the actual release
  worker downloaded the patch, extracted, validated and activated 6.13.1. No game
  code or installer behavior was substituted. Evidence: public-retro-race.png
  and public-fresh-install.log. Completed races/results, production online and
  the physical Apple motion/audio/ghost checks remain pending.

## Release-paradigm review (9 October, after the draft build)

The current release model is Android APK plus PadMint inputs for Apple, as
published in 0.7.14. Reconciled the stale 4 October asset instructions in
AGENTS.md, RELEASE-CHECKLIST and the distribution history in RIGHTS_AND_LICENSES.
Kept all identity, data-preservation, audit and acceptance requirements. The
recipe's personal-output publication flag remains false; its explanation no
longer incorrectly describes maintainer releases as source-only.

Found and corrected the Mac recipe's preflight: `doctor` only verifies cached
dependencies, while the following translate step requires the pinned Retro pack
and payload. It now invokes the existing `bootstrap` path, which fetches and
verifies those inputs and the Mac Dawn dependency. This is a recipe correction;
a fresh complete Mac build/gameplay remains unverified. No Android or Apple app
source changed during this review.

Rechecked the exact signed APK audit, signing certificate, both independently
derived APKs and all existing asset hashes. Version remains 0.7.15/build 260;
public latest remains 0.7.14. Updated status and the maintenance board with a
candidate-only entry, preserving historical and reporter-acceptance boundaries.

The draft is not ready to publish simply by pressing Publish. Before finalizing:

1. Complete offline race/results, production online race/results/reconnect, and
   the physical Apple checks for included motion/audio/ghost fixes. Accept or
   remove optional fixes based on those results. Validate the affected Mac path.
2. Merge the accepted source, check final source/tree identity, regenerate the
   source snapshot from the full merge SHA, and rebuild/retest affected binaries
   when their inputs change. Android was built at daf662ec; iOS at d97eadfc. The
   only non-document changes between those two commits were the Apple installer
   correction and its regression test. The current recipe differs from both.
3. Keep the final six-file manifest consistent, retarget the draft to the full
   merge SHA, and obtain the owner's final publication instruction. Do not upload
   private Apple test packages, player backups or signing material.
4. After publication, verify anonymous downloads, signatures and all checksums,
   then the actual Android updater and latest-release state. Authenticated draft
   downloads do not satisfy the anonymous/public-updater gate.

This review refreshes the draft recipe, notices, source archive and checksums;
the already-tested APK and game-code-free iOS IPA retain their exact hashes.

## Sanity check before publication (9 October, 15:35 JST)

- Production Retro WFC: the exact release-signed APK, on the fresh emulator with
  verified Retro Rewind 6.13.1, connected and showed "Welcome to Retro WFC",
  server status and the VS/Other/Battle Worldwide menu with about 80 players
  online. Login is verified; matchmaking, an online race, results and reconnect
  were not exercised (no second client). Disconnected and stopped the emulator.
  Evidence: online-c4.png and online-wfc-menu.png in the ignored evidence folder.
- Claims versus binaries: every release-note item is new since 0.7.14 and is in
  the binary that ships it. The APK (daf662ec) contains the Android save/ghost
  changes and the shared compressed-ghost fix (Android reaches it through
  `nativeGhostTransfer`). The PadMint IPA (d97eadfc) contains the Apple installer,
  sound, motion and ghost changes. Android build inputs are identical from
  daf662ec through the release branch head.
- 0.7.14's updater looks up `releases/latest`, skips drafts and prereleases,
  expects `KartPad-v0.7.15-android.apk` and `download/v0.7.15/SHA256SUMS`, and
  requires a higher versionCode and the same signer. The staged release meets each.
- Mac recipe: `bootstrap` matches `scripts/self-build-macos.sh`. A local run in
  this managed worktree fails before any download because `ref/upstream/WiiCompiled`
  is a development symlink to the newer vendored fork; 0.7.14's `doctor` fails
  identically here. The pin is unchanged since 0.7.14. A PadMint Mac build remains
  untested end to end.
- Still hands-off only: Apple sound, motion and compressed-ghost replay on a
  physical device. The release notes say so.

## Final acceptance before publication (9 October, 16:00–17:05 JST)

- Online: the release-signed APK signed in to Retro WFC twice (second after a
  cold relaunch), joined VS Worldwide rooms of 10–11 players, spectated a
  running race, then started and raced in a new one at about 60 FPS. Twice the
  room dropped mid-race with "You were disconnected from the other players";
  KartPad returned to the Retro menu cleanly and signed in again. No completed
  online results screen was captured. Recorded in KNOWN-ISSUES and README.
- Compressed Original ghost: a real compressed Luigi Circuit `.rkg` from the
  Chadsoft leaderboard (1:03.147) was imported through the release APK's
  Time Trial Ghosts flow. The next Original launch applied it with a save backup,
  cleared the pending request and stored an uncompressed, CRC-valid slot. It
  appears as ghost 2/2 in Time Trials and replays around the track.
- Mac: a clean PadMint build from the release branch first failed at
  `stage-maintained-translator.py` because app bootstrap never initialized the
  `vendor/wiicompiled` gitlink (pre-existing; the old `doctor` preflight hid it
  by failing earlier). Bootstrap now prepares that gitlink for app targets as it
  already did for packs, with a regression test. A second clean build passed
  every stage and the macOS package audit; the app ran the game at 60 FPS on
  Metal. The maintainer's Mac Application Support was backed up first; saves,
  NAND and configuration were byte-identical afterward.
- Repository: 349 Python tests passed locally; CI regression and receipts pass
  on the final branch head. Android and Apple app inputs are unchanged since the
  tested APK (daf662ec) and PadMint IPA (d97eadfc), so both binaries are final.
- Still hands-off only: Apple sound and motion on a physical device.
