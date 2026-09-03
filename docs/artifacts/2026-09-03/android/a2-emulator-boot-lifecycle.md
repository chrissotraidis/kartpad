# Android A2 emulator boot and lifecycle evidence

Date: 2026-09-03

Base checkpoint: `9d057e9` (`codex/android-a2-private-paths`)

Host: Apple Silicon macOS 26.6.2

Target: `KartPad_API_36_ARM64`, Android API 36, `arm64-v8a`, 4,096-byte pages,
gfxstream with host lavapipe

## Falsifiable subgoal

Stage the already validated ignored `RMCP01` DATA directory outside the APK,
boot the complete Original runtime to rendered game content, and keep that
process alive while Android repeatedly destroys and recreates its SDL surface.
This checkpoint does not claim the complete A2 controller/race/save/physical-
device matrix.

## Private input boundary

The ignored `private/self-build/disc` source contained exactly 2,044 files and
the expected RMCP01 disc/revision/Wii headers. Its pinned executables matched:

- `main.dol`: SHA-256
  `80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05`
- `rel/StaticR.rel`: SHA-256
  `16d9d146112541fefea701ecb5bc1a496f9d50e4a752fbb5b6778e7c6399f67d`

The same 2,044-file tree was streamed into
`files/KartPad/GameData` with macOS AppleDouble creation disabled, then
validated again on the device. `files/KartPad/Config.toml` selects the relative
`GameData` path. Neither the game data nor the translated graph is present in
the APK or Git.

## Boot result

The API 36 emulator indexed 2,037 disc files, published 2,068 FST entries,
executed the main-DOL and StaticR constructors, initialized Vulkan/Aurora,
merged the 1,199-row public pipeline seed, and rendered the Original title and
demo race. SDL host playback received non-silent PCM. Keyboard injection also
navigated a separate run through license creation, Single Player, 50cc Grand
Prix, Mario, automatic drift, Mushroom Cup, and into a live Luigi Circuit race.
That keyboard path is diagnostic input, not physical-controller evidence, and
the race was not completed.

The ignored visual evidence is deliberately not committed with copyrighted
game pixels:

- first rendered title: `.android-bootstrap/a2-emulator-game.png`, SHA-256
  `a2d722612e6b2b5cede480c62c90e8a5413baa8d994f02909b0b144d78724b45`
- live Luigi Circuit race: `.android-bootstrap/a2-emulator-live-race.png`,
  SHA-256
  `4b696244dc6ac776a9c93016a3e758a0620f59b29be355d7c0cd7c7bc2ef7a7a`

## Failure-driven lifecycle correction

The first live-race HOME/foreground attempt recreated the SDL surface but then
aborted in `ImGui::Begin` because `g.WithinFrameScope` was false. Aurora's
asynchronous worker can lose its ImGui frame during surface replacement while
the runtime's optimistic `g_auroraFrameActive` flag is still true.

The Android runtime patch now waits for the worker and verifies ImGui's actual
frame scope before either presentation route draws the host overlay or calls
`aurora_end_frame`. A stale frame is dropped and the optimistic flag is cleared
so the next GX command retries frame creation. Both immediate `GXCopyDisp` and
VI-retrace presentation use the same readiness contract.

The final build survived six consecutive HOME/foreground cycles in the title
and demo renderer loop. Each cycle produced `surfaceDestroyed`, `nativePause`,
`surfaceCreated`, and `nativeResume`; PID `6894` remained unchanged. The final
log contained zero `imgui.cpp`, `WithinFrameScope`, or `SIGABRT` matches and
continued reporting game presentation and non-silent audio. The ignored final
screenshot is `.android-bootstrap/a2-resume-final-generation-6.png`, SHA-256
`7b4c8c8f2dcd9ccdb52d68ab8689dce25e2f35b8daf34ae31c6418df53e35775`.

The same final process then used precise keyboard pulses to load the existing
license, navigate to 50cc Mushroom Cup, and enter a live Luigi Circuit race.
Three more HOME/foreground cycles at the live race retained PID `7414`, resumed
the running race, and produced zero assertion matches. The ignored third-
generation race screenshot is
`.android-bootstrap/a2-final-live-race-generation-3.png`, SHA-256
`01823c192ee513a0ddd3ee4836893bf7b2718aa86ac62936e6b87b8721dcdbc5`.

The preserved post-license NAND was also exercised across three consecutive
cold processes. All reached the title path, and the last visibly restored the
existing `KartPad` license rather than presenting an empty license slot. That
ignored screenshot is `.android-bootstrap/a2-saved-license-precise.png`,
SHA-256
`0383cc02f008c105ee75c51c31cc40242cd5f2ab1686aff4966f17d518b6793e`.

## Reproducibility and package audit

- Fresh preparation applied the complete Android patch stack: pass.
- The four lifecycle-modified runtime files from that fresh preparation were
  byte-identical to the tested source: pass.
- Full private Original APK build: pass.
- Strict APK/native/public-asset/private-data audit: pass.
- Final local APK: 103,429,984 bytes, SHA-256
  `5e07a417f5695f0b0eb1a7237deb649fcac0e3bb16f23f0ae092e722f22314c3`.
- Stripped `libmain.so`: 83,533,016 bytes, SHA-256
  `71486d448c0765e916b95c3ca703d1276152357a912ad0d2fd49c673cc98b44a`.
- Lifecycle patch: SHA-256
  `53404197bef0f46441fee67a993a82cdb963dafa03a8eb1bf8657523f41cfdbb`.

No APK or AAB was hosted or published.

## Honest classification

**Pass for first Original emulator rendering, saved-license cold relaunch, and
repeated title/demo plus live-race surface recreation.** A2 remains open. The
emulator uses a software Vulkan path and ran at roughly 10–15 effective FPS, so
it is not performance evidence. Audible quality was not judged. A complete
race, results, post-race save/relaunch, real controller, and physical Android
hardware remain unproven.

One earlier cold process jumped through guest address zero from
`MiiManager::Init`. Its NAND was preserved by in-place rename rather than
deleted, but the exact same RFL database and post-license `rksys.dat` then
passed the three cold launches above. The event is therefore recorded as an
unresolved, non-reproduced timing failure rather than classified as save
corruption or a deterministic relaunch defect.
