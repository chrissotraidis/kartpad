# 0.8.13 release loop

Started 28 November 2026, revised the same day. Owner decisions are marked **Chris**. Longer-term
speed work is in the [DriftDroid parity loop](DRIFTDROID-PARITY-LOOP.md).

## Objective

Make 0.8.13 a substantial release that fixes the problems players report most, with every change
checked three times before it ships. Keep going through the goals until the release candidate
passes the release gate, or a goal needs a decision, hardware or a release that only Chris can give.

## 0.8.13 is done when

1. A Retro Rewind Grand Prix can be finished, through the trophy ceremony and the no-trophy ending,
   on Android and in the Simulator (#131, #128, #493). If the crash can't be fixed in time, Chris
   has decided to ship without it and the release notes say so.
2. Android, iPhone/iPad and Mac share one settings map: same page names, row names and order, with
   platform-only rows listed in SETTINGS.md. Mac is covered if Chris keeps it in scope.
3. A player on a slow phone can make races smooth with one choice (**Speed: Smoothest**), and KartPad
   offers it after a slow race.
4. Players on Qualcomm's 512.762 driver can install the confirmed Turnip build from inside the app.
5. No 0.8.12 setting is lost on update, and no menu, race or speed number is worse than 0.8.12
   beyond measurement noise.
6. Every change passed all three checks, and anything that couldn't be run is listed under
   **Not checked** in the release notes.

## Scope and cut lines

| Priority | Goals | If time runs short |
| --- | --- | --- |
| **Must** | R0 baselines, R1 #131, R2 settings map, R3 ready PRs, R4 Android Speed & Graphics, R5 rest of Android, R9 docs, R10 candidate | Not cut. #131 can be shipped without only by Chris's decision. |
| **Should** | R6 iPhone/iPad menus, #595 menu videos (in R3) | Cut only with Chris, because Android and iOS menus would then disagree until 0.8.14. |
| **Could** | R7 Mac menus, R8 interrupt-flag fix | Move to 0.8.14. |

**Estimate:** about 7–8 working days in total. R0 0.5, R1 up to 1, R2 0.5 plus review, R3 0.5,
R4 1, R5 0.5, R6 1, R7 1, R8 0.5–1, R9 0.5, R10 1.

**Order.** R0 and R1 start at once. R3 and R8 can run while R2 waits for Chris. R4–R7 start only
after Chris approves the map. R9 and R10 come last.

## Three checks for every change

A failure at any check sends the change back to the first.

1. **Author check, in the PR.** The tests pass, and the change is used on its main path, with
   screenshots or log lines in the PR. Menu changes open every page they touch, on a phone and a
   tablet screen size. Speed changes carry before and after numbers from `tools/android-perf`.
   Settings changes are checked on a fresh install and as an update over 0.8.12 with non-default
   choices saved.
2. **Second pass, after merging**, on a clean device (procedure below), comparing against the R0
   baselines. Run once per merged goal, and once more for everything together before R10.
3. **Release gate, on the final files.** All twelve
   [behaviour checks](RELEASE-CHECKLIST.md#behaviour-checks-every-release), PadMint player checks for
   all three targets, the Pixel 9 Pro XL if Chris connects it, and a read-through of every
   user-visible string against SETTINGS.md.

### Clean device procedure (second pass)

- **Android:** a new AVD from the pinned `android-36` arm64 image, 2400x1080 landscape, named
  `KartPad_0813_Pass<N>`. Game data goes in through the app's own **Import from Extracted Folder…**
  from a copy in Downloads, never pushed into app storage. Also a tablet-size AVD for menu pages.
- **iPhone/iPad:** `xcrun simctl erase` on dedicated iPhone and iPad devices, then the app's own
  import.
- **Mac:** a fresh `~/Library/Application Support/KartPad`, with the developer's folder moved aside
  and restored afterwards.
- **Updates:** install released 0.8.12 first, set non-default choices (each speed switch, engine,
  GPU driver, aspect, FPS counter, controls), then install the candidate over it.

### What counts as worse

- **Speed:** game-thread CPU per frame more than 5% above the baseline in any scene, which is the
  bench's noise. Changes under 10% need three alternating rounds before being called either way.
- **Menus:** a page that differs from the approved map, text that's cut off or overlaps, a row
  that can't be reached with a controller where it could before, a missing screen-reader label,
  or Back landing anywhere other than the previous page.
- **Behaviour:** any change to a race, online play, ghosts, saves or Retro Rewind.

## Boundaries

- **Never publish game code**, packs, disc files, saves or game-derived profiles. They stay in
  `build/` and `private/`. Screenshots that show game scenes stay private. Menu screenshots of
  KartPad's own pages can go in PRs.
- **Saved settings survive.** Renames and regrouping change labels and layout only. Every stored
  key keeps its value, and a test proves it for each moved or regrouped setting.
- **Same change on every runtime** for shared runtime code. Write submodule pins with
  `git update-index --cacheinfo` or from a clean checkout, never `git commit -a` with submodules at
  other commits.
- **Device data:** back up app data before reinstalling, and run `adb shell sync` before every
  `adb emu kill`.
- **tvOS is out of scope** for the menu work. Its build still has to pass, unchanged.
- **Releases, issue replies and closing issues need Chris.** The candidate stays a draft until he
  publishes.

## Goals

Evidence goes in `docs/artifacts/2026-11-28/<goal>/` (no game content) and private outputs in
`build/release-0813/`.

### R0. Baselines and tools (Must)

- **Screens.** A small capture tool per platform, kept in `tools/menu-capture/`: Android
  (`uiautomator` dump plus `screencap` for each page, walked from the menu tree), iOS
  (`simctl io screenshot`, driven with `axe`), Mac (`screencapture` of the Settings window). Use it
  to capture every page and dialog of released 0.8.12 on Android phone and tablet, iPhone, iPad and
  Mac, including the launch screens (Android's On launch, Graphics engine and Help, the iOS game
  selector, the Mac menu bar).
- **Settings matrix.** Every setting by platform: name, page, order, default, stored key and file,
  and whether it exists there.
- **Speed.** Game-thread CPU per frame at the main menu, Select Cup and Grand Prix race 1, on a free
  core and a shared core, three rounds each.
- *Done when* all three are committed, and the capture tool reruns from one command per platform.

### R1. Retro Rewind end-of-cup crash, #131 (Must)

- **Reproduce** with the October cup harness
  ([131-cup-ceremony-harness.md](artifacts/2026-10-04/android/131-cup-ceremony-harness.md), debug
  builds only), which forces a finish after N frames. Run Retro Rewind 6.13.5 cups with both a
  forced 1st place (trophy ceremony) and last place (no-trophy ending). It has only ever been run on
  Original.
- **Find the archive.** The failure is `ARC::InitHandle` on a bad archive while
  `RecognizePadWindow` attaches its layout during the awards section's setup. Log which archive
  handle and source file it uses. Check the likely causes in order: a Retro Rewind replacement
  (`ReplacedAssets.szs`, `RaceAssets_AS.szs`) missing or overlaid wrongly for that section, an
  archive still loading when it is used, or a heap running out after four races.
- **Check #537**, the online "disc error" kick, for the same cause.
- *Done when* the fix is merged and a cup finishes in Retro Rewind and Original, both endings, on
  Android and in the Simulator. If it hasn't reproduced after one day, record what was tried and
  ask Chris whether to hold the release.

### R2. The settings map (Must, approval point)

Written into SETTINGS.md as a draft from the R0 matrix: every surface, page, row name and order,
the platform-only rows, and what moves where. Starting proposal:

- **In-game menu, every platform where it applies:** Return to KartPad Menu, Multiplayer…,
  **Controls**, **Speed & Graphics**, **Display**, **Sound**, **Game Data & Saves**, **Help & Report**.
- **Speed & Graphics:** a **Speed** choice first, then Recommended for This Phone, the individual
  switches, and an **Advanced** section (Graphics Engine, with both engines labelled as Vulkan on
  Android, GPU Driver, 120 FPS Races, Graphics Diagnostics).
- **One name per thing** on every platform (controller setup, the diagnostic log, frame
  interpolation), and Test Native Crash only in diagnostic builds.
- **Speed presets** (to be measured in R4 before the values are final):

| Preset | 30 FPS Races | Simpler Computer Karts | Render Resolution | For |
| --- | --- | --- | --- | --- |
| Smoothest | On | On | 1× | Phones that slow down in races |
| Balanced | Off | On | 1× | Phones that hold 60 with a little help |
| Best Quality | Off | Off | 2× | Fast phones, iPads and Macs |

  Render Resolution stays at 1× below Best Quality because these phones wait on the processor, so a
  lower resolution rarely helps (see [performance handoff](ANDROID-PERFORMANCE-HANDOFF.md)). The
  Speed row shows **Custom** whenever the switches don't match a preset. Existing players see the
  preset that matches their switches, or Custom. 120 FPS Races stays a separate Advanced switch.
- **A "where things moved" table** for SETTINGS.md and the release notes.
- *Done when* Chris approves the map, including the preset names and values and the default for
  new installs. No menu code changes before that.

### R3. Merge what is ready (Must)

In the order from [CURRENT-LOOP](CURRENT-LOOP.md): #594, #597, #598, #600, then #579, then #596
(rebased), then wiicompiled#39 and #599, then wiicompiled#34–#38 and #595 if Chris includes it.
Rerun the full test suite after each merge.
- *Done when* everything included is on `main` and its second pass is clean.

### R4. Speed & Graphics on Android (Must)

Build the page from the map. The presets write the existing settings, so nothing new is stored
except, if needed, the chosen preset. The slow-race offer (#599) switches to **Smoothest**, and
Recommended for This Phone offers a preset. The diagnostic log records the preset.
- *Done when* each preset is measured in a race on the emulator, free and shared core (frame-rate
  log lines, low-detail karts, game-thread CPU), Custom appears when a switch is changed, choices
  survive an engine switch and an update over 0.8.12, and menu tests cover every row.

### R5. The rest of Android (Must)

The launcher screen and every in-game page renamed, regrouped and reordered per the map.
- *Done when* captures match the map on phone and tablet sizes, controller navigation and TalkBack
  labels work on every changed page, and settings survive an update.

### R6. iPhone and iPad (Should)

The same map, presets and names in the iOS menus and game selector.
- *Done when* captures match the map in the iPhone and iPad simulators, each preset works in a race,
  VoiceOver labels are present, and settings survive an update.

### R7. Mac (Could, if Chris keeps it in scope)

The Settings window and menu bar follow the same groups and names, and gain 30 FPS Races, Simpler
Computer Karts and the Speed choice.
- *Done when* captures match the map in a local Mac build, a race runs with each preset, and the Mac
  player check passes.

### R8. Interrupt-flag fix (Could)

Parity loop P2, from DriftDroid `ef99dbe`: carry the guest interrupt-enable state across thread
switches, on every runtime.
- *Done when* merged with emulator numbers showing it faster or neutral beyond noise, and menus,
  races, online and audio unchanged. Left out if it can't be shown safe in time.

### R9. Words and docs (Must)

SETTINGS.md from the final map, KNOWN-ISSUES, a "speed on your phone" table in the README, release
notes with the "where things moved" table and **Not checked**, and draft replies for every issue the
release touches (#131, #104, #301, #554, #576, #584 at least).
- *Done when* every user-visible string has been read against the map once by the author and once
  more in the release gate.

### R10. Release candidate (Must)

Bump `version.json`, build the Android APK, the iPhone/iPad app for PadMint and the PadMint recipe,
run the final combined second pass, then the release gate on those exact files. Leave the release as
a draft.
- *Done when* every behaviour check passes or is listed under **Not checked**, and Chris has the
  draft to publish.

## Reporting

At the end of each goal, a short update to Chris: what changed, which checks passed, numbers, the PR,
what's next. At R2, R1's one-day limit and R10, stop and wait for him.

## Decisions for Chris

1. **The settings map** (R2): structure, preset names and values, and the default for new installs.
2. **Mac** in this release (R7), or 0.8.14.
3. **#595**, native menu-video decoding. It changes every runtime and the translator, so the
   release needs the full iPhone/iPad and Mac checks.
4. **#131 deadline:** whether to hold the release past R1's one day.
5. **The Pixel 9 Pro XL** for the release gate, if you can connect it.

## Journal

Newest first: goal, what changed, which checks passed, PR, next step.

- **28 November.** Loop written and revised (finish line, cut lines, presets, all menu surfaces,
  clean-device procedure, #131 harness). Nothing started. No new player reports since 26 November.

