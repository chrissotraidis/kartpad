# Android A4 disc-image, selector, and menu parity

Date: 2026-09-05

## Outcome

The Android launcher presents separate **Mario Kart Wii / Original game** and
**Retro Rewind** choices when both are ready. The in-game three-dot menu can
return to that selector and its **Game Data & Saves** submenu now exposes both
raw Wii disc-image import and extracted-folder import, plus removal, Retro
Rewind, save, and Mii management.

The selector now also follows the iOS first-launch composition: a diagonal
navy/purple/wine background, orange steering mark, centered white title stack,
and equal blue/pink rounded mode cards with leading icons and separate title/
subtitle emphasis. Its content width follows iOS's 320--760 point cap, adapted
to Android density, while Manage Game Data remains a smaller recovery action.

Android can now extract a user-selected RMCP01 revision-zero ISO or WBFS image
through Dolphin DiscIO built from the pinned upstream source. Extraction uses
the system document picker, app-private same-volume staging, validation, and
atomic activation. A failed import leaves the installed game data active.

## Reproducible native boundary

- Dolphin source revision:
  `4f8af23db516d8b6e9cd00e7b261a65b026514a8`
- Clean ARM64/API 28 build: 1,197 of 1,197 steps passed.
- Standalone probe SHA-256:
  `e634a13651cbd832936311d0599ac3b99ecfe0c7eff09ad8b7a050440be9d800`
- Packaged `libkartpad_discio.so` SHA-256:
  `6ff76ef632417f8807095e7c316bb33415a37a97072c1a5bffd5e5563ca66109`
- The staged JNI library contains no `/Users/` build paths.
- The Dolphin patch applies cleanly in dry-run mode.

The JNI bridge accepts a Storage Access Framework file descriptor, exposes it
to DiscIO through `/proc/self/fd`, validates game ID `RMCP01` and disc revision
zero, exports system data and the data directory, and verifies `StaticR.rel`
before the Kotlin storage layer may activate the result. The package audit now
also checks this optional library's AArch64 ABI, 16 KiB load alignment,
dependencies, RELRO, non-executable stack, JNI export, and bounded embedded PEM
allowlist.

## Emulator acceptance

Device: pinned API 36 ARM64 `KartPad_API_36_ARM64` emulator.

- Installed the final dual debug APK with existing private data preserved.
- Visually inspected the final 2400x1080 selector render in the emulator against
  the iOS first-launch layout and source color/spacing constants.
- The launcher hierarchy showed **Mario Kart Wii / Original game** and
  **Retro Rewind / Installed 6.12.5**, with status stating that both were ready.
- **Manage Game Data** showed distinct ISO/WBFS and extracted-folder import
  actions.
- A deliberately empty `KartPad-invalid.iso` selected through Android
  DocumentsUI failed in-product with: `Dolphin could not read the selected ISO
  or WBFS image.` The app stayed alive and no staging residue remained.
- Earlier in the same acceptance sequence, the live three-dot menu exposed
  Switch Game Version, Multiplayer, FPS, Controls, Display, Game Data & Saves,
  and Report a Problem. Its Game Data & Saves submenu exposed disc-image and
  folder import, game-data removal, Retro Rewind, saves, and Miis. Switch Game
  Version returned through confirmation to the two-choice selector.
- The installed `main.dol` remained byte-identical across the invalid import at
  SHA-256 `80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05`.
- The temporary invalid document was removed. No APK, game data, save, Mii,
  screenshot, or log was published.

Final local-only debug APK SHA-256:
`09cdb68124a1e346a003b7c3e42b75b3f6b5f9fa2dcd1a7461500f5e57fd3204`.

## Verification

- Android lint: pass.
- Strict APK/privacy audit: pass.
- Full Python contract suite: 72 passed, 1 skipped.
- Shell syntax, patch dry-run, and whitespace checks: pass.

## Remaining limitation

No owned ISO/WBFS source image was available in the workspace, and the emulator
did not have safe headroom for a second multi-gigabyte extraction beside the
installed data. The native extraction path and rollback behavior are present,
but a positive full-disc import remains a hands-on acceptance row. Tablet and
physical-device touch, multi-controller setup parity, and physical-device
acceptance also remain open.
