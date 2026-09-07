# Third-party notices

KartPad and all its WiiCompiled modifications are licensed under GPLv3,
including the combined application where GPLv3 requires. See the root
[`LICENSE`](LICENSE) and [`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md).
The component notices below preserve upstream licenses and attribution; they
do not limit GPL coverage of the combined work.

KartPad builds from exact dependency revisions recorded in
`dependencies.lock.json`. The public unsigned IPAs include the license and
notice files collected from the exact pinned sources and package build under
`ThirdPartyLicenses/`.

| Component | Pin or version | License / role |
|---|---|---|
| [WiiCompiled](https://github.com/patchzyy/Wiicompiled), by [patchzyy](https://github.com/patchzyy) | `1912292c804ff9b1b79938de89369ec4496f9fff` | GPLv3; ahead-of-time translator and runtime, including KartPad modifications |
| Aurora | vendored by the WiiCompiled pin | MIT; GX compatibility and Dawn integration |
| Dawn | `v20260603.191052` | Chromium/Dawn upstream terms; Metal WebGPU implementation |
| Dolphin | `4f8af23db516d8b6e9cd00e7b261a65b026514a8` | GPL-2.0-or-later aggregate compatible with GPL-3.0; DiscIO and hardware/HLE-derived integration |
| SunPad | `e43f0ea6b797e5110787171957c9dc3c6213269c` | GPL-3.0; Apple touch, menu, and runtime integration reference |
| SDL 3 | `3.4.4` | zlib; platform and runtime support |
| Minizip-NG | Dolphin-pinned source | zlib; tvOS Retro Rewind archive extraction |
| WiimotePairPlus | `8e7f9b12db2da520e4f868305c4861cdf58fa15f` | GPL-2.0-or-later; experimental macOS Wii Remote Bluetooth pairing flow derived from Dolphin WiimotePair |
| Abseil, Dear ImGui, fmt, FreeType, libpng, Tracy, xxHash, zstd | exact package-build inputs | Their included upstream license files apply |

The published repository and tag provide KartPad's integration source,
reversible patches, dependency pins, and build instructions. Pinned upstream
source is fetched by the public Builder from the repositories recorded in
`dependencies.lock.json`.

The IPAs intentionally contain ahead-of-time translated game logic. These
software licenses do not grant rights in Nintendo-owned game content. This
does not waive GPL obligations for the combined application or for GPL-covered
code included in generated output. See [`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md)
for the game-content boundary and complete Corresponding Source obligations.

The CSNum runtime correction in `patches/wiicompiled-sc-serial.patch` is
backported from [patchzyy/Wiicompiled commit e0e362b](https://github.com/patchzyy/Wiicompiled/commit/e0e362bd992e07784f8ce7fa795cdb496af7b075),
by patchzyy, under the upstream GPLv3 license.
