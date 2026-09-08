# KartPad research ledger

## Notion/source baseline

The approved PRD records a favorable but medium-confidence feasibility assessment: WiiCompiled provides a real static-recompilation substrate, while PowerPC floating-point fidelity, Darwin guest memory, portable scheduling, native Metal integration, and online compatibility remain hard evidence gates. The source/self-build and private-data boundary is mandatory.

## Pinned upstream research

WiiCompiled was fetched and verified at commit `1912292c804ff9b1b79938de89369ec4496f9fff` with tree `34f9deda094915e12f47316059911b28c6812964`. That is the source baseline; later implementation and execution results are indexed in [STATUS.md](STATUS.md).

The other required references are pinned in `dependencies.lock.json`: WheelWizard, Retro Rewind Pulsar, the Retro Rewind WFC server and patcher, and Dolphin. Aurora is vendored inside the WiiCompiled tree and declares Dawn build `v20260603.191052`. Verified reference checkouts must be detached, clean, and push-disabled. The server is AGPL-3.0; the patcher offers its custom attribution license or GPL-2.0-or-later; Dolphin requires per-file SPDX review. No default local-testing private key may enter a KartPad artifact or log.

WiiCompiled bundles `projects/mkwii/MAP.txt` in its GPLv3 repository. It is sufficient as a private local translation/symbolization reference at the pin, but independent provenance for republishing the map has not been established; package/repository audits must not copy it into KartPad.

## Direct product reference: SunPad

The user supplied a local SunPad checkout as the authoritative interaction and README reference. Its iOS overlay provides a persistent `•••` menu, multitouch controls, normalized per-device layouts, edit/reset behavior, controller handoff, held-input clearing, settings, data management, diagnostics, and accessibility labels. KartPad now reuses the pinned component directly; see [SunPad provenance](../apple/third_party/sunpad/UPSTREAM.md). Keep the README in the owner-requested order: title, description, fork attribution, badges, screenshots, Important (including AI disclosure), then concise downloads and usage. Detailed setup and evidence belong in the linked guides.

The exact component is `apple/ios/SunPadGameOverlay.mm` plus its delegate contract, settings, input state, and input mixer. The persistent menu button uses the SF Symbol `ellipsis`, a 40-point circular dark material-like treatment, `showsMenuAsPrimaryAction`, and a rebuilt `UIMenu`; its placement remains above controls and inside the safe area. These source details are GPLv3-compatible with KartPad's WiiCompiled-derived GPLv3 distribution requirement.

## Dolphin oracle automation

Dolphin's `InputCommon/ControllerInterface/Pipes` backend is the accepted deterministic automation interface for the G2 oracle. A named file in the isolated user's `Pipes` directory exposes buttons and main/C-stick axes through newline-delimited `PRESS`, `RELEASE`, and `SET` commands. This avoids dependence on physical controllers and on synthesized macOS keyboard events that Dolphin's polled Quartz backend does not observe. The private FIFO, controller mappings, save, NAND, and caches are ignored; only sanitized screenshots and the evidence manifest are published.
