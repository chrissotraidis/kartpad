# Mods and 120 FPS experiments — 18 November 2026

Status: **paused by Chris, nothing published.** Two Discord requests (Terry): switching to other
Mario Kart Wii mods (Item Fever named), and 120 FPS on Android. Everything below was run on the
Mac (M3 Max) and the Android emulator; no phone ran any of it.

## 120 FPS (frame interpolation)

The Android runtime already contains the Mac's frame interpolation
(`aurora_set_frame_interpolation_fps`, targets 0/120/180/240). Draft PR
[#581](https://github.com/chrissotraidis/kartpad/pull/581) adds one Android switch,
**⋯ → Graphics & Performance → 120 FPS Races (Experimental)**, off by default, live on both engines.

| Run | Result |
| --- | --- |
| Emulator (API 36, arm64, on an M3 Max), Luigi Circuit, Classic, off | 60 FPS, p95 17.8–18.2 ms, app CPU avg ~72% of a core |
| Same, switch on | 114–120 FPS presented, p95 10.3–11.9 ms, app CPU avg ~124% (≈1.7×) |
| Frame worker encode per frame | 4.5 ms off → 10.6 ms on (budget at 120 FPS is 8.3 ms) |
| Mac, existing **Frame interpolation: 120**, windowed, window behind other apps | Counter stayed at 60, frame times uneven (p50 14.3 / p95 27.5 ms vs 16.7 steady off); same set live or from launch. Cause not established — possibly macOS holding a background window at 60 Hz |

**Conclusion so far:** works mechanically on Android, roughly doubles frame-worker load, so it is for
fast phones only and would hurt the slow-phone majority (#554, #576, #510).

**Next step:** one run on a real 120 Hz phone (Chris's Pixel 9 Pro XL). Blocker: the debug APK has the
same package name as the release app, so installing it means uninstalling the release app and its
data; either add a debug `applicationIdSuffix` for side-by-side installs, or ask Chris first. Also
re-run the Mac test with the window in front / fullscreen.

## Mods

KartPad's runtime already has a Riivolution file-overlay loader (`[paths] overlay_roots` in
Config.toml; each root holds `riivolution/*.xml`) and Dolphin-style `texture_replacements`. Neither
has app UI. Riivolution `<memory>` (code) patches are parsed and deliberately never applied.

| Mod (GameBanana) | Kind | Result on the Mac |
| --- | --- | --- |
| Sonic over Luigi (388483) | Character files | Works via a small Riivolution XML mapping `Race/Kart`: Sonic races in Luigi's place at 60 FPS. Menu models need their own mapping (the mod ships them under `Scene (…)` variant folders) |
| MK Double Dash Menu, PAL (373902) | UI `.szs` files | Works via `Scene/UI` mapping: blue star menus and Double Dash race HUD |
| Item Fever 1.1.2 (731930) | **Pulsar code mod** (Loader.pul + Code.pul via memory patches) + files | Loaded as files only: **crashes** once menus load (guest access to 0x524D4380, "memory access out of bounds"). The 8 memory patches are silently dropped |

**Item Fever through the translator (the Retro Rewind path):** Item Fever is built on Pulsar, the same
engine as Retro Rewind, and KartPad's translator handles Pulsar `Code.pul` as a generic Kamek module.

- Against Retro Rewind's base translation, `translate-mod` refuses: Item Fever patches 1,037 game
  functions vs RR's 1,153, so it needs its own mod-aware base.
- With an Item Fever–aware base: `translate-recursive` 29 s, `translate-mod` 9 s, **4,431 functions
  emitted, 0 translation failures**, 12,191 module patches, 125 data patches. The only 2 lost hooks
  (strap-screen skip, NAND open) are the same 2 Retro Rewind loses to native KartPad code.
- A full Mac app with Item Fever in the "Retro Rewind" slot then **translated (all script guards
  passed, 55 s) and compiled** (11 min). **It has not been run yet.**

**Where it stopped:** the Mac app validates the Retro Rewind folder against Retro Rewind's own Code.pul
and XML hashes (`ValidateRetroRewindRoot`, `KARTPAD_RR_*` in
`kartpad_retro_rewind_release.h`), so it won't open the Item Fever folder in that slot.

**Next step:** in the private build, point those `KARTPAD_RR_*` defines at Item Fever's `Code.pul` and
`riivolution/ItemFever.xml` (sizes and SHA-256), rebuild the Mac app, set
`retro_rewind_root` to the Item Fever folder, choose **Game → Retro Rewind**, and race to see the new
items. If that works, Item Fever is feasible as a second translated mod slot, with the same
per-version upkeep as Retro Rewind. Scope decision (someone else's mod, offline only) stays Chris's,
as in #534.

## Recommendations (pending Chris)

1. **File-only mod manager** (Sonic/menu class): feasible on top of the existing loader; needs UI to
   install, enable and order mods, a generated Riivolution XML, and `_U`→`_E` handling. DriftDroid
   shipped this (GameBanana browser). It should **refuse packs with `<memory>`/`.pul` code** with a
   clear message instead of crashing like Item Fever did.
2. **Code mods (Item Fever):** possible only as a translated slot like Retro Rewind; finish the run
   above before deciding.
3. **120 FPS:** keep #581 as a draft until a 120 Hz phone result.

## Private material (not in Git)

`/Users/chrissotraidis/.codex/worktrees/kartpad-weekend-0811/private/experiments-1118/` (~28 GB):
`mods/` (downloads), `overlay/` (Sonic + DD test root), `if-build/out/KartPad.app` (Item Fever Mac
build, not run), `tmp/padmint-player-check.*/source` (private build tree with the Item Fever
translation; ~26 GB, regenerable in ~15 min), `mac-logs/` (incl. the Item Fever file-only crash),
and the scripts `mac-run.sh`, `measure.sh`, `translate-itemfever-full.sh`, `build-itemfever.sh`.
Chris's Mac App Support folder was backed up before each run and restored byte-for-byte after.
