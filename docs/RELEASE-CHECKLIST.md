# KartPad release checklist

Use this checklist for each candidate. Published versions and active work live
in [STATUS.md](STATUS.md) and the [maintenance board](MAINTENANCE-BOARD.md).
Completed [release checkpoints through 0.4.11](archive/release-checkpoints-through-0.4.11.md)
are historical evidence, not a checklist for the next build.

## Android APK and PadMint inputs (from 0.7.14)

[AGENTS.md](../AGENTS.md) lists the current six-file delivery set. Android
retains its ready-to-play APK; Apple builds use PadMint. The 0.7.9–0.7.13
ready-to-play Apple downloads are historical, not requirements for new releases.

For each release:

1. Merge the release PR, then confirm `git rev-parse <merge>^{tree}` equals the
   tree you build from. Bump `version.json` (version and build) in the PR.
2. **Android:** `KARTPAD_ANDROID_PACKAGE_FORMAT=aab
   KARTPAD_ANDROID_BUNDLED_GAME_PACK=<pack> scripts/build-android-app.sh
   <absolute output dir>`. Use an absolute output path; a relative one breaks
   the build-provenance step. The pack must match the printed pack fingerprint.
   Then `KARTPAD_ANDROID_ALLOW_GAME_PACK=1 scripts/derive-android-release-apk.sh`
   with the Community Release key, **twice**; both APKs must be byte-identical.
3. **iPhone/iPad:** `scripts/build-ios-app.sh <dir>` gives the game-code-free
   IPA, published as `-ios-for-padmint.ipa`. Audit it without a game pack or
   provisioning profile. For private acceptance, check the personal pack against
   that exact app with `scripts/check-game-pack-state.py`, add it to a private
   copy, and install in place after backing up and reading back player data.
4. **Mac:** verify the changed PadMint/source-build path when affected. There is
   no ready-to-play Mac download from 0.7.14. A recipe path edit alone does not
   prove that a fresh PadMint Mac build or its gameplay works.
5. **Other files:** `padmint.json` as `-padmint.json`; a notices zip with
   `LICENSE`, `LICENSES/`, `RIGHTS_AND_LICENSES.md` and
   `THIRD_PARTY_NOTICES.md`; `scripts/package-release-source.py` with the
   KartPad merge commit and every runtime and translator gitlink;
   `SHA256SUMS` over all of them.
6. **Audits:** `python3 -m padmint audit` (from the PadMint checkout) on every
   file, and the release gate on the folder. The only accepted findings are
   translated game code (address-named symbols and the embedded data-sections
   marker) in the APK, plus the same marker string inside the translator's source file.
   Inspect any source-definition hits against exact tracked source; record
   synthetic test fixtures as reviewed findings, never a blanket audit PASS.
   Any key, disc data or private path is a stop.
7. **Tests:** the final APK installs over the previous release on an emulator
   and reaches a race with data kept; on a fresh emulator it imports an
   extracted folder or its ZIP and reaches a race. Test the final PadMint app
   with its matching private pack on an Apple device, installed in place. Check
   affected Mac behavior separately; do not imply Android/iPad proof covers Mac.
8. Publish with `gh release create --target <full merge SHA>` (a short SHA is
   rejected), then download every file anonymously and check it against
   `SHA256SUMS`, and confirm GitHub reports the new tag as latest.

## Source and scope

- [ ] Record platform, version/build, exact source commit and intended test or
      release purpose. Identify affected platforms and unresolved reports.
- [ ] Review the diff and run checks appropriate to the changed code, including
      regressions for any reproduced defect. Prepare runtime patches afresh.
- [ ] Verify pinned dependencies, Retro Rewind profile and repository safety.
      Preserve existing working trees, user data and signing identities.
- [ ] Review [rights, Corresponding Source and game-content boundaries](../RIGHTS_AND_LICENSES.md)
      and [third-party notices](../THIRD_PARTY_NOTICES.md) for the exact package.

## Build and package

- [ ] Build from the intended clean source and record the artifact identity.
      A source fix does not update an old binary.
- [ ] Run the platform app/package audit, including architecture, minimum OS,
      signatures, resources, notices and provenance. Exclude private data and
      signing material.
- [ ] Package twice and compare bytes where the platform's release workflow
      requires reproducibility; verify the final SHA-256 and version metadata.
- [ ] Confirm the update path preserves data with the existing signer and bundle
      identifier. Do not uninstall a working preview to test a different signer.

Platform procedures: [Android release](RELEASING_ANDROID.md),
[Apple build](BUILDING.md), [Personal IPA Builder](BUILDER.md),
[Mac install](INSTALL_MACOS.md) and [tvOS build/test](TVOS.md).

## Acceptance and publication

- [ ] Record build, package, emulator, physical-device and production-online
      results separately. State precisely which remain pending.
- [ ] Use the [iPhone/iPad](PHYSICAL-ACCEPTANCE.md),
      [Android](ANDROID-PHYSICAL-HANDOFF.md) or [tvOS](TVOS-TESTING.md) device
      procedure as applicable. Verify existing saves after an in-place update.
- [ ] Write versioned release notes with changes, installation, test scope and
      known limits. Use a prerelease for an unaccepted testing candidate.
- [ ] Publish only within the owner's explicit release authorization. The
      scheduled coordinator and its workers **must never publish an IPA**;
      [manual Apple ownership is separate](MAINTENANCE.md#release-gates).
- [ ] Download hosted assets anonymously, compare hashes and bytes, and re-audit
      the downloaded package, signature and provenance.
- [ ] Update the README download table, installation guide, status and maintenance
      board together. Keep the README section order and AI disclosure intact;
      put detailed changes in release notes rather than adding release-history sections.

Sustained performance, long soaks, full controller/multiplayer coverage and
production-online acceptance remain governed by the [PRD matrix](PRD.md).
A published preview does not close those rows.
