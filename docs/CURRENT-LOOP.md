# Current goal loop: 0.7.11 and 0.8.0

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
4. B2 as reports arrive.

The loop is finished when 0.7.11 and 0.8.0 are released with these gates met,
B is either acting on evidence or parked with its written state, every D
candidate is submitted by Chris or dropped with a reason, and the docs match
the released app.
