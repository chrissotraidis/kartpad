# KartPad to-do

Things we've decided to do later. Each item says why, what "done" looks like,
and where the work lives.

## Next week: Mac menus match Android, iPhone and iPad

0.8.13 gave Android, iPhone and iPad one menu structure (Speed & Graphics with Speed, same page and row names, see [SETTINGS.md](SETTINGS.md)). The Mac wasn't changed and still has its own menu bar (KartPad, Game, Data, Controls, Help) and Settings tabs (Graphics, Audio, Controllers, Game & Data, Advanced). To match:

1. Port 30 FPS Races and Simpler Computer Karts to the Mac runtime. `frame_rate_lock.cpp` and `low_detail_karts.cpp` exist only in the Android and iOS runtimes.
2. Add Speed & Graphics with the Speed choice to the Mac Settings window.
3. Rename and regroup the menu bar and Settings tabs to the shared names ("Controller Settings…", "Frame interpolation" and so on), and update SETTINGS.md.

Check with a local Mac build, a race on each preset, and the Mac player check (release loop goal R7).

## Next build: help slow Android phones without new hardware

*Added 20 November 2026, after 0.8.12.*

**Why.** Almost every open issue is Android, and most are slow phones (#510,
#554, #566, #576, #584, #339) or the Snapdragon 512.762 character fault (#104
and its duplicates). The cause is known: the game runs on one CPU core, and a
race frame takes about 14.5 ms on a Pixel 9 Pro XL, about 29 ms on a Dimensity
7300 and about 45 ms on a Helio G85, against 16.7 ms for 60 FPS. Closing a 2–3×
gap needs structural engine work, and we decided (11 October, confirmed 20
November) not to buy slow test phones, so that work would be measured blind.
These items don't make slow phones faster. They help players get the most out
of the phone they have, and turn "so laggy" reports into numbers we can use.

**What to do, in order:**

1. **Merge the #554 diagnostics** ([#579](https://github.com/chrissotraidis/kartpad/pull/579)):
   touch idle time and CPU clocks in the log, so we can see whether a phone
   slows its CPU when no finger is on the screen.
2. **A one-tap performance check (Android).** **⋯ → Graphics & Performance →
   Check This Phone's Speed** runs about 30 seconds of the game's own attract
   demo and shows a plain result: game-thread milliseconds per frame, the
   expected frame rate, CPU clock range and thermal state, and what to turn on.
   For example: "Your phone needs about 38 ms per frame; 60 FPS needs 16.7 ms.
   Expect about 25 FPS. 30 FPS Races will make races smooth." A **Copy Result**
   button puts a one-line summary on the clipboard for a GitHub issue or
   Discord. The numbers already exist (`KartPadSched`, `KartPadCPU`,
   `[KartPadDiagnostic] kind=frame`); this only gathers and explains them.
3. **Offer the right setting after a slow race (Android).** If a race averages
   under about 50 FPS with 30 FPS Races off, show once: "Races are running slow
   on this phone. Turn on 30 FPS Races and Simpler Computer Karts?" with
   **Turn On** and **Not Now**. Don't ask again after Not Now. On a Snapdragon
   phone on Qualcomm's 512.762 driver, offer Turnip once at first start, using
   the rules in `KartPadPhoneAdvice.kt`.
4. **Hide 120 FPS Races on the Classic engine.** On the Pixel 9 Pro XL it held
   120 FPS on Beta but dropped Classic races to 47–57 FPS with stutter. Show
   the switch only with the WiiCompiled 0.9 (Beta) engine, or show "Needs the
   Beta graphics engine" and turn it off when the player switches to Classic.
5. **Set expectations up front.** Keep the README's
   [What to expect on your phone](../README.md#what-to-expect-on-your-phone)
   table current, ask for the performance check result in the bug report
   template, and answer slow-phone duplicates with a link to the table and the
   check.
6. **Fold the Snapdragon duplicates** (#301, #472, #492, #552) into #104, so the
   512.762 fault has one thread. Needs Chris's OK, because closing notifies
   reporters.

**Done when:** a player on a slow phone gets smooth races without hunting
through menus, and a slow-phone report arrives with a performance check result
we can compare against the table.

**Not in this plan:** the structural speed work (moving graphics bookkeeping
off the game thread, the per-access memory cost, translator code quality).
It's in [Android performance](ANDROID-PERFORMANCE-HANDOFF.md#next-steps-in-order)
and needs a phone that reproduces the slowness before a result can be trusted.

## Updates on iPhone, iPad and Mac

*Added 5 October 2026, after 0.7.14.*

**The gap.** From 0.7.14, Android KartPad updates itself: **Update available →
Update Now** downloads the new APK, checks it and Android installs it. iPhone,
iPad and Mac can't do that:

- **iPhone and iPad:** Apple doesn't let a sideloaded app install apps, so
  KartPad can't replace itself.
- **Mac:** each copy is built by PadMint from the player's own disc, and no
  Mac app is published, so an update means a rebuild.

**Status, 15 October:** step 1 shipped in 0.8.0 and is in the current 0.8.1
release. **Update available** appears on the iPhone/iPad game chooser, and Mac
has **Help → Check for Updates…**. Installing still means a PadMint rebuild.
Step 2, the one-click rebuild in PadMint, is still open.

**What to do, in order:**

1. **An "Update available" notice in KartPad on iPhone, iPad and Mac (done in 0.8.0).** Use the
   same hourly GitHub check Android uses (`KartPadUpdateCheck.kt`): on the game
   chooser, show that a newer version is out and say to rebuild it with
   PadMint, with a link to the release notes. This is in 0.8.0 and later, in
   `apple/ios` and `apple/macos`.
2. **One-click update in PadMint.** PadMint already knows the player's disc and
   settings, so it can offer to rebuild when a new KartPad is out. On Mac
   it can replace the app; on iPhone and iPad it hands the new IPA to the
   player's sideloading tool (Sideloadly, AltStore or SideStore), which still
   does the install. This belongs in the PadMint redesign, not in KartPad.

**Not planned:** AltStore/SideStore source auto-updates. They need a published,
downloadable IPA, and from 0.7.14 we publish only the Android APK.

**Done when:** a player on iPhone, iPad or Mac learns about a new version inside
KartPad, and updating takes one action in PadMint with saves kept.

## Optional touch item hold (#473)

**Done in 0.8.4** (Android and iPhone/iPad; the hold was shortened to 0.67
seconds in 0.8.5). The original plan is kept below for reference.

Requested on Pixel 10a / Android 17 / KartPad 0.8.1, with matching behavior
wanted on iPhone/iPad. Holding L to trail a defensive item competes with
steering and drifting on a touchscreen.

Keep it separate from auto-accelerate and off by default. Proposed behavior:
hold L to lock, press L again to release, show the locked state, and clear it
on menu entry, app backgrounding, controller handoff and layout editing. A short
tap must keep its ordinary item behavior; accessibility needs an equivalent
lock/release action. No saved held button across launches.

Not implemented. Before shipping, check defensive-item trailing and release,
ordinary item use, multiple touches and lifecycle cancellation on Android and
iPhone/iPad. [Request and reply](https://github.com/chrissotraidis/kartpad/issues/473#issuecomment-6159856629).
