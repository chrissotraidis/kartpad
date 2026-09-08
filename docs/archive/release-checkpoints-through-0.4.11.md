# KartPad release checklist

> Historical record retained during the 9 September 2026 documentation cleanup.
> Versions, task ownership and pending actions describe their original checkpoint.
> Use [current status](../STATUS.md) and the [maintenance board](../MAINTENANCE-BOARD.md) for active work.

## iPhone/iPad 0.4.11 console-serial hotfix

- [x] Retain the credited upstream fix and host/Android ARM64 regressions.
- [x] Rebuild the native ARM64 iPhone/iPad app as 0.4.11/build 26; app audit passes.
- [x] Inspect the linked serial routine: numeric byte reversal and a four-byte
      store replace the old string write; 140 Python tests and source/safety
      checks pass.
- [x] Merge release metadata, rebuild from exact main, package twice and audit.
- [x] Publish the new IPA/checksum, anonymously download and re-audit.
- [x] Update issue #94 with the verified download and remaining boundaries.

Old packages remain offline-only; the Mac and tvOS rebuilds are tracked below. No new physical
online race or server-history cleanup is inferred from these checks.

## macOS 0.4.11 console-serial hotfix

- [x] Rebuild both executable profiles from freshly patched source.
- [x] Audit the signed app and inspect the linked corrected serial write.
- [x] Run bounded local launch/close checks without touching installed saves.
- [x] Merge metadata, package exact main twice and audit extracted signatures.
- [x] Publish only Mac ZIP/checksum, anonymously download and re-audit.
- [x] Update issue #94 and the current download documentation.

## First Android community release (v0.4.10-android.1)

- [x] Owner accepts Original/Kishi gameplay, automatic touch hiding and reports
      Retro WFC worldwide live racing on the physical Pixel.
- [x] Keep performance/device/controller limits explicit; preserve phone data.
- [x] Integrate current main licensing and the upstream issue #94 serial backport.
- [x] Rebuild the native runtime, pass host and ARM64 serial regressions, and
      inspect the corrected linked four-byte write.
- [x] Audit AAB/APK, reject debug signing and wrong versions, derive identical
      signed APK bytes twice, and verify fresh emulator install/import entry.
- [x] Merge reviewed source and publish only APK, notices and checksums.
- [x] Download hosted files anonymously, compare and re-audit exact bytes.

See [candidate verification](../artifacts/2026-09-07/android/first-release-verification.md)
and [release maintenance](../RELEASING_ANDROID.md). Original public-signature
physical installation, complete production-online results/reconnect, historical
server CSNum cleanup and sustained 60 FPS are not claimed.

## tvOS 0.4.11 console-serial hotfix

- [x] Prepare fresh dual runtime sources with the credited issue #94 correction.
- [x] Build ARM64 tvOS 0.4.11/build 9 and pass the app/RCpc/private-data audit.
- [x] Verify linked serial write and repository/source checks.
- [x] Merge metadata, rebuild exact main, package twice and audit exact IPA.
- [x] Publish only the tvOS IPA/checksum; anonymously download and re-audit.
- [x] Update issue #94 with the verified download and remaining server-history boundary.

No physical Apple TV test, production-online acceptance, DSU support or
external-display fix is inferred from this targeted rebuild.

Published and anonymously re-audited: [v0.4.11-tvos.1](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.11-tvos.1).
See the [exact artifact and triage evidence](../artifacts/2026-09-08/tvos-v0411-release.md).

## tvOS experimental candidate

- [x] Publish the physically untested artifact only as an explicit hardware-
      bring-up preview and direct initial testing to a small Apple TV cohort
      using [`docs/TVOS-TESTING.md`](../TVOS-TESTING.md) and the acceptance matrix
      in [`docs/TVOS.md`](../TVOS.md).
- [x] Label that artifact experimental and unaccepted until tester evidence
      completes the physical Apple TV matrix.
- [ ] Prove Original and Retro Rewind gameplay separately with an Extended
      Gamepad; do not infer Retro WFC acceptance from offline play.
- [ ] Back up and rehearse restore of Caches/KartPad before asking a
      tester to risk saved progress.
- [ ] Re-audit the exact signed tester artifact for private game data, Retro
      Rewind content, derived game artwork, signing material, and local paths.

The exact 67-row matrix in `docs/PRD.md` remains the authority for full
engineering completion. A community preview may ship with narrower, explicit
limitations when its exact artifact passes every preview gate below.

## 0.4.7 macOS first-class candidate

- [x] Build the one-command Mac workflow as dual Original / Retro Rewind
- [x] Validate the exact Retro Rewind folder before selecting that profile
- [x] Verify standard Game, Data, Controls, and Help menus in the built app
- [x] Verify original-game and Retro Rewind launch separately on macOS
- [x] Exercise keyboard gameplay input and the visible mouse/menu path
- [x] Verify controller mapping contracts; keep untested physical hardware
      claims explicit
- [x] Build and audit exact-source macOS 0.4.7 build 21
- [x] Build and audit exact-source iOS 0.4.7 build 21
- [x] Package each artifact twice byte-identically and audit the exact files
- [x] Publish `v0.4.7`, both artifacts, and `SHA256SUMS`
- [x] Download hosted assets, byte-compare, and re-audit them
- [x] Respond to and close issue #79 with the exact commands and evidence

The annotated `v0.4.7` tag resolves to source commit
`061e9bfe3c2e522e58087e908402dc545ae6c1a8`. The downloaded hosted artifacts
matched their local release bytes and passed their extracted-package audits:

- macOS ZIP: `37ae10bb384c776cdbd7596701363f8449c496faa6d6e551ec8d5073b05c38ab`
- iPhone/iPad IPA: `c5750fe718e05d8f18fa986d828de5276e8e721035b33c7cb8572f6d29ad683b`

The keyboard path reached the translated controller core, and the native
controller mapping plus four-slot contracts pass. No specific physical Mac
controller model was accepted in this release, so that hardware claim remains
bounded to the tested contracts and community reports.

## 0.4.6 license-management hotfix candidate

- [x] Enumerate active Original and Retro Rewind licenses by profile and slot
- [x] Rename one exact license without changing its creation ID or other data
- [x] Delete only one guarded license block after an explicit second warning
- [x] Revalidate the live save, back it up, write atomically, and repair CRC-32
- [x] Prevent Mii-appearance removal while a license still references that Mii
- [x] Reassert the persistent three-dot button after an iPadOS screenshot
- [x] Build and audit exact-source iOS 0.4.6 build 20
- [x] Install in place on iPad and preserve its existing data
- [ ] Exercise license rename/delete staging UI without deleting live data
- [x] Package twice byte-identically and audit the exact unsigned IPA
- [x] Publish `v0.4.6`, `KartPad-v0.4.6-ios-unsigned.ipa`, and `SHA256SUMS`
- [x] Download hosted assets, byte-compare, and re-audit them

Published source: `c3ce6fd4fcbc93a1606093af3859c91c1e109c9e`.
iPhone/iPad executable SHA-256:
`a61686b65d6b666b2fee3a3acbee7034a171e712f4596ce0213dbdc830f5ecb6`.
iPhone/iPad IPA SHA-256:
`8c62ff341c8acae085127998e39411238ef93a3297d81687237d96c0c406289e`.
The in-place iPad installation retained the existing WBFS and byte-identical
console identity, Mii database, original save, Retro Rewind save, and
preferences. The same files remained intact after the first 0.4.6 launch.

## 0.4.5 player-identity hotfix candidate

- [x] Reproduce the fixed-name gap on physical iPad Retro Rewind 6.12.7
- [x] Tie renames to the full eight-byte Mii creation ID
- [x] Update matching license names without changing account or progress fields
- [x] Validate Mii database CRC-16 and RKSYS CRC-32 after mutation
- [x] Stage only the rename intent so later gameplay cannot be overwritten
- [x] Back up the Mii database and every modified live save before replacement
- [x] Build and audit exact-source iOS 0.4.5 build 19
- [x] Install in place and verify the existing iPad Mii and linked license
      record contain `Kahris`, with backups created before replacement
- [x] Install in place on iPhone and byte-compare its configuration, identity,
      Mii database, original save, Retro Rewind save, and preferences before
      and after installation
- [x] Package twice byte-identically and audit the exact unsigned IPA
- [x] Publish `v0.4.5`, `KartPad-v0.4.5-ios-unsigned.ipa`, and `SHA256SUMS`
- [x] Download hosted assets, byte-compare, and re-audit them

Published source: `f1cfe0495bf9159b4d4c8d02663003a97b62d7ad`.
iPhone/iPad executable SHA-256:
`764d402d6fa91ecec4a6067e819e0c5f2d2fed235ba2a67849484188b3d3f2ff`.
iPhone/iPad IPA SHA-256:
`c79a19db4d8fdbf64aa7927f13c90c97a18e43ec4898f5b22120ef35a98002ff`.

## 0.4.4 Retro Rewind compatibility candidate

- [x] Hash and inspect the official Retro Rewind 6.12.7 full archive
- [x] Pin the matching Retro Rewind source commit and tree
- [x] Regenerate the complete 6.12.7 graph with zero translation failures
- [x] Preserve strict archive, `Code.pul`, XML, and signed payload checks
- [x] Make the version watcher open one deduplicated maintenance issue
- [x] Add a resumable one-command latest-profile updater
- [x] Pass full repository, source, patch, translator, and native tests
- [x] Build and audit exact-source iOS 0.4.4 build 18 and tvOS build 7
- [x] Package each IPA twice byte-identically and audit exact packages
- [x] Publish `v0.4.4`, both IPAs, and `SHA256SUMS`
- [x] Download hosted assets, byte-compare, and re-audit them
- [ ] Keep production Retro WFC and physical-device acceptance separate until
      the exact candidate completes those gates

Published source: `3b857f9ae2b7933c6eb4f8f8f61a07df6b455624`.
iPhone/iPad executable SHA-256:
`1e251b27a05411f4e03b9d6ff468cb49a7bb111d3648534d32184e2493c089c7`.
iPhone/iPad IPA SHA-256:
`5d2428abe9e4e0a7736912669c05fe8b40d3d5b34fcf85d05f3d31f336c6ed11`.
tvOS executable SHA-256:
`0bd0409e4cfb14fd4850ebae96b1cd5e85e6c6476dee94b872426a78c91c6d47`.
tvOS IPA SHA-256:
`b508d45fc4426190e7c25c6f57c31ec838f71f02a666feb07b06ca379a976f66`.

## 0.4.3 community maintenance candidate

- [x] Review all open non-maintainer pull requests at their exact heads
- [x] Accept only source changes with a reproducible defect or bounded feature
- [x] Preserve individual contributor attribution through separate merges
- [x] Validate the combined translator, native tests, and unsigned iPhoneOS app
- [x] Build and audit exact merged-source iOS 0.4.3 build 17 and tvOS build 6
- [x] Package both IPAs twice byte-identically and pass fresh extraction audits
- [x] Publish the stable tag, both IPAs, and `SHA256SUMS`
- [x] Verify fresh hosted downloads byte-for-byte and re-audit them
- [ ] Receive physical acceptance for the exact tvOS artifact before claiming
      A12 compatibility or supported Apple TV functionality

Published source: `2075cacbadbc6053e8fedf6179ab525003bac181`.
iPhone/iPad executable SHA-256:
`a1095e26d931768549c00213b5604f88506814c1b3badfa5f6c55a5072075b26`.
iPhone/iPad IPA SHA-256:
`a8cfe67b068064a9379a88b99e5e15e9fb982b0ef079aac64622e6f4efea8f4d`.
tvOS executable SHA-256:
`a365640bedfd81c779cd98fae9de443c1c81f42f02c19633479ecf77eaafd760`.
tvOS IPA SHA-256:
`878f27afc6900c43e07cb3330f3fa811d0cdd074cbc2f14a7e11f99e574cff31`.

## 0.4.2 maintenance candidate

- [x] Preserve the accepted iPhone/iPad product and tvOS controller/launch flow
- [x] Make guest aspect state follow the existing mobile host selection
- [x] Use the generic tvOS CPU baseline with RCpc explicitly disabled
- [x] Fail closed if Xcode drops the compiler forwarding sequence or the final
      tvOS executable contains an RCpc load instruction
- [x] Build and audit exact merged-source iOS 0.4.2 build 16 and tvOS build 5
- [x] Package both IPAs twice byte-identically and pass fresh extraction audits
- [x] Publish the stable tag, both IPAs, and `SHA256SUMS`
- [x] Verify fresh hosted downloads byte-for-byte and re-audit them
- [ ] Receive physical acceptance for the exact tvOS artifact before claiming
      A12 compatibility or supported Apple TV functionality

Published source: `776a2a6a0e367b6d06f627c983f5da4a565ea104`.
iPhone/iPad executable SHA-256:
`fc9801af64251af68431ca04ce73c76d397cfff4d478c55c66c708cb86fcf704`.
iPhone/iPad IPA SHA-256:
`4c498de9a858bf9d59e6f082ebbe7a34e64935831601dc0981de42be8a8d473e`.
tvOS executable SHA-256:
`ceea40f50dd06d7a1ec7d37ee84cb620a5af74ec885cfb25babc9792583c0f30`.
tvOS IPA SHA-256:
`0802f7e572da3df9b8daf5b09b45717584fad33c07d8be4ba5c6d8fadceaab3f`.

## 0.4.1 tvOS storage hotfix candidate

- [x] Redirect tvOS config, NAND, saves, and logs from Application Support to Caches
- [x] Keep iOS and macOS Application Support behavior unchanged
- [x] Add atomic-write fallback and explicit runtime log-directory creation
- [x] Update cache-first backup and diagnostic collection with legacy log fallback
- [x] Build and audit exact merged-source tvOS app 0.4.1 build 4
- [x] Package twice byte-identically and pass fresh extraction audits
- [x] Publish tag, IPA, checksum, and verify a fresh hosted download
- [x] Receive reporter acceptance on the exact signed hotfix artifact

Published source: `d0e77d5c9bc48a7f1f6aaedf79fd00d5e616dc0c`.
tvOS executable SHA-256:
`a9e5c89ba20406897f8925c48b9683a1582bf902a9335a6922c22db1240f7ce3`.
tvOS IPA SHA-256:
`ca62f6e00e0b5260ddb6b836ae2cda969d3bc5655ba4bd3dac19aa9406249e49`.
The Issue #17 reporter accepted config writes without error 513, both profile
launches, normal-relaunch persistence, and cache-root backup on 2026-09-04.

## 0.4.0 stable candidate

- [x] Physical iPhone launches Retro Rewind 6.12.5 with existing data intact
- [x] Physical iPhone accepts per-control Hide/Show and the editor Back path
- [x] Untouched-iPhone default seeding preserves custom iPhone and iPad layouts
- [x] Full tests, source pins, repository safety, and SunPad snapshot pass
- [x] Exact merged source produces iPhone/iPad build 15 and tvOS build 3
- [x] Both IPAs package twice byte-identically and pass extraction audits
- [x] Stable tag, hosted assets, checksums, and hosted re-audits match locally
- [x] Remote `main` and dereferenced `v0.4.0` match the audited source

Published source: `369159153bef0d045edf5cc1cf3b1b444b36a284`.
iPhone/iPad IPA SHA-256:
`af80c2bc6fcabdb4eee84aed05254eccef76d7e6bbf83f2c7f21101168c665c8`.
tvOS IPA SHA-256:
`9ee2a9b05bff56261d4d4986eca54840e98ade8ae0abd3ac623c1f2393dcf5cc`.

## 0.4.0 Preview 2 candidate

- [x] Official Retro Rewind 6.12.5 archive, code, XML, and upstream source pins
- [x] Fresh 6.12.5 translation graph passes strict function and patch gates
- [x] Kamek v2/v3 parser keeps file and command bounds validation
- [x] Universal iPhone/iPad menu refresh cannot restore the SunPad menu
- [x] Daily upstream-version check and deterministic profile updater
- [x] Exact merged source produces iPhone/iPad build 14 and tvOS build 2
- [x] Both IPAs package twice byte-identically and pass fresh extraction audits
- [x] Release tag, hosted assets, checksums, and hosted re-audits match locally
- [ ] Physical testers accept the 6.12.5 flow and the Apple TV matrix

Published source: `e9fa6058ee09fff0b16481ebe4a78d61cea69c87`.
iPhone/iPad IPA SHA-256:
`a796cd0e29bfd47d78afc50989a959803f9eff434252a3a455af85308b380fe6`.
tvOS IPA SHA-256:
`3f8f529a93cc3f1ddfe9e9b71171ba56ead5a49ae3598c449a42f00eed6c5a9a`.

## 0.4.0 Preview 1 candidate

- [x] Independent native `KartPadDual` tvOS implementation and full arm64 build
- [x] Original three-layer Apple TV icon and Top Shelf catalog compile and audit
- [x] Durable Application Support is separated from purgeable game/mod caches
- [x] Retro Rewind temporary-download lifetime is safe and its pack remains
      pinned, size checked, and SHA-256 verified
- [x] Tester-specific bundle identifiers work across build, audit, staging,
      backup, and diagnostic scripts
- [x] Exact merged source produces iPhone/iPad build 13 and tvOS build 1
- [x] Both IPAs package twice byte-identically and pass fresh extraction audits
- [x] Release tag, hosted assets, checksums, and hosted re-audits match locally
- [x] PR #7 receives an accurate closure response after the replacement lands

Published source: `4d32dfac683966ea1cb4f72963deffbe936404da`.
iPhone/iPad IPA SHA-256:
`5b959d7a6abba43db3d557bbba3dc3a1ab913650f0717cdf8600afa06fcb32c1`.
tvOS IPA SHA-256:
`78dcdf28c947330d480fcc789f0b81b95bafe94497c56f9c26bb6249c5362df1`.

## Published 0.3.0 preview

- [x] Exact source pins, notices, and reproducible dependency graph
- [x] Supported disc identity and private game-data boundary
- [x] Dual-mode Original / Retro Rewind graph and official version lock
- [x] iPhone/iPad ARM64 build, package, privacy, and signature-residue audits
- [x] Physical iPad Retro Rewind download, verification, installation, launch,
      and initial single-player gameplay
- [x] Deterministic IPA packaging and SHA-256 checksum
- [x] Embedded install guide, release notes, provenance, rights, and licenses
- [x] Hosted IPA downloaded, byte-compared, checksum-verified, and re-audited
- [x] Dereferenced release tag and hosted artifact provenance match the audited
      source commit

Published artifact: `v0.3.0-preview.3`, app 0.3.0 build 10, source
`452af2dde3d19508a5e6ced6c03deb0e24b8b509`, IPA SHA-256
`e839c115a97867949b16fa1c4a2a3472dce4eb3da6c69fff6f40c3eca2abbdcf`.

## Published 0.3.0 Preview 4

- [x] Experimental Mii database and Apple integration contracts pass
- [x] Experimental macOS Wii pairing compiles, links, packages, and carries
      Bluetooth permission
- [x] Pre-release iPad in-place install preserves the complete KartPad
      Application Support/NAND tree byte-for-byte and remains running
- [x] Exact merged-main app 0.3.0 build 11 passes the device-app audit
- [x] Two deterministic IPA packages match byte-for-byte
- [x] Exact IPA provenance, notices, privacy, and signature-residue audit pass
- [x] Hosted IPA and checksum match the local audited artifacts byte-for-byte
- [x] Dereferenced `v0.3.0-preview.4` tag matches the artifact source commit
- [x] Issue #5 receives the bounded external Mii and Wii hardware test request

Published artifact: `v0.3.0-preview.4`, app 0.3.0 build 11, source
`3e43c002d60378bd4975c4637a8e3a149f2d733e`, IPA SHA-256
`6bd4a3bd6a8582dd193093dda7471cecee2cafd7450f51ea59454329a1529b9e`.

## 0.3.0 Preview 5

- [x] Empty signed-container scan falls through directly to the Files picker
- [x] macOS source removes cursor auto-hide and restores the pointer for settings
- [x] Focused import, menu, Mii/Wii, and cursor contracts pass
- [x] Exact app 0.3.0 build 12 passes device build and package audit
- [x] Two deterministic IPA packages match byte-for-byte
- [x] Hosted IPA/checksum match and the downloaded IPA passes a fresh audit
- [x] Issue #1 and Issue #5 receive focused retest instructions

Published artifact: `v0.3.0-preview.5`, app 0.3.0 build 12, source
`8e57ac49c161ff576d6eff198ade2ee9b21f575e`, IPA SHA-256
`9b7b8c586ddd04b639dda5634e72e88dc91ccefb93762f1afde6e8006d274d14`.

## Full engineering-completion gates still open

- [ ] Stable representative performance and frame pacing across supported
      devices and tracks
- [ ] Complete three- and four-player result paths
- [ ] Required long-duration soak coverage
- [ ] Complete touch, motion, controller, audio, thermal, and lifecycle matrix
- [ ] Production Retro WFC and external-client acceptance after service recovery
- [ ] Clean fresh-checkout provisioning across every intended target
- [ ] No remaining P0/P1 defects and complete exact-candidate evidence index
