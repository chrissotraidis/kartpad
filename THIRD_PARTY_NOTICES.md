# Third-party notices

KartPad builds from exact dependency revisions recorded in
`dependencies.lock.json`. The public unsigned IPAs include the license and
notice files collected from the exact pinned sources and package build under
`ThirdPartyLicenses/`.

| Component | Pin or version | License / role |
|---|---|---|
| WiiCompiled | `1912292c804ff9b1b79938de89369ec4496f9fff` | GPL-3.0; ahead-of-time translator and runtime |
| Aurora | vendored by the WiiCompiled pin | MIT; GX compatibility and Dawn integration |
| Dawn | `v20260603.191052` | Chromium/Dawn upstream terms; Metal WebGPU implementation |
| Dolphin | `4f8af23db516d8b6e9cd00e7b261a65b026514a8` | GPL-2.0-or-later aggregate compatible with GPL-3.0; DiscIO and hardware/HLE-derived integration |
| SunPad | `e43f0ea6b797e5110787171957c9dc3c6213269c` | GPL-3.0; Apple touch, menu, and runtime integration reference |
| SDL 3 | `3.4.4` | zlib; platform and runtime support |
| Mbed TLS | `4.1.1` | Apache-2.0 OR GPL-2.0-or-later; Android native TLS primitive |
| Minizip-NG | Dolphin-pinned source | zlib; tvOS Retro Rewind archive extraction |
| WiimotePairPlus | `8e7f9b12db2da520e4f868305c4861cdf58fa15f` | GPL-2.0-or-later; experimental macOS Wii Remote Bluetooth pairing flow derived from Dolphin WiimotePair |
| Abseil, Dear ImGui, fmt, FreeType, libpng, Tracy, xxHash, zstd | exact package-build inputs | Their included upstream license files apply |

The published repository and tag provide KartPad's integration source,
reversible patches, dependency pins, and build instructions. Pinned upstream
source is fetched by the public Builder from the repositories recorded in
`dependencies.lock.json`.

The IPAs intentionally contain ahead-of-time translated game logic. That logic
is not claimed to be covered by the open-source licenses listed above. See
`RIGHTS_AND_LICENSES.md` for the separate community-release boundary.
