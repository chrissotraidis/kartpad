# KartPad 0.5.1 release package, final (26 September 2026)

## State

All five release assets are packaged and audited in `artifacts/release-051b/` of the release
worktree (ignored by Git). **Not published**: no tag, GitHub release, store upload or README
download change exists. Publication still needs the owner's explicit approval.

## Commits

| Commit | Role |
| --- | --- |
| `de3a99c9054042f07e2840066b1bd06f4012659b` | Compilation source for all three apps (clean tree) |
| `38f4c372c0e858bc49963c92fef8a4b77cb7fe80` | Packaging only: iOS build 85 record, Android code 229 notices constants, Mac 0.5.1/85 constants, source notes, matching tests. Source commit embedded in the IPA |
| `29191278c8c2f2797839e361a4178dcd79831bf6` | Packaging only: binds the Android notices to the source archive hash. Packaging commit embedded in the notices |

Runtime pins at `de3a99c`: Android `ce9e90a`, iOS `cbe43de`, macOS `69cdba9`, tvOS `686a573`.
Every change after `de3a99c` is documentation or an allowlisted packaging script/test; both
`scripts/ios_release.py` and `scripts/package-android-release-notices.py` enforce this. Build
details: [android-release-051.md](android-release-051.md), [macos-051.md](macos-051.md).

## Assets

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `KartPad-v0.5.1-arm64.apk` | 169125606 | `89859d4d08492013fa8a979f9732e8a2a33f883142812770e75f6b956fae4b19` |
| `KartPad-v0.5.1-ios-unsigned.ipa` | 64870553 | `40d529f0a8d7130145d6bfcc4547dec6c64093c15b8bdb1488a5a527b9b72008` |
| `KartPad-v0.5.1-macos-arm64.zip` | 63111483 | `a4348b8df37d9aa8925f86f9f02bc03b0ecd39715da4cf6a2e84660382fad399` |
| `KartPad-v0.5.1-notices.zip` | 96827 | `faedad3effa238b9e900a6e5a5139b4cfc03619ed9a5ec8c5988574e3503b46a` |
| `KartPad-v0.5.1-source.tar.gz` | 362989803 | `9aa1d877cc072fee6302dfb235d9320f9c1ca5860ba8414a8262dd8a4e540e4c` |
| `SHA256SUMS` (covers the five above) | 474 | `c5f35b7b24223d4c8cbf1e5e25ce2c916e485241eaeddaf99f0545eed067cab3` |

The private Android AAB (`673df6a36bf0c63fb4ea443420837a7f05e2c96703ebe0b6e400ee5d632049dd`,
133315804 bytes) and the iOS dSYM are kept locally and are not downloads.

## Identities

- Android: 0.5.1, code 229, arm64-v8a, minSdk 28, targetSdk 36, not debuggable. One v3 signer
  `CN=KartPad Community Release`, certificate SHA-256
  `c1dbe0a0d72d830a5779476b346a750d0a37515adef992cad2f3863058f7f2f2`, the same signer as public v0.5.0.
- iPhone/iPad: 0.5.1, build 85, unsigned, diagnostics NO; executable SHA-256
  `2adc1caf16ffba9628e97868c77b7d2019bc0918fad2d0c2618517ec31a4caf6`; UUID `A68BD70F-325F-3D68-AE98-342EE0731569`.
- Mac: 0.5.1, build 85, arm64, ad-hoc signed; embedded source commit `de3a99c`.
- APK and IPA embed the same clean core source fingerprint: 7397 files,
  `ccadff741e7e594a6c1a71e267f2a7de6ed85627f9e84d9f495ec1794b94dcc8`.

## Package checks

- Android AAB and APK audits passed (expected 0.5.1 / 229, release required); repeated
  derivation gave identical bytes; zipalign passed.
- `package-public-unsigned-ipa.py` and `audit-public-unsigned-ipa.py` passed: app 0.5.1 (85),
  exact build-85 manifest and executable, unsigned input, packaging source `38f4c37`.
- `audit-public-macos.py` from the repository (now carrying 0.5.1 / 85) passed on the Mac ZIP
  with `--source-commit de3a99c` and `KARTPAD_EXPECTED_VERSION=0.5.1 KARTPAD_EXPECTED_BUILD=85`.
  The temporary wrapper `work/macos-051/run_public.py` is no longer needed.
- Core snapshot: `package-release-source.py` at `de3a99c` with all four runtime gitlinks
  (2623 top-level entries; 67673943 bytes; `eac17b319baea45a209d17ada4fe0ab59b205813dceaba3ea75d465c108c34a8`).
- `package-coordinated-source.py` passed. It checked the APK and IPA fingerprints and the Mac ZIP's source commit
  against the snapshot. It retained dependency sources from the public v0.5.0 source archive,
  downloaded anonymously (`70f1672b99d40114807fa36eb7c12f4d161b1d5a65c13636cf2451f7291a3457`).
  The manifest status is `candidate_not_release_approval` and it has 85 members.
- `package-android-release-notices.py` passed. It re-checked the clean tree, the source-archive
  members, the APK and AAB audits, the single signer, the native library hashes, and the APK/AAB
  payload equality. The ZIP holds 30 allowlisted entries and no private paths. Its PROVENANCE.json names
  source `de3a99c`, code 229 and the archive above.
- `shasum -a 256 -c SHA256SUMS` passed for all five assets.
- Tests passed: iOS release provenance, Android public-release/bundle-audit/update-in-place
  contracts, macOS dual-mode contract (16 tests, 8 subtests); debug-label, pipeline-worker and
  shared-runtime parity scripts; `verify-sources.sh` (with `KARTPAD_DISC_PATH` set to the main checkout's
  WBFS, because this worktree's WBFS is a symlink).

## Not done or not verified

- `tests/test_tvos_contract.py::test_release_contracts_cover_ios_and_tvos` fails. It has expected
  `RELEASE_TAG = "v0.4.24-ios.1"` in `scripts/ios_release.py` since the 25 September packaging
  commit `97fe014`, so it fails at `de3a99c` as well; it was left unchanged.
- The disposable-emulator update from public v0.5.0 to code229 kept all 2044 game files. Code229 reached the
  New Licence screen, but no race was played. Public code229, iOS build 85 and Mac build 85 have not had a
  physical-device play session. The owner's iPad acceptance was on private build 84, and the
  Pixel sessions were on private code227/228.
- Publication, anonymous post-publication download and re-audit, README/STATUS updates and reporter
  replies have not been done.
