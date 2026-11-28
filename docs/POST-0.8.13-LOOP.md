# After 0.8.13: follow-up loop

Started 28 November 2026, the day 0.8.13 (build 279) was published as Latest. It tracks what 0.8.13 fixed,
which players we're waiting on, and what's still left, until every row is confirmed, closed by Chris or
moved to a later loop with a reason. The release itself is in [the 0.8.13 release loop](RELEASE-0.8.13-LOOP.md).

## Each pass

1. **Check the issues** in *Waiting on players* for new comments:
   `gh issue list --repo chrissotraidis/kartpad --state all --search "updated:>=<last pass date>"`.
   Write what each reporter said into the table, with the date.
2. **A reporter confirms a fix:** thank them, move the row to *Confirmed*, update KNOWN-ISSUES and STATUS,
   and ask Chris before closing the issue (closing notifies everyone on it).
3. **A reporter says it still happens:** download their log, note the version and setting, and move the
   item to *Remaining work* with what the log shows.
4. **Work *Remaining work* top-down.** Each item gets its own PR with its checks, and updates the docs it
   changes in the same PR (README, SETTINGS, KNOWN-ISSUES, STATUS, TODO).
5. **Read the docs list** at the end, and fix any stale wording you find.
6. **Add a journal line** with the date, what changed and what's next.

## Fixed in 0.8.13

| Change | Issues | Checked | Confirmed by a player |
| --- | --- | --- | --- |
| Retro Rewind award archives mapped for every language, so cups end without a crash | #131, #493 | Emulator, Retro Rewind in Spanish: trophy ceremony and low-finish ending both return to the menu; crashed before the fix | Waiting |
| **Speed & Graphics** with **Speed** (Smoothest, Balanced, Best Quality) on Android, iPhone and iPad | #576, #510, #566 | Emulator and Pixel 9 Pro XL: presets, Custom, settings kept on update, `result=30_forced` races. iPhone/iPad compiled and passed the player check only | Waiting |
| Slow-race offer switches to Smoothest | #599 | Emulator end to end in #599; this build's emulator races hold 60, so it didn't appear | Waiting (slow phone) |
| Turnip offered once at start on the 512.762 driver; Mr. Purple's Turnip in the download list | #104, #301 | Emulator shows the non-Snapdragon path; no Adreno phone | Waiting |
| Native menu-video decoding | #584 | Emulator: video thread about 43% less work at the main menu and Select Cup | Waiting (Helio G99) |
| Graphics engines labelled Vulkan | #576 | Emulator and Pixel | Done |
| 120 FPS Races only with the Beta engine | #596 | Emulator and Pixel | Done |
| Touch-idle and CPU-clock fields in the diagnostic log | #554 | Emulator log | Waiting (log) |

## Waiting on players

Replies posted 28 November. None closed.

| Issue | Reporter | We asked for | Latest |
| --- | --- | --- | --- |
| [#131](https://github.com/chrissotraidis/kartpad/issues/131) | iStraySh | Finish a Retro Rewind cup in Spanish on 0.8.13 | — |
| [#493](https://github.com/chrissotraidis/kartpad/issues/493) (closed) | jossol27 | The same | — |
| [#576](https://github.com/chrissotraidis/kartpad/issues/576) | AchieveFreedom | Try Smoothest; a log from a slow moment | — |
| [#584](https://github.com/chrissotraidis/kartpad/issues/584) | kevinguerrero1826-cpu | Whether character and track select feel better; a Select Cup log | — |
| [#104](https://github.com/chrissotraidis/kartpad/issues/104) | Snapdragon 512.762 players | The start-up Turnip offer and the confirmed builds | — |
| [#301](https://github.com/chrissotraidis/kartpad/issues/301) | PeriTheFrost | The same, and Smoothest for speed | — |
| [#554](https://github.com/chrissotraidis/kartpad/issues/554) | Sharik7 | One online race with the gas latched, one holding A, then a log | — |
| [#566](https://github.com/chrissotraidis/kartpad/issues/566) | motoharu-reiMa | A long session on 0.8.13 with Smoothest | — |
| [#510](https://github.com/chrissotraidis/kartpad/issues/510) | Michele | The same | 28 Nov: no lag over three cups on 0.8.13 (Galaxy S10 Lite, Smoothest); log shows steady 30 FPS, no throttling, texture memory flat. Asked for a log if it comes back. Also asked for Wiimmfi (#90) |

## Confirmed

| Issue | What the reporter saw | Date | Next |
| --- | --- | --- | --- |
| [#510](https://github.com/chrissotraidis/kartpad/issues/510) | Three cups on 0.8.13 with Smoothest, no lag (log: 30 FPS, no throttling, texture memory flat) | 28 Nov | Chris decides whether to close; one more long session would make it firmer |

## Remaining work

1. **Mac menus match Android, iPhone and iPad** (next week): port 30 FPS Races and Simpler Computer Karts to
   the Mac runtime, add Speed & Graphics, use the shared names. See [to-do](TODO.md#next-week-mac-menus-match-android-iphone-and-ipad).
2. **iPhone/iPad menus in the Simulator.** The Simulator build stops on the Dawn archive: the pinned hash is
   `feb5c4e0…`, the cached copies are `1bf95e9f…`. Rebuild it with `scripts/build-dawn-ios-simulator.sh`,
   then run release checks 7–11 in the Simulator.
3. **Retro Rewind upstream report.** Chris posts the note in
   [reply drafts](artifacts/2026-11-28/reply-drafts.md) as a new rr-pulsar issue if he wants Retro Rewind to
   fix its XML. KartPad's mapping steps aside once the XML lists the files.
4. **The eight-course memory loop.** `scripts/android-course-memory-loop.sh` loses sync with the menus (it
   must start on the title screen, and short taps don't register reliably). Make it wait for the title
   screen and hold each press, then record a 0.8.13 baseline for release check 6.
5. **Measure the Speed presets** on the emulator, free and shared core (release loop R4), including whether
   Balanced helps on its own. The README says neither has been measured on a phone.
6. **iOS runtime pin.** 0.8.13 pins `25e015d`; `kartpad-ios` also has `515f901` (iPad portrait
   orientations for the TV-display work). Decide together with that work before the next iOS repin.
7. **Runtime comment fix** (wiicompiled #44–#47, comment only): pin with the next runtime change.
8. **Slow-phone plan items left** ([to-do](TODO.md#next-build-help-slow-android-phones-without-new-hardware)):
   the one-tap performance check, the bug-report template field, and folding the Snapdragon duplicates into
   #104 (needs Chris).
9. **Interrupt-flag fix** (release loop R8, DriftDroid parity loop P2).
10. **#537** (online "disc error" kick) still needs the reporter's `ERROR: DVD read failed` line. It isn't
    the #131 cause.
11. **Next release notes:** the 0.8.13 source archive carries the first wording of the movie claim ("decodes
    the same as before"); nothing to change in 0.8.13, but keep the corrected wording.

## Docs updated for 0.8.13

README (current release, speed table, menu paths), STATUS, CURRENT-LOOP, SETTINGS (map, Speed, where things
moved), KNOWN-ISSUES (#131, menu paths), TODO (Mac, slow-phone plan status), FUTURE-FEATURES, MAINTENANCE-BOARD,
INSTALL_ANDROID, RELEASING_ANDROID, release notes. When touching a doc, check it says **Speed & Graphics**
(Graphics & Performance only in history) and doesn't call a 0.8.13 change "the next version".

## Journal

Newest first.

- **28 November, evening.** Chris posted the Discord announcement. Michele (#510) reported no lag over
  three cups on 0.8.13 with Smoothest; his log confirms it; replied, and pointed his Wiimmfi request to
  #90. CURRENT-LOOP's 18–20 November list is marked superseded by this loop.

- **28 November.** 0.8.13 published as Latest (Chris's decision; the release loop had planned a prerelease
  because no slow or Snapdragon phone ran it). Files downloaded anonymously and matched SHA256SUMS; the
  in-app update API reports v0.8.13. Replies posted on #104, #131, #301, #493, #510, #554, #566, #576, #584.
  Discord post and banner made. After publishing, the PadMint player checks against Latest passed for Android (6 min), iPhone/iPad (5 min) and Mac (12 min), from PadMint `main` (`cea6b43`).
