# 0.8.13 release loop

Started 28 November 2026. Owner decisions are marked **Chris**. Longer-term speed work is in the
[DriftDroid parity loop](DRIFTDROID-PARITY-LOOP.md).

## Objective

Make 0.8.13 a substantial release that fixes the problems players report most, with every change
checked three times before it ships. It has five parts:

1. **Settings that make sense on every platform.** One menu structure, the same names and order on
   Android, iPhone/iPad and Mac, and a single speed choice for mid-range phones.
2. **Android speed.** Ship the speed work that is already built, and add what can be measured in
   time.
3. **The Retro Rewind end-of-cup crash** (#131, also #128 and #493). Nobody can finish a Retro
   Rewind Grand Prix.
4. **The Snapdragon missing-characters fix inside the app** (#104, #301).
5. **Diagnostics for the open speed reports** (#554).

Keep going through the goals below until the release candidate passes the release gate, or a goal
needs a decision, hardware or a release that only Chris can give.

## What "checked three times" means

Every change passes all three checks. A failure at any check sends the change back to the first.

1. **Author check, in the PR.** The tests pass, and the change is used on its main path on the
   emulator, simulator or Mac build, with screenshots or log lines in the PR. A menu change is
   checked by opening every page it touches. A speed change carries before and after numbers.
   A settings change is checked on a fresh install and as an update over 0.8.12 with non-default
   choices saved.
2. **Second pass, after merging.** A fresh build of `main` on a **clean** emulator and simulator
   (new AVD and simulator device, game data imported from scratch, never the development device).
   Rerun the scripted checks for everything merged so far, and compare the R0 baselines: no menu,
   setting or speed number gets worse.
3. **Release gate, on the final build.** All twelve behaviour checks in the
   [release checklist](RELEASE-CHECKLIST.md#behaviour-checks-every-release), player checks for all
   three targets, and a read-through of every user-visible string against [SETTINGS.md](SETTINGS.md).
   Anything that can't be run goes under **Not checked** in the release notes.

## Boundaries

- **Never publish game code**, packs, disc files, saves or game-derived profiles. They stay in
  `build/perf/` and `private/`.
- **Saved settings survive.** Renames and regrouping change labels and layout only. Every existing
  preference key keeps its stored value, and a test proves it for each moved setting.
- **Same change on every runtime** for shared runtime code (Android, iPhone/iPad, Mac, tvOS and the
  translator copy). Write submodule pins with `git update-index --cacheinfo` or a clean checkout,
  never `git commit -a` with submodules at other commits.
- **Emulators:** `adb shell sync` before every `adb emu kill`.
- **Releases, issue replies and closing issues need Chris.** The candidate stays a draft until he
  publishes.

## Goals

Work on the lowest goal that isn't done. Record the result in the journal at the end.

**R0. Baselines.** Before anything changes, on released 0.8.12:
- Screenshots of every menu page and dialog on the Android emulator, the iPhone and iPad
  simulators and the Mac app.
- A settings matrix: every setting by platform, with its name, page, order, default, stored key
  and whether it exists there.
- Speed numbers on the emulator (game-thread CPU per frame at the main menu, Select Cup and Grand
  Prix race 1, on a free core and on a shared core).
- *Done when* all three are committed under `docs/artifacts/2026-11-28/` (screenshots without game
  content where possible, never game files).

**R1. Reproduce the Retro Rewind end-of-cup crash (#131).** Install Retro Rewind 6.13.5 on the
emulator, play a Grand Prix to the awards screen, and catch the failing archive load
(`ARCInitHandle: bad archive format` while `RecognizePadWindow` loads its layout). Find which
archive is opened and why it isn't valid. Check #537's "disc error" kick for the same cause.
- *Done when* it is fixed, with a cup completed in Retro Rewind and Original on Android and in the
  Simulator. If it doesn't reproduce after a day, record what was tried and ask Chris whether to
  ship without it.

**R2. The settings map (alignment with Chris).** From the R0 matrix, write the target structure into
SETTINGS.md as a draft: page names, row names, order, which rows are platform-only, and what moves
to an Advanced section. The proposal to start from:
- Top level, on every platform where it applies: **Controls**, **Speed & Graphics**, **Display**,
  **Sound**, **Game Data & Saves**, **Help & Report**, plus Multiplayer and Return to KartPad Menu.
- **Speed & Graphics** starts with a **Speed** choice, **Smoothest / Balanced / Best Quality**,
  which sets 30 FPS Races, Simpler Computer Karts and Render Resolution together. **Recommended for
  This Phone** suggests one. The individual switches follow, and an **Advanced** section holds
  Graphics Engine (both labelled as Vulkan on Android), GPU Driver, 120 FPS Races and Graphics
  Diagnostics.
- One name for each thing across platforms (controller setup, the diagnostic log, frame
  interpolation), and Test Native Crash only in diagnostic builds.
- *Done when* Chris agrees the map. No menu code changes before that.

**R3. Merge what is ready,** in the order from [CURRENT-LOOP](CURRENT-LOOP.md):
#594, #597, #598, #600, then #579, then #596 (rebased), then wiicompiled#39 and #599, then
wiicompiled#34–#38 and #595 if Chris includes it. Rerun the full test suite after each merge, and
run the second pass for each.
- *Done when* everything included is on `main` and the second pass is clean.

**R4. Speed & Graphics on Android.** Build the page from the map. The presets write the existing
settings, and the page shows **Custom** when the switches don't match a preset. The slow-race
offer (#599) turns on **Smoothest**, and Recommended for This Phone offers the right preset.
- *Done when* each preset is checked in a race (frame rate log lines, low-detail karts), switching
  engines and updating over 0.8.12 keep the choices, and the menu tests cover every row.

**R5. The rest of the Android menus,** renamed and moved per the map.
- *Done when* every page matches the map, with screenshots before and after, and saved settings
  carry over an update.

**R6. iPhone and iPad.** The same map, presets and names in the iOS menu.
- *Done when* every page matches the map in the iPhone and iPad simulators, the presets work in a
  race, and settings carry over an update.

**R7. Mac** (if Chris keeps it in scope). The Settings window follows the same groups and names,
and gains 30 FPS Races, Simpler Computer Karts and the Speed choice.
- *Done when* every tab matches the map in a local Mac build and a race runs with each preset.

**R8. The interrupt-flag fix** (parity loop P2, DriftDroid `ef99dbe`). Carry the guest
interrupt-enable state across thread switches on every runtime.
- *Done when* it is merged with emulator numbers showing it is faster or neutral beyond noise, and
  menus, races, online and audio still behave. Leave it out if it can't be shown safe in time.

**R9. Words and docs.** SETTINGS.md from the final map, KNOWN-ISSUES, a "speed on your phone" table
in the README, release notes with **Not checked**, and draft replies for every issue the release
touches.
- *Done when* every user-visible string has been read against the map.

**R10. Release candidate.** Bump `version.json`, build the Android APK, the iPhone/iPad app for
PadMint and the PadMint recipe, then run the release gate (check 3) on those exact files, and leave
the release as a draft.
- *Done when* every behaviour check passes or is listed under **Not checked**, and Chris has the
  draft to publish.

## Decisions for Chris

1. **The settings map** (R2), including the preset names.
2. **Mac in scope** for the menu work (R7), or later.
3. **Native menu-video decoding (#595).** It changes every runtime and the translator, so it adds a
   full iPhone/iPad and Mac check to the release.
4. **#131 deadline.** How long to hold the release for the crash if it doesn't reproduce quickly.

## Journal

Newest first: goal, what changed, which checks passed, PR, next step.

- **28 November.** Loop written. Nothing started. No new player reports since 26 November.

