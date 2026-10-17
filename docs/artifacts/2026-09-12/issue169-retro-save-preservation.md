# Retro save preservation correction — issue #169

## Source finding

Android stores the Retro WFC saves at
`KartPad/RetroRewind/riivolution/save/RetroWFC/RMCP/rksys.dat` and
`.../RetroWFC2/RMCP/rksys.dat`. Retro pack activation replaces the entire
`KartPad/RetroRewind` directory and deletes the rollback after activation. That
replacement boundary could therefore remove both user save branches even when
the pack import itself succeeds.

## Correction

Before the directory swap, the installer now copies the existing
`riivolution/save` subtree into the validated staging tree. The copy is
payload-preserving, rejects symlinks/non-regular save entries, and leaves the
old installed tree untouched if copying or activation fails. The new pack still
replaces its code/content; only user save files are carried forward.

## Verification

- `scripts/test-android-retro-rewind-storage.sh`: passed.
- The fixture covers both `RetroWFC` and `RetroWFC2`, a staged pack file, and
  replacement of a pack-provided default save.
- Focused Python maintenance/save/compatibility suite: 74 passed.

## Remaining acceptance

This is source-corrected, not reporter-confirmed. Issue #169 was reported on
Android build 21 and still lacks the exact exit-versus-pack-replacement
boundary. The next acceptance must use a current candidate and preserved user
data, then verify both Retro save branches across the exact replacement and
relaunch path. Do not deliberately discard progress or publish from this
fixture result.

Public support update: [issue #169 comment](https://github.com/chrissotraidis/kartpad/issues/169#issuecomment-5644596717).
