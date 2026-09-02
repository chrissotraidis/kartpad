# KartPad app icon provenance

## iPhone and iPad K-circuit icon

The current iOS and iPadOS icon is original project artwork selected on
2026-09-01. OpenAI's built-in image-generation tool produced the raster master
at `branding/KartPadIcon-k-circuit-ai.png`; its SHA-256 is
`94f5dc82a3e53bb6dd7d157449b2f2881c1747de23061f8ba6c924a92ab7df01`.

The prompt requested a generic top-down kart on a broad K-shaped circuit,
midnight-navy surroundings, cyan track lighting, and an orange kart. It
expressly excluded text, logos, characters, recognizable Mario Kart vehicles
or items, controllers, Apple branding, watermarks, and trademarked trade dress.

`scripts/generate-ios-icon-assets.sh` deterministically crops and downsamples
the master to the opaque universal 1024×1024 AppIcon asset used by both iOS and
iPadOS. The production PNG's SHA-256 is
`eb2a9f0c4fdfc78d78f9ab6052104c66a9c7a405336cda70e6f6b2dcd78300bd`.
Xcode applies the system-generated dark and tinted treatments from that single
high-resolution icon.

## tvOS Wii banner icon

The tvOS app icon is intentionally the Wii game banner requested for the
Apple TV port. `scripts/generate-tvos-banner-assets.py` reads the private,
user-supplied `opening.bnr` during a local build, decodes its banner logo and
kart artwork, and emits the tvOS `App Icon.brandassets` Small/Large image
stacks plus the Top Shelf image. Xcode compiles those generated assets into
`Assets.car`.

The banner source, extracted game files, and intermediate PNGs stay outside
the repository and are never copied into the app bundle as raw game data.

## Original abstract and macOS icon

The KartPad icon is original project artwork created on 2026-08-28. OpenAI's built-in image-generation tool produced the initial concept at `branding/KartPadIcon-concept-ai.png`; its SHA-256 is `9e0b4a62d1be64e5108b2b5d9fa2a5611683c0709b1d5baf2c8685afd383ed60`.

The prompt requested a generic abstract wheel/track ring, a geometric K-shaped track curve, and forward-motion marks on a midnight background. It expressly excluded Nintendo and Mario Kart logos, characters, karts, game wheels, courses, items, textures, screenshots, checkerboard flags, controllers, Apple branding, watermarks, and trademarked trade dress.

`KartPadIcon.svg` is the editable original master authored for this repository
from that concept. `KartPadIcon-Dark.svg` and `KartPadIcon-Tinted.svg` are its
appearance variants. They remain the source of the current macOS `.icns`, but
are no longer referenced by the iOS/iPadOS AppIcon set.

`branding/exports/KartPad.icns` is the macOS bundle icon generated from the opaque production export. Its ten standard and Retina members validate at 16, 32, 64, 128, 256, 512, and 1024 pixels; its SHA-256 is `2c83d844e0fe895cae99bc4ed8ea976a969b3035833373c39af31247b17ea7b8`.
