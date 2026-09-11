# Install the KartPad unsigned IPA

KartPad `v0.4.16-ios.2` (0.4.16, build 36) is the current unsigned ARM64 IPA
for iPhone and iPad. It is a free community release, not an App Store or
TestFlight build. Re-sign it with your existing Apple identity or compatible
personal sideloading tool before installing. It adds reviewed-log acknowledgment
and an inability explanation while retaining the newer chooser and help. It is
rebuilt against official Retro Rewind 6.12.8 inputs. Build 36 also contains the
guard for malformed Retro Rewind REL diagnostics that caused the reported
post-chooser crash. See the [release notes](releases/v0.4.16-ios.2.md).
Focused UIKit and package checks passed; physical acceptance is limited to the
attached iPhone 14 on iOS 26.6.1.

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

1. Download `KartPad-v0.4.16-ios.2-unsigned.ipa` and `SHA256SUMS-ios` from the
   [official iPhone/iPad release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.16-ios.2).
2. Run `shasum -a 256 KartPad-v0.4.16-ios.2-unsigned.ipa` on a Mac and
   compare it with the IPA row in `SHA256SUMS`. The notices and shared source
   have separate rows; the source download is optional for normal installation.
3. Re-sign and install it with AltStore Classic plus AltServer or another
   compatible IPA-signing workflow. AltStore PAL cannot import arbitrary
   unsigned IPA files.
4. On first launch, choose **Import Game** on the Mario Kart Wii card and select
   your own legally obtained PAL (Europe) `RMCP01` revision 0 ISO/WBFS. An extracted
   DATA folder also works; convert RVZ before importing.
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

## Import and controls

The experimental direct Wii Remote/Nunchuk pairing flow is macOS-only; the IPA
does not claim direct Wii Remote pairing on iPhone or iPad.

If **Import from This Installation's Folder…** cannot see a game image because
the signer created a different app container, KartPad opens the normal Files
picker automatically. Select the visible WBFS/ISO there; the app still validates
the exact supported game before importing it.

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
