# Current goal loop: next-release issue fixes (6 October 2026)

## Latest recheck: identity/Mii recovery

The expanded pass confirms the previous save/ghost tests and finds new
identity/Mii failures: partial linked renames and lost pending imports after
silent writes, plus console recovery proceeding after a failed backup.
[Evidence and correction](TRIAGE-2026-10-06.md#recheck-and-extension-android-identity-and-mii-writes)
are recorded. Save, identity and Mii paths now share the small checked writer;
failed Mii application uses the existing startup gate. Fourteen new fault cases
and two console checkpoints pass, including real Android API before/after
checks and preservation/retry checks. These changes do not resolve #234's
missing-data migration boundary.

Next device-free work: abrupt process termination at transaction completion,
launcher access to failed-import recovery, and a fresh exact Mac two-player
race. Keep the physical/release acceptance gates below separate.

## Latest result: Android save/ghost failure handling

The next device-free pass found and corrected unchecked Android atomic writes.
Silent staging failures no longer report success; failed backups or save
replacement stop the import and retain the request. Fourteen controlled failure
cases pass, and real Android framework probes reproduce the before/after
staging behavior for both save and ghost imports. See the
[fix and validation receipt](TRIAGE-2026-10-06.md#follow-up-fix-checked-android-save-and-ghost-writes).
This is pending in draft #416, not released or confirmation of #234.

The separate identity/Mii writer audit is now covered by the recheck above;
its remaining boundaries and next work supersede this earlier action.

## Current constraint: device-free investigation

Chris requested the next pass without a physical device. The
[device-free follow-up](TRIAGE-2026-10-06.md#device-free-follow-up-6-october)
adds a failing-before/passing-after **actual iOS Simulator background test**
for Sound, cold-launch and Done persistence, phone/tablet UIKit layout checks,
and **64 ghosts / 32 courses / four licenses** of native and independent
format/save-preservation checks. The retained Mac build now reaches a real
two-player race with both characters in their karts at 1x and selected 4x/120;
it is not an exact-candidate, sustained-race or affected-M5 acceptance result.
No new runtime patch, merge or release came from this pass.

Controlled pending ghost/save failure checks have now produced the fix above.
Continue without hardware with the next work listed there. Keep physical
sound/gesture/GPU acceptance and genuine signed Android fresh/update acceptance
explicit; simulator results do not substitute for those gates.

## Resumed by Chris: 6 October, 16:46 JST

[Evidence, validation and remaining gates](TRIAGE-2026-10-06.md).

Chris explicitly resumed the paused investigation. The pending comparison-ghost
import has now applied through the normal Play launch, created a backup, and
passed save/input readback checks and a complete imported replay. The resumed
evidence and next acceptance steps are recorded in the triage receipt; no
release was published.

Chris renewed this loop: fix as many recent issues as the evidence supports,
keep the Controls hierarchy consistent across KartPad platforms, reply in his
voice, and triple-check changes. This section supersedes the older next actions
below. Current public release is 0.7.14; release scope is selected by acceptance,
not by an arbitrary issue count. No new release is authorized by a green build
alone.

One issue at a time: read the supplied evidence -> identify a discriminating
local reproduction -> make the smallest correction -> review the diff, run
behavior/regression tests, and check the relevant built app -> commit/PR ->
report the proven result. A candidate that cannot reproduce or improve the
failure stays out of the release. Keep working on another ready item while a
specific hardware gate remains unavailable. Do not repeat unchanged tests or
request another reporter capture without a new question it can answer.

| Work | Evidence / next gate |
|---|---|
| #304 PowerVR | New 0.7.14/build 258 ZIP reviewed. Self-check: 149544 covered pixels in all three copies; alternate layout differs in all those pixels, constant-index copy matches original. This is a comparison, not a known-good image. Review recorded draw state and shader layout before any default workaround. Reporter acknowledged; no new capture requested. |
| #104 / #301 Adreno | Retain existing 0.7.12/13 reports. Empty comparisons cannot rule out a vertex-path problem or prove a bone-lookup root cause. G85 has one mismatch with only the original drawing pixels. Do not automatically enable a workaround from `mismatch` alone. Need a candidate checked against a representative failing draw and affected hardware. |
| #430 Shake to Trick | Candidate exposes Apple's existing implementation and adds Android support. It provides the same Controls -> Shake to Trick entry on both mobile hosts, default off and independent of tilt steering. Fix Apple flat-device early return. Verify gesture hysteresis/cooldown, sensor lifecycle, controller priority, release/cancellation, persistence and menu navigation. Mac/tvOS have no handset sensor; do not add a misleading active control. |
| #390 startup flicker | Reporter confirms every launch on iPhone 16 and iPad Air 4, starting with 0.5.x; gameplay otherwise fine. Existing diagnostic and video sufficient for investigation. Physical iPhone 14 is a possible 60 Hz reproduction target, not yet proof. Compare startup presentation and fade paths before shader/timing changes. |
| #420 / #411 sound | Updated #420 with a reproduced background-persistence correction and failing-then-passing regression; iOS build/audit pass. Physical sheet navigation, audible levels and restart persistence remain unverified. Keep its status explicit. |
| #378 controller routing | Actual ipega fails on 0.7.7; 0.7.8 candidate has only virtual-controller proof. Do not resend an unchanged request or call it fixed. |
| #370 / #380 / #131 | Existing released fixes/workarounds or emulator passes await affected-device confirmation; no new evidence justifies more patches yet. |
| #416 / #339 upstream/performance | Draft #416 now includes main through 0.7.14 (`104feef7`); version conflict resolved, tests/build and unchanged candidate pack fingerprints verified. No proven speed gain. Correctness-preserving CPU-context change must beat same-scene physical-device noise and pass equivalence tests. Reply to rounding concern posted. |
| #375 / #295 ghosts | Draft has unresolved Retro replay/rendering and physical-iPhone gates. Its independently reproduced Original compressed-import correction is now isolated in draft #436, with a failing-then-passing native/sanitizer regression and mobile builds. Matching rebuilt packs and an exact combined Android imported replay now pass. Physical/iOS replay and broader Retro acceptance remain separate. |
| #431 HONOR | Main report for identical #432-434, which were assigned then closed as duplicates. Device/build/settings known; screenshot and reviewed standard diagnostic requested once. No GPU root cause inferred. |

The reviewed candidates are now combined in draft #416: upstream 0.8.0, #420 sound, #435 shake, and #436 Original compressed imports. The combined suite passes (346 tests, 1 skip, 214 subtests); full Android and iOS apps build. See the triage record for exact pack identities and remaining device acceptance. This is not permission to merge/release before acceptance. Preserve #375 as a separate unfinished Retro feature.

The additional one-hour pass is recorded in [the triage receipt](TRIAGE-2026-10-06.md#additional-investigation-and-pause-6-october-13451455-jst). The exact Android candidate now has retail license/menu and sustained built-in staff-replay movement evidence. The resumed pass also verifies the imported comparison ghost through the exact expected finish frame. Physical hardware and final signed fresh/update gates remain open. The later device-free pass advances the retained Mac build into split-screen rendering; see the current constraint above for its limits.

Every change gets three complementary checks: code/lifecycle review, executable
regressions, and app/platform validation. Record limitations rather than calling
three repetitions of one test acceptance. Do not close a bug as fixed without
an affected user's confirmation or equivalent direct affected-device evidence.

## Earlier loop and evidence (retained history)

Written 5 October 2026, after 0.7.10. It replaces the next actions in the
[1 October loop](FOCUSED-LOOP-2026-10-01.md); the
[original August loop](GOAL-LOOP.md) stays as history.

## Goal

Make KartPad fail less often for new players and run better for everyone,
without growing it: setup that doesn't need help on Discord, logging that pins
the remaining Android graphics bugs from players' own reports, measured speed
work with the WiiCompiled update, and fixes sent upstream when they're real.

## Ground rules

- **Devices:** the Android emulator on this Mac, the iPad Pro, the iPhone 14,
  this Mac, and Chris's Pixel 9 Pro XL when he connects it. No test phones get
  bought. An emulator FPS number is not a performance result.
- **Players:** don't ask anyone to run settings experiments. At most one
  request per issue per release, and only for the standard **Report a
  Problem** log. Close an issue only when someone affected confirms.
- **Scope:** no new features beyond what's listed here. Don't touch PadMint
  (Chris is redesigning it), but keep `padmint.json` and
  `-ios-for-padmint.ipa` working. Never publish game data, keys, saves or
  signing material.
- **Releases** use the [ready-to-play recipe](RELEASE-CHECKLIST.md#ready-to-play-release-from-079).
  Docs change in the same PR as the behavior they describe.
- **Replies** are first person, signed "Best, Chris", in the reporter's
  language.

## Track A: setup that works without help (0.7.11)

The Discord thread of 4 October and #370 show the same failures: players tap
the disc-image import first and hit a key prompt, don't know which Dolphin
folder to pick, and lose files moving 2,000 of them through Google Drive.

- **A1. Game data screens (Android and iPhone/iPad).** Put **Import from
  Extracted Folder…** first and mark it recommended. Label the disc-image
  option as needing your Wii's key, and make **Use Extracted Folder** the main
  button of the key prompt. Replace "RMCP01 DATA folder", "private storage"
  and the RVZ sentence with plain words. Say that the folder Dolphin made
  (with `DATA`, `UPDATE`, `CHANNEL`) works. Same order in **Getting
  Started**. Check the Mac's first-run text.
- **A2. Import a zip on Android.** Accept one `.zip` holding the game data
  (`files`/`sys` at the top, inside `DATA/`, or inside Dolphin's folder).
  Stream it, refuse unsafe paths and oversized archives, then run the same
  validation and completeness check as a folder. A cut-off zip must fail with a
  clear message. iPhone/iPad already unzip in Files, so they get wording only.
- **A3.** Fix `scripts/build-game-pack.sh`, which no longer passes the pack
  fingerprint the pack project requires (found while building 0.7.10's iOS
  test pack). Check whether PadMint uses this script before calling it a player
  bug.

**Done when:** on a fresh emulator, importing Dolphin's parent folder and a zip
both reach a race; a truncated zip and a zip missing a file give clear errors;
the disc-image path still works with a key; screenshots of the new Android and
iPad screens; unit tests cover zip path safety; 0.7.11 is released.
**Stop:** no other formats or cloud integrations.

## Track B: logging that pins Android graphics bugs (no phones)

Adreno 8xx is fixed. Open: Adreno 6xx/7xx (#104, #301) and PowerVR (#304).
The September synthetic probes passed on affected phones, so they don't tell
good drivers from bad ones, and the PowerVR shader-limit theory was ruled out
on 4 October.

- **B1. A draw self-check, logging only.** Once per session, on real game
  draws (vehicle select or the race start), render a small sample of character
  draws two ways: the normal shader vertex fetch, and the CPU repack path. Read
  both back and log per vertex-format class whether they match. Put the result
  at the top of **Report a Problem**. It must not change what's drawn, must cost
  only a few milliseconds once, and must catch a GPU error and log it instead of
  crashing (on PowerVR the full repack showed no frame at all).
- **Proof before shipping:** on the emulator both paths match (no false
  alarms), and a deliberately broken debug path is flagged (it really detects
  mismatches).
- **B2. Act only on evidence.** When an affected phone's report shows
  mismatches on a specific format, let **Automatic** pick the fix from the
  self-check result on that phone. If the report shows no mismatch, vertex
  fetch isn't the cause: record that, add one more bounded check for the next
  candidate (uniform indexing or depth precision), and stop there.

**Done when:** B1 ships (in 0.7.11 if its proof passes, otherwise the next
app release), and each of #104, #301 and #304 either has a report analyzed or
one posted request. **Stop:** two passes with no new evidence, then park with
the written state. No settings experiments for players.

**B1 status (5 October):** released in 0.7.12 (runtime `747c224`), same pack
interface as 0.7.11. Once per session, 20 s after the first character draw,
one skinned draw of 64 or more vertices is kept whole and drawn twice off
screen (the layout the game used and the other one), then compared. The log
line is `KartPad draw self-check: ... result=match|mismatch|inconclusive`,
with one retry line per attempt (up to 10) giving the reason, and the last
result is printed near the top of **Report a Problem** exports. Emulator proof:
a normal run gives `match`, a forced break
(`adb shell setprop debug.kartpad.selfcheck_break 1`) gives `mismatch`, and
with the CPU repack forced on it gives `match` the other way round. It checks
only the vertex path; a `match` on an affected phone means the cause is
elsewhere (B2). Nothing is drawn on screen differently.
Self-check logs were requested on #104, #301 and #304 on 5 October; B2 starts
when one arrives. Not yet run on a physical Android phone (the Pixel 9 Pro XL
has 0.7.12 installed in place but was locked).

**B2, first report (5 October, #104, Galaxy S24 Ultra, Adreno 750):** all 7
attempts on the same 81-vertex body draw gave `drawn_game=0 drawn_other=0`:
neither vertex layout draws it, while the same draw covers 36 to 689 pixels on
the emulator. So vertex fetch is not the cause on the 750. That matches the
reporter's 0.7.3 tests, where the CPU repack alone left only the eyes and only
the constant (switch) bone-matrix lookup drew bodies. The next bounded check
(0.7.13, runtime `6fb1989`) adds a third copy with the game's layout and the
constant lookup, and reports `result=indexing` when it differs from the
game's draw. Emulator proof: normal runs give `match` with
`constant_differing=0`; `debug.kartpad.selfcheck_break 2` (both layout copies
left empty, as on the S24) gives `indexing`. If the S24 reports `indexing`,
Automatic uses the constant lookup for skinned draws on that GPU; the white
bodies (missing textures) seen with that lookup in 0.7.3 are the step after.
If it reports `match` or nothing draws in any copy, record it and stop.

**B2, three reports in (5 October):** the same pattern on three GPUs, all from
0.7.12 logs. Galaxy S24 Ultra (Adreno 750, #104) and Moto G85 (Adreno 619,
#301): skinned draws of 81 to 120 vertices come out empty with both vertex
layouts on every attempt. Moto G54 (PowerVR BXM-8-256, #304): an 81-vertex
piece covers 26,151 pixels with both layouts (36 to 689 on the emulator), so it
"explodes" either way and only the colors differ (`result=mismatch`). The
vertex layout isn't the cause on any of them; the bone-matrix lookup is the
common suspect. 0.7.13's `drawn_constant` copy was requested on all three.

**B2, 0.7.13 answers (5 October), B parked for Adreno:** the S24 (#104, 8
attempts) and the G85 (#301, 9 attempts) both report `drawn_constant=0`: the
constant lookup with the game's own vertex layout draws nothing either. On one
G85 attempt the game's copy drew 2,472 px and both other copies drew nothing.
So on Adreno 6xx/7xx neither change works alone, which matches the S24's 0.7.3
test: only the CPU repack and the constant lookup together drew bodies, and
then white and at about 24 FPS (the "fix invisible characters" option). Two
reads fail on these drivers, both reading per-vertex-indexed data, and the
self-check can't narrow it further without a new rendering path. Per the stop
rule this is recorded and B is parked for Adreno; no more test requests to
these reporters. The one remaining candidate is reading the bone matrices from
a storage buffer instead of the uniform buffer, which would replace both
workarounds at once (and possibly the white textures); it's a renderer change
for Chris to decide on, not a logging step. PowerVR (#304) still waits for its
0.7.13 log.

## Track C: 0.8.0, the WiiCompiled update and measured speed (#339)

patchzyy asked for a focused performance and compile-time pass. KartPad's
runtime is 20 or more upstream commits behind, and upstream has since merged
macOS support, PSQ fallback fixes and a shader wait screen.

- **C1. Sync** the translator and runtime forks to current upstream main,
  building on draft #384. This changes the pack interface, so it ships as
  **0.8.0**; the ready-to-play downloads carry the new code, and PadMint users
  rebuild once. Tell Chris before release so PadMint's notes match.
- **C2. Baselines first, on the same machine every time:**
  - Compile: clean and incremental translation, shard generation, Clang and
    link times for the Android pack on this Mac.
  - Runtime: CPU frame time on a fixed scene driven by the RKG replay fixture
    (repeatable since the #131 harness): the Mac build, plus the Pixel when
    it's connected.
- **C3. One candidate at a time,** chosen by the profile. Today's top costs:
  PowerPC float-rounding emulation, indirect-call dispatch, CPU-context lookup.
  First candidate: the translator passes the CPU context to float helpers.
  Keep a change only if the same-scene measurement beats the noise; reject
  regressions.
- **C4. First-time pauses:** measure menu and pre-race stalls in the replay
  scene, and compare upstream's shader wait screen with KartPad's pipeline
  cache.

**Done when:** 0.8.0 reaches a race on the emulator as an update over 0.7.x
with saves kept, on the iPad and on the Mac, with Retro Rewind booting; and
measured before/after numbers are posted on #339. #339's targets (10% lower
CPU frame time on weaker hardware, 40% shorter compilation) are goals, not
promises.

**C status (5 October, draft #416):**

- **Packs rebuilt** for the final pins. Android pack fingerprint `56339f84`
  (276 s on a fresh work folder including disc extraction; translation 34 s).
  iOS pack 194 s.
- **Android:** the ready-to-play 0.8.0 APK installs over 0.7.9 on the
  emulator with the save unchanged (`rksys.dat` md5 identical before and
  after), passes the full game-file check, reaches a Grand Prix race, and the
  self-check reports a match. Retro Rewind downloads (about 96 s) and its first
  Play reaches the Retro Rewind title.
- **Mac:** the 0.8.0 dual app builds (16.5 min including translation) and races
  Luigi Circuit at 60 FPS (median 16.7 ms, 95th percentile 17.5 ms), run with
  a temporary HOME so Chris's own Mac data wasn't touched.
- **iPhone/iPad:** the first 0.8.0 build failed: upstream's macOS Core Audio
  media monitor (`external_audio_macos.cpp`) was compiled for iOS. The iOS
  runtime fork now keeps it macOS-only (`266173a`); iOS takes the existing
  "unavailable" path, like Android. The iPad Pro has 0.8.0 installed in place
  (saves backed up first) and shows both games ready. Racing on the iPad needs a
  tap from Chris.
- **Numbers on #339 (5 October):** compile 175 s → 181 s total, compile CPU
  1,032 s → 1,023 s; same-scene emulator frame time (Luigi Circuit, 12 racers,
  two alternating runs each) is the same within noise, and process CPU is the
  same within 1%. The emulator's run-to-run swing (about 15%) is too large to
  judge a speed candidate.
- **C3, first candidate dropped before building:** the float helpers
  (`Ppc*StateInline`, 57,958 call sites) read the CPU context from a
  thread-local, so passing `ctx` looked like it would save a TLS lookup per
  operation. The compiled 0.8.0 Android pack says otherwise: the access is
  initial-exec style, read once per function in the prologue (`mrs
  TPIDR_EL0`, 7,633 reads across about 38,000 functions, no descriptor
  calls). Passing `ctx` would save a few cycles per function, not per
  operation. The cost in the profile is the float-status emulation itself
  (FPSCR read, rounding, exception bits and write-back on every operation).
  The next candidate needs a fresh profile on the Pixel 9 Pro XL to choose.

## Track D: upstream fixes, only when substantive

A change goes to WiiCompiled only if all of these hold:

1. It is reproduced on **upstream's own main** (not just our fork) and it's not
   already merged or in an open PR there (#244, #251 and #252 already carry
   earlier KartPad work).
2. It's platform-neutral: KartPad-only workarounds stay in KartPad.
3. It's one behavior per PR, in upstream's style, with a regression test.
   Game-behavior changes include evidence that they match the real Wii.
4. **Chris writes the PR description and replies.** WiiCompiled's
   CONTRIBUTING says PR text must not be generated. The loop prepares the
   branch (from upstream main, on the `chrissotraidis/wiicompiled` fork),
   tests and a plain evidence note, and never posts upstream itself.

Candidates found on 5 October, to verify in that order:

- **D1. Controller with no player.** Upstream's `apply_port_preferences` has
  the same structure KartPad fixed for #378 (`094b567`): a saved Player 1
  for a missing controller leaves a connected pad with no port.
- **D2. Fatal errors on macOS and Linux.** Upstream's non-Windows
  `ShowRuntimeFatalPopup` only logs, and upstream now ships macOS, so a
  fatal error there closes the game silently.
- **D3.** Any Track C speed change that lives in the translator or shared
  runtime.

Not candidates: the Adreno repack, the iOS fatal hook and other KartPad
platform code. The game-data completeness check counts only if upstream also
imports extracted folders the way KartPad does.

**Stop:** a candidate that doesn't reproduce upstream is dropped, with the
reason recorded in [UPSTREAM_UPDATES.md](UPSTREAM_UPDATES.md).

## Track F: music and game-sound levels (#411)

Chris asked for this on 5 October. In the ••• menu (Android and iPhone/iPad)
and the Mac menu bar, a **Sound** item with one toggle, off by default. Off
means everything plays at full volume, as today. On shows two levels, Music
and Game sounds (effects, voices and menus), so a player can mute just the
music, mute the whole game, or keep only the game sounds.

- The runtime already has this: per-category live levels from upstream
  (`MusicAttenuation::Set*Volume`, applied to the game's own sound players, so
  a change takes effect mid-race) and `[audio]` keys in `Config.toml` that it
  applies at every start. KartPad only adds the menus.
- No pack-interface change: Android declares the four setters in its JNI file
  and saves the levels from Kotlin; the Apple shells call the same functions.
  So it can ship in a 0.7.x release.
- **F1 Android**, **F2 iPhone/iPad**, **F3 Mac**, one pass each, each checked
  on its device (levels change live, survive a restart, toggle off restores
  full volume). A second pass after players try it.

**F status (5 October):** F1 Android merged (#419): ••• → **Sound…**, a toggle (off)
and Music / Game sounds sliders. On the emulator the sliders call the runtime
live (`[KartPadSound] music=0.00 sounds=0.48` in the session log) and closing
the dialog saved `[audio]` in Config.toml; same pack interface (85d2a9c9).
The emulator has no audio output, so hearing it is the remaining check (Pixel
or iPad). The levels go through the shared game audio code
(`hle/audio` → `MusicAttenuation`, re-applied every audio tick), the same
path the Mac's Audio settings use, and `InitializeRuntimeSettings` applies the
saved `[audio]` keys at every start on all platforms. F2 iPhone/iPad is in
#420 (a Sound sheet from the ••• menu): it builds and is installed on the iPad,
and waits for one tap-through there. A remote check isn't possible: the iPhone/iPad
runtime rejects launch arguments ("does not accept command-line options"), so the
game can't be started on the iPad without a tap. For the second pass: SDL's default iOS
audio session ducks other apps' music while KartPad plays, so Spotify keeps
playing but quieter. F3 Mac: already there as **Game → Game Settings… →
Audio** (master, music, effects, menu sounds, voices, mute; applies live).

## Track G: the full game-file check at import (5 October)

A player's iPad showed "Ready to play", then "The game stopped because the
game data is incomplete: 1 of 2032 game files are missing or cut short, for
example /thp/title/title_SD_50.thp". The game checks every file in the disc's
own table at start (#370), but the importers on Android, iPhone/iPad and the
Mac only checked six key files and two hashes. The movie isn't at the end of
the disc (it sits at 3.8 GB with smaller files after it), so a truncated disc
image doesn't explain it; a folder copy where one large file never arrived
does, most often an iCloud Drive folder that isn't fully downloaded.

- **G1 (done, `codex/game-data-full-check`):** the importers and the game
  chooser run the same rule as the game (every `sys/fst.bin` file present at
  its full size), so an incomplete copy is refused at import, or shown as
  "Setup needed" with the file's name, instead of failing after Play. The
  message says to download the whole folder (Files/Finder **Download Now**)
  and import again. One shared header for iPhone/iPad and Mac
  (`apple/shared/KartPadGameFiles.h`), one Kotlin function on Android.
- **Checked:** Mac harness on a real extraction (complete: passes in under
  half a second; `title_SD_50.thp` emptied: "1 of 2032 … title_SD_50.thp";
  a second file removed: "2 of 2032"). Android emulator: complete data still
  "Ready to play"; with `title_SD_50.thp` emptied the chooser says "Setup
  needed" with the message, and Game Data & Saves shows it too. iPad Pro: the
  new build installed in place, real data still "Ready to play". Mac: the
  shell file compiles with the release build's flags.
- Ships in 0.7.14 with the sound levels (Track F). **Stop:** no automatic
  iCloud downloading or per-file repair.

## Track E: support, every pass

Check issues updated since the last pass. Reply to anyone waiting, link
duplicates so every reporter keeps getting updates, and close on confirmation.
Update [KNOWN-ISSUES.md](KNOWN-ISSUES.md) and [STATUS.md](STATUS.md) when an
issue's state changes. When the Pixel is connected, install the current
release on it in place, keeping its data.

## Order and finish line

1. A1 to A3 and B1's emulator proof, then **0.7.11**.
2. D1 and D2 verification in parallel (small), handing branches and notes to
   Chris.
3. C1 to C4, then **0.8.0**; D3 if a speed change qualifies.
4. B2: parked for Adreno (see above); PowerVR when its 0.7.13 log arrives.
5. F1 to F3 (sound levels) in a 0.7.x release, then a second pass on feedback.
6. G1 (full game-file check) ships with F in 0.7.14.

The loop is finished when 0.7.11 and 0.8.0 are released with these gates met,
B is either acting on evidence or parked with its written state, every D
candidate is submitted by Chris or dropped with a reason, and the docs match
the released app.
