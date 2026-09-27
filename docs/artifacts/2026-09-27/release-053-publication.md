# KartPad 0.5.3 publication record (27 September 2026)

- Release: https://github.com/chrissotraidis/kartpad/releases/tag/v0.5.3 (Latest, by chrissotraidis).
- Compiled from `838214b`; runtimes Android `8deed05`, iOS `3a688ad`, macOS `e481a03`, tvOS `686a573`.
- Android 0.5.3 code 231 (signer `c1dbe0a0…`), iPhone/iPad 0.5.3 build 87 (diagnostics NO), Mac 0.5.3 build 86.
- All three assets downloaded anonymously and matched SHA256SUMS; APK signer rechecked; Mac ZIP audit passed.

## Cup-select fix evidence (#327)

Apple hosts use 16 KiB pages, so the runtime runs in checked-access mode, where every paired-single
float load/store went straight to `Read64Slow`/`Write64Slow` (deferred-read mutex on every access).
The THP course-preview decoder uses those constantly. A Mac profile at Select Cup showed about 1.3 s of
every 6 s in that path. With the loads/stores routed through `Memory::Read64`/`Write64` (page-table
fast path first), a local Mac test build driven through the same menu presses measured Select Cup at
29–30 FPS before and a steady 60 FPS after. An earlier scheduler-preemption idea was tested and
dropped: the decoder runs with interrupts disabled, so a preemption point never fires.

## Android checks

- 0.5.3 installed over 0.5.2 on an emulator with game data kept ("Ready to play").
- The new all-draws repack option logged `mode=all_draws` with repacked pipelines active and raced
  on Luigi Circuit with correct rendering and no graphics errors (SwiftShader, not Adreno).

## Not verified

- No physical iPhone/iPad/Snapdragon run of 0.5.3; Joy-Con change untested with hardware.
- The all-draws option is unconfirmed on an Adreno 840 phone.

## Replies after publication

#327, #324, #102, #316, #308, #137.
