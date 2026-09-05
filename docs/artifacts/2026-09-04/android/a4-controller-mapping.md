# Android A4 controller mapping checkpoint

Date: 2026-09-04

## Scope

This accepts persistent A/B/X/Y/Z controller remapping through the Android UI,
JNI bridge, SDL snapshot, and Classic Controller adapter on the standalone API
36 ARM64 emulator. It does not accept physical controllers, multi-controller
assignment, or complete A4/menu parity.

## Implementation

- `KartPadControllerMapping` stores a validated one-to-one permutation in
  app-private preferences. Assigning an occupied physical button swaps the two
  game assignments; invalid state fails closed to the direct default.
- Controller Button Mapping presents accessible A/B/X/Y/Z rows, physical
  A/B/X/Y/Left Shoulder choices, connected-controller status, Reset to Default,
  and Done.
- JNI publishes the mapping to a lock-free native snapshot. The prepared game
  runtime applies it before `MapGamepadToClassic` without changing D-pad,
  sticks, Start, or direct trigger/right-shoulder behavior.
- Android direct mapping now matches iOS: left shoulder maps to Classic Z,
  left trigger to L, and right shoulder or trigger to R.

## Emulator evidence

- The production launcher visibly offered Mario Kart Wii Original and installed
  Retro Rewind 6.12.5; Retro reached its live title.
- The mapping UI saved A→B and B→A, then showed the same assignments after a
  full process restart.
- An Android InputReader-visible virtual Xbox controller was attached. A bounded
  debug build confirmed both the JNI publisher and game-input consumer saw the
  exact mapping `1,0,2,3,4`.
- With that mapping, a physical A event left the `Press the A Button` Retro title
  unchanged. A separately timed physical B event advanced to Select License.
- The virtual controller was disconnected and Reset to Default restored A→A,
  B→B, X→X, Y→Y, Z→Left Shoulder. Temporary native tracing was removed before
  the clean build.

## Verification

- Exact clean local APK SHA-256:
  `30493adced96cad0edcb9d90354596dc59550be0522735f1356758124cb8686a`.
- Strict Android package/privacy audit: pass.
- Fresh dual runtime preparation: pass; 464 unified-diff hunks across 54 patches
  applied, and the resulting KPAD source matched the rebuilt source byte-for-byte.
- Android/Apple focused source contracts: 19 pass.
- Native Android touch input and host gamepad contracts: pass.
- Android lint, repository safety, pinned source/input verification, unchanged
  SunPad overlay snapshot, and `git diff --check`: pass.

No APK, AAB, game data, save, trace, or screenshot was published.
