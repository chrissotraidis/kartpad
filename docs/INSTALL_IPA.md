# Install KartPad on iPhone and iPad

> [!IMPORTANT]
> Use the [latest PadMint](https://github.com/chrissotraidis/padmint/releases/latest)
> for the [latest KartPad](https://github.com/chrissotraidis/kartpad/releases/latest).
> On an Apple Silicon Mac with Xcode, or experimentally on a Windows or Linux
> computer, PadMint makes a complete personal IPA from your own disc. See
> [Get KartPad](../README.md#get-kartpad) for the steps.

PadMint's IPA is unsigned: sign and install it with your existing compatible
Apple identity and update in place to keep your saves. Older version notes
below are kept for reference.

0.5.0 added a persistent Auto-accelerate opt-out and corrected shader
startup pressure, framebuffer-copy crashes, and incomplete generated textures.
See the [release notes](releases/v0.5.0.md).

The IPA declares **iOS/iPadOS 16 or newer** and an ARM64 device with Metal.
The generic ARM64 startup correction is retained. The A10X reporter confirmed
startup and Original/Retro loading in build 29, but reported lower performance;
see [issue #135](https://github.com/chrissotraidis/kartpad/issues/135).
These results do not establish performance on every device.

**Update before online play:** 0.4.11/build 26 fixes the incorrect console-serial
value reported in [issue #94](https://github.com/chrissotraidis/kartpad/issues/94).
Older IPAs should remain offline. This does not erase incorrect serial history
already held by a server or clear bans; affected accounts may need service-admin
help. Never reset identities or delete saves as a workaround.

1. Make your personal IPA with PadMint (see
   [Get KartPad](../README.md#get-kartpad)). It runs on an Apple Silicon Mac
   with Xcode, or experimentally on Windows or Linux, and accepts your own
   supported disc image as ISO, WBFS or RVZ. It also saves a `KartPad game
   data` folder.
2. Keep the IPA private. It contains code translated from your game and must
   not be shared or uploaded.
3. Re-sign and install it with AltStore Classic plus AltServer or another
   compatible IPA-signing workflow. AltStore PAL cannot import arbitrary
   unsigned IPA files.
4. On first launch, tap **Import Game** on the Mario Kart Wii card, then
   **Import from Extracted Folder…**, and pick the `KartPad game data` folder
   PadMint made. Get it onto the device first: AirDrop it from a Mac, or put it
   in iCloud Drive, on a USB drive or in a cloud drive app. Alternatively,
   **Choose WBFS, ISO, or DATA Folder…** accepts your own legally obtained PAL
   (Europe) `RMCP01` revision 0 ISO/WBFS or extracted DATA folder; convert RVZ
   first. An ISO/WBFS needs your own 16-byte Wii common key saved as
   `common-key.bin` in **Files → On My iPhone/iPad → KartPad**; KartPad does
   not include it. A folder does not need the key.
5. Choose **Mario Kart Wii** for the original game or **Retro Rewind** for the
   optional expanded game. KartPad can download, verify, and install the
   official version-locked Retro Rewind 6.12.8 full pack.

Choose **Help** on the game chooser for the two-step setup instructions and
GitHub guides. The normal landscape iPhone chooser fits without scrolling;
large accessibility text can scroll to remain readable.

## Player identity

To change an existing online name, open **••• → Game Data & Saves → Player
Identity… → Rename or Delete Licenses…**. Choose the exact Original or Retro
Rewind profile and numbered slot, then choose **Rename License…**. KartPad
preserves that license's friend code, account data, records, and progress.

To remove a duplicate, choose that exact profile and slot, then **Delete
License…**. Read the second confirmation carefully: deleting a license removes
its friend code, account data, records, and progress. Other licenses retain
their slots. Fully close KartPad from the app switcher and reopen it to apply
either operation. Returning to the KartPad menu and resuming does not apply
pending changes. The live save is revalidated and backed up first.

Use **Edit Mii Name…** to rename a Mii and licenses already linked to it. To
create a license, choose **New** inside the game and select your Mii. Use
**Import Mii Appearance…** for a standard 74-byte `.mii` file. **Remove Mii
Appearance…** does not delete a game license and is blocked while the Mii is
still linked to one.

The latest update also aligns the mobile settings order and labels, adds **Game Data & Saves → Time Trial Ghosts** for Original `.rkg` transfers, expands controller remapping, and provides Small/Medium/Large FPS counters. The iPhone report form now scrolls correctly. See [mobile settings](SETTINGS.md) for supported workflows and platform differences.

## Import and controls

The experimental direct Wii Remote/Nunchuk pairing flow is macOS-only; the IPA
does not claim direct Wii Remote pairing on iPhone or iPad.

If **Import from This Installation's Folder…** cannot see a game image because
the signer created a different app container, KartPad opens the normal Files
picker automatically. Select the visible WBFS/ISO there; the app still validates
the exact supported game before importing it.

## Files access

KartPad already enables `UIFileSharingEnabled` and
`LSSupportsOpeningDocumentsInPlace` for iPhone and iPad. In Apple's Files app,
open **Browse → On My iPhone/iPad → KartPad** to manage its Documents folder.
Finder's device file-sharing view exposes the same folder on a connected Mac.
You can copy your ISO/WBFS into that folder and select it with KartPad's import
picker. Files may also be selected directly from another Files provider.

This folder is not the entire app container. Live saves, installed Retro content,
and the Mii database currently remain under Application Support. The sharing
flags do not expose those directories or add save/Mii export controls. Use the
existing **Player Identity → Import Mii Appearance…** action for `.mii` imports.

## Content and updates

The IPA includes KartPad's ARM64 app and ahead-of-time translated executable
module. It does not include a Mario Kart Wii disc image, extracted courses,
textures, audio, saves, signing certificate, or provisioning profile. The app
still requires the supported user-supplied image because those non-executable
game files are imported privately on the device.

The Retro Rewind pack is also not included in the IPA. Its official download is
about 1.72 GiB, and installation needs additional temporary space. KartPad
checks the official version feed before launching Retro Rewind and asks for a
compatible KartPad update if the online-compatible content profile advances.
The accepted physical iPad flow completed the download, verification,
installation, launch, and a playable single-player match.

Production-online acceptance is separate from offline gameplay and package
audits. See the [online status](ONLINE.md) for tested flows and remaining gaps.

Updating in place with the same bundle identifier and signing identity is the
safest way to retain game data and saves. A clean uninstall can remove the app
container, so back up anything important before uninstalling or changing
signing identities.

The Personal IPA Builder remains available for developers and future verified
container or executable profiles. A locally generated personalized IPA is a
separate, unaudited artifact and is not the published release artifact.
