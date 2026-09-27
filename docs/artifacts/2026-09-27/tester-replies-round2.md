# Tester replies, 27 September 2026 (post 0.5.3 / 0.5.4)

| Issue | Tester | Evidence | Finding | Action |
| --- | --- | --- | --- | --- |
| #327 | johnpower2006 (iPhone 16) | Reply | Cup-select fix confirmed. New: launch "flickers" and is slow. | Reproduced in iPhone 16 Simulator: iOS showed an empty (white) launch screen, then the game chooser flashed for ~0.25 s even with a saved game choice. Fixed: black `UILaunchScreen` colour and the chooser window stays transparent when a saved choice skips it (`67a8e8d`). Verified by recording three simulator launches before/after; chooser still appears normally with "Ask every time". |
| #104 | Deivmsr (S24 Ultra, Adreno 750) | Screenshot | With "fix invisible characters" (0.5.4) drivers now render but are solid silver/chrome. | Diagnosis: character draws carry two per-vertex texture-matrix indices (logged `tex_mtx_indices=2`), still read through the dynamic `postex_mtx[in_texmtxidx/3]` lookup Adreno 750 mishandles; broken reflection texgen gives the chrome look. Fix: route those through the same constant switch in constant-PNMTX mode (Android runtime `2ff436e`, pin `497f6c7`). Emulator: characters render, no WebGPU errors. Unverified on Adreno. |
| #316 | inkwreck2 (OnePlus 15) | Screenshot | "fix characters and track textures" fixed characters and tracks; ~50 FPS instead of 60. | Expected cost of all-draws repack (plus Fill Screen). Asked which variant holds 60. |
| #215 | jorgedorocoso899-cloud | Reply | Crash was Renderer Validation (0.5.1 bug, fixed in 0.5.2). Suggests a low-detail mode. | Noted as feature idea. |

All replies posted as chrissotraidis. Nothing pushed or published; local test APK `work/android233/KartPad-0.5.5-test-local.apk` and simulator build are unpublished.
