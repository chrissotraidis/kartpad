# Install the experimental KartPad Apple TV build

KartPad `v0.4.11-tvos.1` includes an unsigned ARM64 tvOS IPA for hardware bring-up. It
carries forward the cache-root storage correction and adds a generic compiler
baseline with RCpc instructions disabled and audited out of the final binary.
It also includes the issue #94 numeric console-serial correction. Older tvOS
builds should remain offline. Existing incorrect server-side identity history
requires service-admin review; updating does not reset accounts or remove bans.
Treat it as an experimental build, not supported Apple TV functionality.

1. Download `KartPad-v0.4.11-tvos.1-unsigned.ipa` and `SHA256SUMS` from
   the [0.4.11 Apple TV release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.11-tvos.1)
   and verify the checksum.
2. Re-sign the IPA with your own Apple development identity and bundle
   identifier, then install it on a paired Apple TV through Xcode or a
   compatible tvOS signing workflow.
3. Set `KARTPAD_TVOS_BUNDLE_IDENTIFIER` to the signed identifier before using
   any repository device script.
4. Stage your own extracted PAL `RMCP01`, revision-0 `DATA` directory with
   `scripts/stage-tvos-game-data.sh`.
5. Follow the [tvOS test guide](TVOS-TESTING.md) in order and stop at the first failure.

An Extended Gamepad is required for racing. The Siri Remote is supported only
for the native setup screens. The app does not include a disc image, extracted
Nintendo assets, Retro Rewind pack, saves, signing identity, provisioning
profile, or Wii banner artwork. KartPad downloads and hash-verifies the pinned
official Retro Rewind pack only after the tester selects that mode.

Update in place with the same signing identity and bundle identifier. KartPad's
tvOS config, NAND, saves, logs, game data, and downloaded pack live under
`Library/Caches`; tvOS may purge them under storage pressure. Run
`scripts/backup-tvos-state.sh` before and after meaningful testing and before
deleting the app or changing signing identities. Never attach game data, Retro
Rewind files, saves, signing material, device identifiers, or a complete app
container to a public report.
