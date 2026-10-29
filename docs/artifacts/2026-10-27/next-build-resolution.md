# Next-build candidate: beta resolution and #522

27 October 2026. Tested locally, then prepared for review in [KartPad #522](https://github.com/chrissotraidis/kartpad/pull/522) and [Android runtime #9](https://github.com/chrissotraidis/wiicompiled/pull/9). No release, tag or upstream merge.

## Source

- Candidate branch: `codex/next-build-resolution`, based on main `5c9af806c02733f238520b405f886ae45b5aa37e`.
- #522 is cherry-picked as `f1682dd5` (original `1a28cabc89152aca2164119ae8e60c2ee810d057`). It rejects Nintendo/Retro WFC names in the experimental private-server setting; those services already have their normal connection paths.
- Android runtime branch: `codex/beta-resolution-resize`, commit `4be10fabb9d978cf908819d4f0516d10c78cdd30`, pushed before the parent PR update so the gitlink is fetchable.
- The reused worktree is `/Users/chrissotraidis/.codex/worktrees/kartpad-release-086`. The dirty primary checkout was left untouched. Both local branches and private build artifacts remain here.

The beta's synthetic resize event previously notified consumers of a new size without queuing render-target recreation. It now calls the existing deferred resize path, just like a native window resize. GPU resources are still recreated at the GX frame boundary. Classic rendering and crash fallback behavior are unchanged.

## Verification

- Full Python suite: 379 tests, 378 passed initially; the sole error was the missing Android NDK in the exact-build-ID symbolization test. After installing the pinned NDK `29.0.14206865`, all four native diagnostic tests passed, including that test.
- New executable regression uses the actual beta resize functions and event handler, with ASan/UBSan. It covers deferred application, duplicate/no-op events, coalescing, and every UI scale from 0.5x through 4x. The released handler fails the framebuffer-size assertion; the corrected handler passes. Added to shared-runtime CI.
- Native private-WFC tests passed with ASan/UBSan. Android subnative-resolution checks and shared-runtime parity checks passed.
- Fresh Classic app, WiiCompiled beta runtime and matching PGO game pack builds passed. Maintained-runtime staging verification confirmed the exact local runtime commit.
- Combined arm64 APK audit passed in release + bundled-game-pack mode. This is a private diagnostic-signed test artifact, not a publishable release package. Repository version remains 0.8.6/build 268; only this APK overrides it to `0.8.6-resolution-test`/269.
- `git diff --check` passed for both repositories.

The legacy `verify-sources.sh` still fails its preexisting reference-pin check: it expects `1912292c804ff9b1b79938de89369ec4496f9fff`, while the reference checkout is `bd219e38a3e9a1a5047ce41d8cd01210bef3af43`. It verified 37 patch hunks before stopping. This was not changed or counted as a pass.

## Emulator checks

Used a fresh Android 36 arm64 Pixel 6 AVD with the combined APK and private test data. No physical device or existing player data was modified.

- Beta loaded and reached an Original Mario Kart Wii Luigi Circuit race.
- Live resolution changes visibly changed image detail at 0.5x and 2x, both in the same game menu and during the same race, without restarting the process. A 4x setting was also exercised in the menu/title flow.
- Backgrounding and resuming returned to the running race.
- Entering `play.rwfc.net` in Experimental Server Settings kept the dialog open with the explanation to use the default connection; no override was saved. Use Default dismissed it.
- After selecting Classic and restarting, Classic loaded successfully to the licence screen, preserved the test licence and retained the 2x setting.

The fresh AVD ran out of storage while duplicating the disc folder during import. Subsequent gameplay checks used preloaded app-private test data; this is not a successful fresh-import test. Emulator FPS is not phone performance evidence. No completed-race, Retro Rewind, online-match, Galaxy S25 crash reproduction, or new Apple UI acceptance is claimed.

## Artifacts and remaining steps

Private artifacts are ignored under `private/next-build-resolution/`, including build logs, runtime/pack outputs, emulator logs and screenshots. APK: `KartPad-resolution-test.apk`.

SHA-256: `efec3ce4829538523e22222ec0077ba1da023db0820077b1e9f758c013166397`.

Before a later authorized release: merge runtime #9 into `kartpad-android` and the combined KartPad #522 into `main`, rebuild the matching game pack (#522 changes the runtime fingerprint), run the normal release checks and PadMint player-check, and obtain physical-device acceptance. Do not reuse build 268's game pack or publish this diagnostic-signed APK. The existing #522 branch now carries the combined candidate; both PRs remain unmerged.
