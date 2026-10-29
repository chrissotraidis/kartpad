# WiiCompiled fixes through v0.9.0 — 24 October 2026

KartPad's translator and runtime forks were behind upstream WiiCompiled v0.9.0
(`ac99413`, 23 October): Android, iOS and the translator by 23 commits from
`bd219e3`, macOS and tvOS by 49 from `8346376`. Following
step 5 of the [update loop](../../UPSTREAM_UPDATES.md#update-loop), each fork received
the reviewed upstream fixes rather than a wholesale merge.

| Fork branch (chrissotraidis/wiicompiled) | Commit |
| --- | --- |
| `codex/wc-090-ports-android` | `38829c39` |
| `codex/wc-090-ports-ios` | `4870515a` |
| `codex/wc-090-ports-macos` | `f646cae3` |
| `codex/wc-090-ports-tvos` | `0843bf4d` |
| `codex/wc-090-ports-translator` | `0dce4142` |

The reference pin in `dependencies.lock.json` moves to `ac99413`. Its PAL
function map and every licence file the packagers copy are unchanged; the new
`aurora-main` submodule (patchzyy/aurora-wiicompiled `dd399416`, 3.5 MB, no
nested submodules) is fetched by setup's recursive submodule step.

## Ported

All four runtimes unless noted:

- `9058913` the game's clock starts at the real local date instead of 1 January 2000
  (save and ghost timestamps).
- `a93eaf5` Sky Station crash: unsourced konst colour/alpha selectors read as zero.
- `c255df5` surface release waits for GPU idle, so the retired swapchain is freed safely.
- `8676d1a` controller port identity scores path and slot as well as GUID, and
  upgrades saved v2 preferences. On Android it feeds KartPad's reserved and
  free-port assignment (#378's rule still holds).
- `2ee48fc` Wii Remote rumble through the controller motor (iOS, macOS, tvOS;
  Android already had its own).
- `6b4de9f` WPADGetDataFormat reports the attached extension's format.
- `95a49f3` (fix 280) settings writes edit the TOML document instead of lines.
- Wii Remote input: EEPROM accelerometer calibration (`b87186c`, `60197f2`),
  per-remote calibration (`d529677`), soft-drift (`d7b6436`), missed shakes (`4f166e1`).
- aurora-wiicompiled `998c456`: XF matrix memory is written word by word, so
  matrix loads that start inside a matrix or cross matrices are kept instead of
  rejected. Adapted to KartPad's Aurora (`command_processor.cpp`).
- macOS and tvOS only, from the older range: Wii certificates (`6b853ca`) and
  the parts of `85f2501` they lacked (port index sync through Aurora, mapping
  platform). The display-list staging fix (`196b485`) and the THP path fix
  (`77a8623`) were already present.
- Translator: fix 279 (`ed6fea0`, conditional calls treated as calls) and
  `29155ee` (only relocated module pointers are trusted as Kamek code). The
  base translation is byte-identical (29,637 functions); Retro Rewind drops 21
  dynamic `rr_kamek_*` entries that were data words (several at consecutive
  4-byte addresses), so `expectedRetroFunctions` is now 4,139.

## Not ported, and why

- `efedf42` reorganises the guest-ABI headers for upstream's prebuilt
  Windows/Linux runtime. Translated code inlines these headers; KartPad's
  Android/iOS versions carry the 16 KiB-page and flat-memory changes. No
  behaviour change for KartPad's platforms.
- v0.9.0's Aurora base swap to aurora-wiicompiled (655 commits, including a new
  render worker). KartPad's forks keep their maintained Aurora with about 100
  platform patches. Android adds the new layer beside it as a choice
  ([record](aurora-wiicompiled-layer.md)); Apple platforms keep the classic
  layer for now. Its fog `fsel` fix was already in every fork.
- Launcher, packaging and version-only commits; `3ff1473` (Linux Wii mappings);
  `0b12fc8` (upstream setup version in logs).
- macOS/tvOS: `9d182f8` (PSQ fallbacks moved to a new file; this fork's CMake
  diverges), `6fa2473` (the macOS VM backend KartPad does not compile),
  `b59e035`, `e409d9f`, `a9c9c0d`, `e164af9` and upstream's merge of
  KartPad's own fixes (`6f14bde`), which overlap code these forks already rewrote.

## Checks

Translator: 696 tests. KartPad: full suite (378) with Apple's Python 3.9,
including the Android routing probes under ASan/UBSan against the merged
identity code. Build, emulator and player-check results are recorded in the
0.8.6 release notes.
