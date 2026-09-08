# KartPad release checklist

Use this checklist for each candidate. Published versions and active work live
in [STATUS.md](STATUS.md) and the [maintenance board](MAINTENANCE-BOARD.md).
Completed [release checkpoints through 0.4.11](archive/release-checkpoints-through-0.4.11.md)
are historical evidence, not a checklist for the next build.

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
      [manual Apple ownership is separate](MAINTENANCE.md#platforms-and-build-completion).
- [ ] Download hosted assets anonymously, compare hashes and bytes, and re-audit
      the downloaded package, signature and provenance.
- [ ] Update the README download table, installation guide, status and maintenance
      board together. Keep the README section order and AI disclosure intact;
      put detailed changes in release notes rather than adding release-history sections.

Sustained performance, long soaks, full controller/multiplayer coverage and
production-online acceptance remain governed by the [PRD matrix](PRD.md).
A published preview does not close those rows.
