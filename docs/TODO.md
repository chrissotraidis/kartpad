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
