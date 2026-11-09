# KartPad release checklist

Use this checklist for each candidate. Published versions and active work live
in [STATUS.md](STATUS.md) and the [maintenance board](MAINTENANCE-BOARD.md).
Completed [release checkpoints through 0.4.11](archive/release-checkpoints-through-0.4.11.md)
are historical evidence, not a checklist for the next build.

## Android APK and PadMint inputs (from 0.7.14)

[AGENTS.md](../AGENTS.md) lists the current six-file delivery set. Android
retains its ready-to-play APK; Apple builds use PadMint. The 0.7.9–0.7.13
ready-to-play Apple downloads are historical, not requirements for new releases.

For each release:

1. Merge the release PR, then confirm `git rev-parse <merge>^{tree}` equals the
   tree you build from. Bump `version.json` (version and build) in the PR.
2. **Android:** `KARTPAD_ANDROID_PACKAGE_FORMAT=aab
   KARTPAD_ANDROID_BUNDLED_GAME_PACK=<pack> scripts/build-android-app.sh
   <absolute output dir>`. Use an absolute output path; a relative one breaks
   the build-provenance step. The pack must match the printed pack fingerprint.
   Then `KARTPAD_ANDROID_ALLOW_GAME_PACK=1 scripts/derive-android-release-apk.sh`
   with the Community Release key, **twice**; both APKs must be byte-identical.
3. **iPhone/iPad:** `scripts/build-ios-app.sh <dir>` gives the game-code-free
   IPA, published as `-ios-for-padmint.ipa`. Audit it without a game pack or
   provisioning profile. For private acceptance, check the personal pack against
   that exact app with `scripts/check-game-pack-state.py`, add it to a private
   copy, and install in place after backing up and reading back player data.
4. **Mac:** complete the [Mac player flow](#mac-player-flow) when affected. There is
   no ready-to-play Mac download from 0.7.14. A recipe path edit alone does not
   prove that a fresh PadMint Mac build or its gameplay works.
5. **Other files:** `padmint.json` as `-padmint.json`; a notices zip with
   `LICENSE`, `LICENSES/`, `RIGHTS_AND_LICENSES.md` and
   `THIRD_PARTY_NOTICES.md`; `scripts/package-release-source.py` with the
   KartPad merge commit and every runtime and translator gitlink;
   `SHA256SUMS` over all of them.
6. **Audits:** `python3 -m padmint audit` (from the PadMint checkout) on every
   file, and the release gate on the folder. The only accepted findings are
   translated game code (address-named symbols and the embedded data-sections
   marker) in the APK, plus the same marker string inside the translator's source file.
   Inspect any source-definition hits against exact tracked source; record
   synthetic test fixtures as reviewed findings, never a blanket audit PASS.
   Any key, disc data or private path is a stop.
7. **Tests:** run every [behaviour check](#behaviour-checks-every-release)
   below on the final build. Test the final PadMint app
   with its matching private pack on an Apple device, installed in place. Check
   affected Mac behavior separately; do not imply Android/iPad proof covers Mac.
8. Publish with `gh release create --target <full merge SHA>` (a short SHA is
   rejected), then download every file anonymously and check it against
   `SHA256SUMS`, and confirm GitHub reports the new tag as latest.

## Behaviour checks (every release)

The steps above prove the files are built, signed and packaged correctly. They
don't prove the game works. Every check below has caught, or would have caught,
a bug that reached players. Run all of them on the final build from the merge
commit, record the result in the release notes, and treat a failure like a
failed player check: it blocks the release. If a check can't be run, say so in
the release notes under **Not checked** and add it to the
[maintenance board](MAINTENANCE-BOARD.md).

Android checks use an arm64 emulator at 2400x1080 landscape with game data
imported. iPhone/iPad checks use the iOS Simulator with a full translated build
(see [BUILDING.md](BUILDING.md)); in the Simulator, `axe key` drives the game
as Wii Remote 1 (arrows = D-pad, Return = A, Backspace = B), with each key held
about 0.3 s (`--duration 0.3`). Lines marked *console log* come from
**⋯ → Report a Problem… → Save Diagnostic Log…**; on Android, save it to
Downloads and `adb pull` it. Lines marked *logcat* come from `adb logcat`.

| # | Check | How | Pass |
| --- | --- | --- | --- |
| 1 | Full test suite | `python3 -B -m pytest -q tests` on the release branch, with the JDK in `.android-bootstrap`. CI runs only part of the suite. | No failures. |
| 2 | Fresh install | New emulator: install the APK, import an extracted folder, start Original, reach a race. | Race starts at 60 FPS. |
| 3 | Update | New emulator: install the **previous published** APK, import, race once; install the new APK over it without uninstalling. | Game card still says Ready to play, no first-run setup, race starts. |
| 4 | Every new or changed feature | Use the feature for what it's for, not just its menu or its fallback. | The main path works, or the release notes say exactly why it couldn't be tested. |
| 5 | Custom GPU driver loads | Android: **GPU Driver → Add Driver… → Download a Driver…**, install a Turnip release, start the game. | *logcat* `KartPadGpuDriver state=loaded` on the first start. The emulator has no Adreno GPU, so graphics then fail and the next start falls back with a "didn't load" message, which is expected. |
| 6 | Memory across courses | `scripts/android-course-memory-loop.sh <dir> 8`, the same way on the previous release and the candidate. | Native heap grows no more between round 1 and round 8 than on the previous release, and less than about 40 MB; live textures stay flat. |
| 7 | Start-up frames | Launch Original and Retro Rewind on the emulator and in the Simulator. | *console log* `[vi] present kinds` totals: the `black` count stops rising once `copies` (the game's own frames) starts rising. |
| 8 | 30 FPS Races | Turn it on; start an Original Grand Prix race on each Android engine and in the Simulator; open Retro Rewind's title screen and menus, then a race. | Races at 30 FPS at normal speed; Retro Rewind's menus at 60. *console log* `[KartPadFrameRate] scene … result=30_forced` only where `scene_kind=2`. |
| 9 | Retro Rewind | On the candidate: title screen → race on Android and in the Simulator. | Race starts. |
| 10 | Menus match | Open every ⋯ submenu on the Android emulator and in the Simulator. | Rows and order match [SETTINGS.md](SETTINGS.md) on both. An option added on one platform is either added on the other or listed there as platform-only. |
| 11 | Diagnostic log | Save a diagnostic log on Android and in the Simulator. | The log opens; on Android its header has `gpu_driver`, `thirty_fps_races` and `simpler_computer_karts`, and its health lines have the last two. |
| 12 | Player checks | From PadMint's current `main`: `scripts/player-check.sh kartpad ios <disc> <checkout> <ios-for-padmint.ipa>`, `… macos <disc> <checkout>` and `… android <disc> <checkout> <android.apk>` before tagging, and each without the checkout after publishing. Android and iPhone need the release app as the last argument. | All three pass. |

## How bugs got past earlier releases

These are the reasons behind the checks above. Add one here whenever a bug
reaches players that a release check could have caught.

- **Custom GPU drivers never loaded (0.8.6–0.8.8).** The feature was released
  with only its fallback tested ("an emulator can't run a Snapdragon driver").
  The fallback was all it ever did: `--wrap=dlopen` stopped every driver at the
  first step, and the menu kept naming the chosen driver. An emulator does show
  whether a driver loads, before its graphics fail. Checks 4 and 5.
- **Memory grew with every course (#510).** Every release was tested with one
  race at a time, and long sessions were left to the PRD matrix. Players saw
  slow motion after two or three cups. Check 6.
- **Flicker at start-up on iPhone/iPad (#390).** Nothing counted the frames sent
  to the screen, so it could only be seen on a real 60 Hz device. KartPad now
  logs them. Check 7.
- **30 FPS Races also slowed Retro Rewind's menus (0.8.8).** The option was
  checked in races only. Check 8.
- **Menus drifted apart.** Options were added on Android without a rule for
  iPhone/iPad, so the platforms differed until 0.8.9. Check 10.
- **A test broke unnoticed (0.8.9 candidate).** A new report field broke a test
  that CI doesn't run; a local full run caught it before merge. Check 1.
- **Wrong player-check call (0.8.9 candidate).** The Android check stops with
  "published app does not exist" without the APK. Check 12 gives the exact calls.

## Source and scope

- [ ] Record platform, version/build, exact source commit and intended test or
      release purpose. Identify affected platforms and unresolved reports.
- [ ] Review the diff and run checks appropriate to the changed code, including
      regressions for any reproduced defect. Prepare runtime patches afresh.
- [ ] Verify pinned dependencies, Retro Rewind profile and repository safety.
      Preserve existing working trees, user data and signing identities.
- [ ] Review [rights, Corresponding Source and game-content boundaries](../RIGHTS_AND_LICENSES.md)
      and [third-party notices](../THIRD_PARTY_NOTICES.md) for the exact package.

## Build and package

- [ ] Build from the intended clean source and record the artifact identity.
      A source fix does not update an old binary.
- [ ] Run the platform app/package audit, including architecture, minimum OS,
      signatures, resources, notices and provenance. Exclude private data and
      signing material.
- [ ] Package twice and compare bytes where the platform's release workflow
      requires reproducibility; verify the final SHA-256 and version metadata.
- [ ] Confirm the update path preserves data with the existing signer and bundle
      identifier. Do not uninstall a working preview to test a different signer.

Platform procedures: [Android release](RELEASING_ANDROID.md),
[Apple build](BUILDING.md), [Personal IPA Builder](BUILDER.md),
[Mac install](INSTALL_MACOS.md) and [tvOS build/test](TVOS.md).

### Mac player flow

- [ ] Record the exact PadMint ZIP, KartPad revision/recipe, host and process
      architecture. Run `scripts/player-check.sh` from PadMint's current `main`
      with the clean KartPad checkout before tagging, then without a checkout
      after publishing and before announcing. Its fresh build does not replace
      the packaged page checks below.
- [ ] Extract the candidate PadMint Mac ZIP and use its real launcher and page.
      Check native Apple Silicon and an actual Rosetta parent restarting
      natively. On real Intel, verify the Mac target explains the Apple Silicon
      requirement and supported mobile choices remain available.
- [ ] Complete **Make my copy** with an isolated empty PadMint folder, then
      repeat with the same folder, unchanged checkout and inputs. Verify valid
      caches are reused, a new output is created, and the previous app/ZIP and
      player data remain unchanged. Do not clear a player's cache for this test.
- [ ] Open the final app using Finder/`ditto` extraction and follow the documented
      missing-data → native import → offline race entry → clean quit/relaunch
      flow for both Original and matching Retro Rewind. For the focused 0.8.2
      fixes, reach gameplay past the former fault, verify input, and quit/reopen
      with game selection, licenses, saves and settings retained. Full race
      completion is not required for this release's accepted scope. Record audio
      and performance separately; CI/build success alone does not prove gameplay.
- [ ] In **Controls → Controller Settings…**, select **Keyboard**. Remap and
      clear bindings, then use **Reset Keyboard Defaults**. Verify actual menu
      and race actions and keyboard autosave across quit/relaunch without
      **Save Profile**, then explicit **Save Profile**. Preserve saves and
      unrelated settings. Record which reset states were observed or reloaded.
      Left/right Shift, Control and Option capture has synthetic AppKit and
      production-input coverage; physical capture remains unverified and is
      recorded as a coverage limit, not an additional 0.8.2 release gate.

## Acceptance and publication

- [ ] Record build, package, emulator, physical-device and production-online
      results separately. State precisely which remain pending.
- [ ] Use the [iPhone/iPad](PHYSICAL-ACCEPTANCE.md),
      [Android](ANDROID-PHYSICAL-HANDOFF.md) or [tvOS](TVOS-TESTING.md) device
      procedure as applicable. Verify existing saves after an in-place update.
- [ ] Write versioned release notes with changes, installation, test scope and
      known limits. Use a prerelease for an unaccepted testing candidate.
- [ ] Publish only within the owner's explicit release authorization. The
      scheduled coordinator and its workers **must never publish an IPA**;
      [manual Apple ownership is separate](MAINTENANCE.md#release-gates).
- [ ] Download hosted assets anonymously, compare hashes and bytes, and re-audit
      the downloaded package, signature and provenance.
- [ ] Update the README download table, installation guide, status and maintenance
      board together. Keep the README section order and AI disclosure intact;
      put detailed changes in release notes rather than adding release-history sections.

The short multi-course memory check (behaviour check 6) is required every release. Longer sustained performance, long soaks, full controller/multiplayer coverage and
production-online acceptance remain governed by the [PRD matrix](PRD.md).
A published preview does not close those rows.
