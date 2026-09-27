# Morning handoff, 28 September 2026

Worktree `/Users/chrissotraidis/.codex/worktrees/kartpad-release-051-20260925`, branch `codex/release-053`.
Everything below is committed locally only. Nothing is pushed or published.

Heads at the time of writing:

```
d8916d8c Overnight record: #101 HUD measurement
android 35257c4 
ios 4ef1b9f 
macos 11735a3 
tvos d83c777
```

Detailed evidence for each item is in `docs/artifacts/2026-09-27/overnight-loop.md`.

## Changes waiting for a release (since 0.5.4)

| Change | Platforms | Issue | Verified on | Needs |
| --- | --- | --- | --- | --- |
| Drop retrace backlog > 3 s (game ran too fast after background) | all | #330 | host test; iPhone sim 30 s pause; Android emulator log shows one `dropped 76190 ms` after Home, no repeats during slow play | Pixel: Home 60 s mid-race |
| Crash prompt after unexpected exit; export works with no session | Android | log collection | emulator `am crash` → prompt → ZIP → GitHub | Pixel |
| Automatic uses character repack (mode 1) on Adreno 8xx | Android | #102 | emulator; tester evidence | Z Fold 8 / OnePlus 15 |
| Accept PowerVR 64-component floor (Dawn patch) | Android | #304 | emulator forced floor: `maxInterStageShaderVariables: 14`, races | real PowerVR; needs new Dawn package + lock |
| (reverted) lighter prewarm under 6 GB: #135 report showed warm-up already skipped; A10X course select is GPU-bound | — | #135 | — | build 60 vs 87 GPU comparison |
| #193 skipped-recipe logging, inter-stage limit log | Android | #193, #304 | emulator | — |
| Black iOS launch screen, no chooser flash | iOS | #327 | sim | iPad |
| Repack copy fast path | Android | #316 | host tests | — |
| Plainer log steps in bug form and SUPPORT.md | docs | — | — | push |
| Simulator-only scripted pad input | iOS sim | testing | sim | — |

Host graphics tests: 241 pass, same 4 old failures as the baseline.

## Physical-device checks

1. **Pixel** (install `work/android238/kartpad-238.apk` in place, release signer `c1dbe0a0…`):
   - Race, Home for 60 s, return: timer runs at normal speed; log has `[vi] dropped … retrace backlog`.
   - `adb shell am crash <game pid>` then reopen: prompt → save ZIP → GitHub draft.
   - Original and Retro race, one online race; Help shows "Automatic (recommended)";
     log shows `repack mode=off source=auto`.
   - Leave a menu idle for 5 min (#301 idle freeze); it should keep animating.
   - Make sure `debug.kartpad.dawn_interstage_floor` is unset on the phone (it is only a test hook).
2. **iPad** (device build `build/ios88/xcode/Release-iphoneos/KartPad.app`, built 01:00 from `d5a01c93`,
   clean source, diagnostics NO; contains the #330 change and the since-reverted under-6 GB prewarm change (inactive on 6 GB+ iPads), no simulator input hook. Its Info.plist
   still says 0.5.1 / 72 (placeholder from PublicProducts.cmake; the release scripts stamp the real number),
   so treat it as a test build only. Unsigned; sign and install in place with backup/readback):
   - Race, Home 60 s, return: normal speed.
   - Cup select stays 60 FPS (#327); launch shows black, no chooser flash.
   - Log shows `Pipeline prewarm plan: retain 512, warm-up pass …` (8 GB+ iPad).

## Waiting on testers

- #304 Moto G54 (PowerVR), #193 S24 Ultra, #102 Retro on Z Fold 8, #135 A10X, #301 Moto G85 option 1,
  #313 Honor X7c on 0.5.4, #196 Retro online details, #310 lobby crash report.

## Decisions for Chris

- Release 0.5.5 (Android) and a matching iOS/Mac build with the changes above.
- The PowerVR fix changes the pinned Android Dawn package: publish `work/dawn-imgtec/dawn-android-imgtec.tar.gz`
  (sha `014027e7…`) as a new release asset and update `dependencies.lock.json`.
- Push the local runtime commits (Android, iOS, macOS, tvOS) before any release.

