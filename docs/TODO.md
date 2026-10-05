# KartPad to-do

Things we've decided to do later. Each item says why, what "done" looks like,
and where the work lives.

## Updates on iPhone, iPad and Mac

*Added 5 October 2026, after 0.7.14.*

**The gap.** From 0.7.14, Android KartPad updates itself: **Update available →
Update Now** downloads the new APK, checks it and Android installs it. iPhone,
iPad and Mac can't do that:

- **iPhone and iPad:** Apple doesn't let a sideloaded app install apps, so
  KartPad can't replace itself.
- **Mac:** each copy is built by PadMint from the player's own disc, and no
  Mac app is published, so an update means a rebuild.

Today these players get no notice at all that a new version is out.

**What to do, in order:**

1. **An "Update available" notice in KartPad on iPhone, iPad and Mac.** Use the
   same hourly GitHub check Android uses (`KartPadUpdateCheck.kt`): on the game
   chooser, show that a newer version is out and say to rebuild it with
   PadMint, with a link to the release notes. Small and self-contained, in
   `apple/ios` and `apple/macos`.
2. **One-click update in PadMint.** PadMint already knows the player's disc and
   settings, so it can offer "KartPad 0.7.x is out, update?" and rebuild. On Mac
   it can replace the app; on iPhone and iPad it hands the new IPA to the
   player's sideloading tool (Sideloadly, AltStore or SideStore), which still
   does the install. This belongs in the PadMint redesign, not in KartPad.

**Not planned:** AltStore/SideStore source auto-updates. They need a published,
downloadable IPA, and from 0.7.14 we publish only the Android APK.

**Done when:** a player on iPhone, iPad or Mac learns about a new version inside
KartPad, and updating takes one action in PadMint with saves kept.
