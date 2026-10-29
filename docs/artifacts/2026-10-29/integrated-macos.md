# Integrated Mac build and bounded gameplay smoke, 2026-10-29

The clean Mac PadMint player check passed, followed by short native Original and Retro Rewind races using an isolated validation copy. This is a prerelease build and smoke result, not a release announcement or full gameplay acceptance.

## Exact build

- KartPad source: clean `c3829dfcf478fec8d57dcb1e63f01f21964d247b`.
- macOS runtime: `926814625140d640f9173272f3f6cf6ef69ddfe7`; staged controller identity, SDL mapping, and both matrix-selector source files matched that pin byte for byte.
- PadMint current main: `d6f0f59e7f9376b0c7c85607301b8ac808485cd0`.
- Ran current-main `scripts/player-check.sh kartpad macos <private-disc> <clean-checkout>` using Apple's `/usr/bin/python3` 3.9.6, an empty PadMint home, freshly downloaded tools, and a fresh source clone. The backend used two jobs and freshly translated the supported Retro Rewind 6.13.4 inputs.
- Player check completed with exit 0 after 863 seconds. The normal package audit and strict deep code-signature verification passed. The app is ARM64, targets macOS 14.0, and retains the existing 0.8.6 metadata; no new tag was created.

Original retained executable SHA-256: `dfc38e7e5174ac88a0eade531397f5f101d8e727859b633e710b8b55c1cdaac5`.

Original personal ZIP SHA-256: `a2e968b5dc88cfe0697cd27a20e6bd03fb8b10e379119bad46837da8e5b6ccbd`.

The package's icon matched the then-tracked `branding/exports/KartPad.icns`. Any subsequent icon-only repack is separate evidence; this original artifact remains unchanged.

## Isolation and observed behavior

The launched copy changed only its bundle identifier to `dev.kartpad.validation.triage20261029` and renewed the ad hoc signature with the same entitlements. Its `__TEXT,__text` SHA-256 exactly matches the original: `6ce393f6b00d31508f3455b47140ea3abbe946ab1453b32b83050f8d080a9406`. A `portable.txt` outside the app routed runtime configuration, NAND, Mii data, caches, and logs into the task's private `UserData`. Separate bundle preferences prevented use of the normal app's preferences. Network and Discord presence were disabled in the private configuration; resolution was 1x.

The runtime reads Retro Rewind's Riivolution save redirect relative to its configured SD tree. Therefore the test used a private APFS clone of this build's freshly extracted pack, rather than shared release inputs. The Retro save was created under that private SD tree.

- Original: created a fresh license with the bundled KartPad Mii; navigated Single Player, Grand Prix, 50cc, Mario, Standard Kart M, automatic drift, Mushroom Cup. Luigi Circuit loaded with the player, kart, course, HUD, and AI visible. Holding Return accelerated the kart from the start through the first item boxes. Pausing and the native Game menu worked.
- Retro Rewind: selected it through the native Game menu, quit, and reopened the same private app. The Retro title and license appeared. Navigated Grand Prix, 150cc, Mario, Standard Kart M, inside transmission, hybrid drift, and the first cup. SNES Mario Circuit 1 loaded with visible track and player; holding Return moved the kart to the first corner. Quit the app and verified no validation executable remained running.
- The checked normal-app preferences, Config.toml, Mii database, and known Original/Retro save paths had identical before/after hashes or remained absent.

The initial native UI connection stalled for about 18 minutes while Original attract mode continued running. Subsequent controls responded normally. Brief race screenshots showed about 60 FPS; menu/loading transitions and tool pauses are present in the logs. This was not a controlled performance test. No lap, cup, online session, controller reconnect, physical Wii Remote, other Mac, or iPad acceptance is claimed.

## Private retention and cleanup

All artifacts remain ignored under `private/triage-20261029/integrated-macos/`: untouched app and ZIP in `original/`; extracted disc and private Retro SD in `inputs/`; isolated app, two race screenshots, saves, and runtime logs in `smoke/`; build/source/pin/status receipts, inventories, signatures/provenance, and personal-state hashes in `receipts/` and `smoke/provenance.json`. A copy of the new validation-only preference domain is retained in the receipts; that separate test domain remains installed.

Copied app, disc, and Retro trees were verified byte for byte before cleanup. After verifying retention and checking for active processes, only the completed player check's disposable `padmint-player-check.g7Tnci/source` directory was removed using `rm -r`. Its original app, game inputs, and evidence were already independently retained. The outer temporary tools/cache and initial smoke copy were left alone. Disk headroom was 38 GiB immediately afterward. No primary project, shared release cache, or personal save was removed.
