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

Android's release includes a companion notices ZIP with these documents and
the license files from its pinned native dependencies. Keep that ZIP with the
APK when redistributing it. Android uses Vulkan through Dawn and AndroidX
WorkManager (Apache-2.0), rather than Apple's Metal/GameController host paths.

| Component | Pin or version | License / role |
|---|---|---|
| [WiiCompiled](https://github.com/patchzyy/Wiicompiled), by [patchzyy](https://github.com/patchzyy) | `1912292c804ff9b1b79938de89369ec4496f9fff` | GPLv3; ahead-of-time translator and runtime, including KartPad modifications |
| Aurora | vendored by the WiiCompiled pin | MIT; GX compatibility and Dawn integration |
| Dawn | Apple: `v20260603.191052`; Android: `dawn-android-20260919.1`, identity `b0fd045b0a694eb07ac3fcf0d741f8697b935856` | Chromium/Dawn upstream terms; Metal and Vulkan WebGPU implementations; Android changes and rebuild recipe are in the source delivery |
| Dolphin | `4f8af23db516d8b6e9cd00e7b261a65b026514a8` | GPL-2.0-or-later aggregate compatible with GPL-3.0; DiscIO and hardware/HLE-derived integration |
| SunPad | `e43f0ea6b797e5110787171957c9dc3c6213269c` | GPL-3.0; Apple touch, menu, and runtime integration reference |
| SDL 3 | `3.4.4` | zlib; platform and runtime support |
| Mbed TLS | `4.1.1` | Apache-2.0 OR GPL-2.0-or-later; Android native TLS primitive |
| Minizip-NG | Dolphin-pinned source | zlib; tvOS Retro Rewind archive extraction |
| WiimotePairPlus | `8e7f9b12db2da520e4f868305c4861cdf58fa15f` | GPL-2.0-or-later; experimental macOS Wii Remote Bluetooth pairing flow derived from Dolphin WiimotePair |
| Abseil, Dear ImGui, fmt, FreeType, libpng, Tracy, xxHash, zstd | exact package-build inputs | Their included upstream license files apply |

The published repository and tag provide KartPad's integration source,
editable maintained source, dependency pins, and build instructions. Runtime
Git submodules pin the maintained fork commits; `dependencies.lock.json` records
the upstream baseline and other fetched dependencies. Separate dependency patches
remain where needed.

The IPAs intentionally contain ahead-of-time translated game logic. These
software licenses do not grant rights in Nintendo-owned game content. This
does not waive GPL obligations for the combined application or for GPL-covered
code included in generated output. See [`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md)
for the game-content boundary and complete Corresponding Source obligations.

The CSNum correction in each maintained runtime branch
(originally `patches/wiicompiled-sc-serial.patch`) is
backported from [patchzyy/Wiicompiled commit e0e362b](https://github.com/patchzyy/Wiicompiled/commit/e0e362bd992e07784f8ce7fa795cdb496af7b075),
by patchzyy, under the upstream GPLv3 license.

## Maintained WiiCompiled source

KartPad's platform runtime source is maintained in the actual
[WiiCompiled fork](https://github.com/chrissotraidis/wiicompiled), derived from
[patchzyy/WiiCompiled](https://github.com/patchzyy/wiicompiled). The pinned
`vendor/runtimes/` submodules preserve the upstream runtime and vendored Aurora
licenses and notices. KartPad's translator changes are maintained in the
`vendor/wiicompiled/` subtree. See [source maintenance](docs/source-maintenance/README.md)
for exact source ownership, upstream identity and contribution workflow.
