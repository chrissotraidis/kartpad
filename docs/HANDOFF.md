# KartPad handoff

Use the [maintenance board](MAINTENANCE-BOARD.md) for current ownership,
candidates and next actions. [STATUS.md](STATUS.md) summarizes published
packages and acceptance; [KNOWN-ISSUES.md](KNOWN-ISSUES.md) links investigations.
Do not resume an old preview branch or installation procedure from a dated log.

## Before continuing

1. Fetch current main, inspect the working tree and check active task ownership.
   Preserve unrelated changes; use a separate worktree when another task owns
   the checkout or a running build.
2. Read the [maintenance workflow](MAINTENANCE.md) and the relevant board row.
   Confirm the exact source, package and target device before testing.
3. Pick an unclaimed, bounded next step. Update the board when its state changes
   and link one dated evidence record instead of duplicating the running history.
4. Use the [Android physical handoff](ANDROID-PHYSICAL-HANDOFF.md),
   [iPhone/iPad acceptance](PHYSICAL-ACCEPTANCE.md) or [tvOS test](TVOS-TESTING.md)
   for device work. A successful build or emulator run is not physical acceptance.

## Working boundaries

- Preserve game data, Retro Rewind content, saves, identities and signing state.
  Never uninstall or clear storage merely to make an update install.
- Public Android APKs and older private previews use different signers. Follow
  [installation guidance](INSTALL_ANDROID.md); do not force a signer migration.
- Keep private inputs, generated game code, raw captures, credentials and device
  identifiers out of Git and public reports.
- The scheduled coordinator and its workers **must never upload or publish an
  IPA**, even if it is built and audited. Manual Apple publication has a separate
  owner and explicit release authorization; see [MAINTENANCE.md](MAINTENANCE.md).
- Keep source, build, package, emulator, physical-device and production-online
  results separate. Check free storage before large builds; use at most one
  Simulator and close it after validation.

The ignored local `build/maintenance/CURRENT.md` and `HANDOFF.md` supplement
public records with machine-specific ownership and private artifact paths.
Older development checkpoints remain in the [journal](archive/JOURNAL.md),
[iterations](iterations/) and [dated evidence](artifacts/), with earlier versions
of this handoff available in Git history.
