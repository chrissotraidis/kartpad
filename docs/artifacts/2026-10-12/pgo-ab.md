# PGO A/B on the Android emulator: 12 October 2026

Part of #339. Bench: `tools/android-perf/ab.sh` with `-gpu host`, KartPad
`0.8.0-perf` (runtime `21da321`), AVD `KartPad_API_36_ARM64` on an M3 Max.
Each run cold-boots the emulator, installs the variant over the existing data,
drives Grand Prix race 1 (Luigi Circuit, 12 racers, player idle) and measures
game-thread CPU per frame over 60 s. Load average stayed between 3 and 16.

- **base:** the pack from the 10 October investigation.
- **pgouse:** the same translation built with `-fprofile-instr-use` from one
  Luigi Circuit race (`race.profdata`, 38,570 functions).

| Round | base (ms/frame) | pgouse (ms/frame) |
|---:|---:|---:|
| 1 | 7.80 | 6.02 |
| 2 | 8.01 | 6.81 |
| 3 | 7.99 | 6.96 |
| 4 | 7.73 | 5.82 |
| **Mean** | **7.88** | **6.40 (−19%)** |

User time dominates (kernel 0.12–0.16 ms in every run). All runs held 60 FPS,
so the saving is headroom: on a phone whose game thread is the limit, it would
show up as frame rate.

**Limits:** emulator on desktop cores, not a phone. The profile and the bench
use the same race, so this is an upper bound until a track the profile didn't
see is measured. An attempt on Mario Circuit failed to reach the track: key
events made Android register a controller and the game stopped at the GameCube
rumble prompt. Those runs were discarded.

