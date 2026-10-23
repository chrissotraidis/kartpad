# Issue #233 S24 renderer follow-up

Date: 12 September 2026 (Japan time)

The reporter supplied a sufficiently specific new renderer case:

- Samsung `SM-S928B`, Android 16/API 36
- KartPad `0.4.16-android.2`, build 65
- Retro Rewind profile, 4x resolution, 16:9 experimental aspect
- Renderer validation off
- Character models show only the front of the face in character selection and
  gameplay; reported every time

This belongs to the existing Android S24/Adreno renderer family, but it is not
treated as proof that every S24 or Adreno device shares one cause. The next
useful test remains the same-device dynamic PNMTX baseline → selected literal
variant → dynamic baseline comparison with correlated draw, binding and shader
records. No APK is ready for this handoff, and no new reporter request is
needed before compatible private delivery exists.

Public intake response: [issue #233 reply](https://github.com/chrissotraidis/kartpad/issues/233#issuecomment-5646551787).
