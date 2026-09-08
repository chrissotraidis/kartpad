# KartPad portability ledger

Historical host-portability checkpoint: 28 August 2026. Later results are
indexed in [STATUS.md](STATUS.md); the contracts below remain useful for regressions.

## G3 result

The first host boundary compiles and links natively for arm64 macOS. `kartpad_host` exposes only host-neutral C++ types and has separate Darwin/Windows source graphs for monotonic clocks, deadline sleeps, thread names, application directories, and atomic file replacement. The Darwin graph contains no Win32 library or `-march=x86-64` token. Its capability macros select Darwin, arm64, Metal, the base product, macOS, and checked guest memory explicitly.

Command: `./scripts/test-host-portability.sh`

Result: Pass — configure, compile/link, one CTest contract suite, zero failures, plus the forbidden-token graph audit. Evidence manifest: `docs/artifacts/2026-08-28/g3-host-portability-build-manifest.json`.

The unmodified Windows baseline remains isolated at WiiCompiled commit `1912292c804ff9b1b79938de89369ec4496f9fff`, tree `34f9deda094915e12f47316059911b28c6812964`. Its checkout is clean and push-disabled. KartPad's new Windows host-service sources keep the same public contracts, but an actual Windows compile remains a later comparison row and is not claimed here.

## Host contract ownership

| Dependency order | Baseline use | KartPad contract / Apple plan | State / owner |
|---|---|---|---|
| Build flags | Windows/LLVM-MinGW/x86-64 gate; unconditional Win32 libraries | Explicit `MKW_HOST_*`, architecture, renderer, product, Apple-target, and memory switches; generated manifest | G3 Pass — build system |
| Paths/logging/files | Win32 module/path/console/file attributes | `HostPaths`, durable `AtomicWriteFile`; diagnostic sink follows the same platform split | Paths/files Pass; logging integration G6 — platform |
| Clocks/threads | Win32 waitable timers, thread metadata | monotonic nanoseconds, deadline sleep, bounded thread naming | G3 Pass — platform |
| Guest memory | `VirtualAlloc2`, placeholder views, shared mappings, `VirtualProtect`, VEH | checked oracle plus Darwin Mach VM backend | G4 checked path Pass; optimized flat differential pending — memory |
| Scheduler | Windows fibers | explicit cooperative scheduler/state machine with owned guest contexts | G5 Pass — scheduler |
| Renderer/window | Aurora/Dawn Win32 surfaces, D3D/Vulkan defaults | Dawn Metal surface and Retina lifecycle | Metal host adapter smoke Pass; surface/translated bridge G7 — graphics |
| Audio/media | host audio path and Windows media ducking | CoreAudio-compatible narrow output and media/session adapter | CoreAudio init Pass; streaming/quality G8+ — audio |
| Input/raw adapter | SDL plus SetupAPI/WinUSB WUP-028 | SDL/GameController; separate macOS USB adapter backend or explicit limitation | GameController discovery Pass; mappings/devices G8/G10 — input |
| Networking/TLS | WinSock, Windows trust/interface APIs | BSD sockets, Network/Security framework adapters, local-server tests | DNS/loopback TCP Pass; protocol/TLS/external G12 — network |
| Packaging/crash UI | Win32 executable/DLL copying, DbgHelp, Windows dialogs | native app bundle, Apple crash/symbol paths, safe diagnostics | G13 — application |

## Source-complete upstream Windows inventory

Run `./scripts/list-upstream-windows-sources.sh` to reproduce the inventory. Third-party Crypto++ and pugixml matches are not forked here; their upstream platform branches stay dependency-owned and must compile through their public targets.

| Owner / plan | Exact first-party files containing Windows/build-ISA dependencies |
|---|---|
| Build system; capability split | `runtime/CMakeLists.txt`; `runtime/cmake/PublicProducts.cmake`; `aurora-main/CMakeLists.txt`; `aurora-main/extern/CMakeLists.txt`; `aurora-main/cmake/AuroraCopyRuntimeDLLs.cmake`; `AuroraDawnProvider.cmake`; `AuroraNodProvider.cmake`; `AuroraSDL3Provider.cmake`; `aurora_core.cmake` |
| G3/G6 platform/diagnostics | `runtime/src/main.cpp`; `runtime/src/system_bridge.cpp`; `runtime/src/host_cpu_baseline.cpp`; `runtime/src/memory.cpp`; `runtime/src/settings_overlay.cpp`; `runtime/include/runtime_config.h`; `runtime/include/aurora_events.h`; `runtime/src/hle/vi.cpp` |
| G4 memory | `runtime/src/guest_flat_memory.cpp`; `aurora-main/lib/dolphin/os/OSMemory.cpp` |
| G5 scheduler | `runtime/include/fiber_manager.h`; `runtime/src/fiber_manager.cpp`; `aurora-main/lib/dolphin/os/OSTime.cpp` |
| G6/G10 input/media | `runtime/src/wup028_adapter.cpp`; `runtime/src/music_attenuation.cpp` |
| G6/G12 networking | `runtime/include/hle/network_poll_contract.h`; `runtime/include/hle/network_deferred_contract.h`; `runtime/src/hle/net/network_internal.h`; `network_core.cpp`; `network_ssl.cpp` |
| G6/G9 storage | `runtime/src/hle/storage/nand_api.cpp`; `nand_async.cpp`; `nand_fs.cpp`; `nand_internal.h`; `nand_isfs.cpp`; `riivolution.cpp` |
| G6 Aurora/Metal/window | `aurora-main/lib/aurora.cpp`; `internal.hpp`; `logging.cpp`; `system_info.cpp`; `window.cpp`; `card/DolphinCardPath.cpp`; `dawn/BackendBinding.cpp`; `webgpu/gpu.cpp` |

No file in this inventory is treated as fixed merely because a non-Windows branch exists. Each moves to Pass only when its owning goal's contract and immediate Apple test pass.

## G4 memory decision

The checked/table backend is selected for correctness and likely mobile compatibility. It uses sparse owned backings, explicit guest mappings, and shared backing IDs for aliases; it never derives an unchecked host pointer from a guest address. Its full conformance suite passes Release and ASan/UBSan on arm64.

The first Darwin flat candidate was evaluated safely. A 4 GiB-plus-guard reservation at `0x0000100000000000` succeeded with `mach_vm_allocate(..., VM_FLAGS_FIXED)` and was protected/deallocated successfully; a base-relative reservation lifecycle also passed twice. `VM_FLAGS_OVERWRITE` was never used. This proves reservation feasibility only. Flat aliases, page protections, fault classification/resume, and checked differential equivalence remain open optimization work and cannot replace the checked backend yet.

## G5 scheduler decision

The explicit state-machine strategy is selected because translated code can yield at the modeled OS/HLE boundaries. It stores the entire guest CPU snapshot per guest thread and therefore does not depend on Windows fibers, arbitrary host-stack preservation, deprecated Darwin contexts, or unaudited assembly. A scheduler mutex protects metadata but is released around every guest step and callback.

Release and ASan/UBSan suites cover start/yield/sleep/wake/queue/join/cancel/exit, simultaneous alarms, priority order, nested callbacks, VI cadence, repeated lifecycle, idle/deadlock behavior, background suspension, and shutdown from waiting/running states. Two independent million-operation fixtures produced the same state hash with exact distribution and register/FP/SIMD preservation. Wii OS HLE integration continues through G7/G8; physical mobile lifecycle remains G15/G16.

## G6 Apple subsystem smoke

With Metal API Validation enabled, the Apple M2 device/queue completed an offscreen RGBA8 clear and every pixel read back correctly. Apple's default output Audio Unit initialized and reported a valid 48 kHz/eight-channel stream, GameController discovery initialized with a valid zero-device list, durable storage passed, and BSD DNS/loopback TCP exchanged a verified payload. These are native host-adapter smokes only; Dawn/Aurora presentation and translated renderer integration remain G7.

## G6 semantic portability — initial checkpoint

The locked upstream ISA package assumes SSE intrinsics, MXCSR, `__regcall`, and Microsoft force-inline syntax. KartPad now has a standard-C++ semantic layer and a dual-architecture differential harness. Release arm64 and x86_64/Rosetta produce the same 250,155-check raw-result hash, pinned Dolphin's estimate implementation is compiled as the oracle, and an actual translator-emitted integer/scalar/paired/GQR/FPSCR fixture executes through checked memory on both architectures. Stateful edge helpers were still open at this checkpoint. The later completed
G6 result is recorded in [SEMANTICS.md](SEMANTICS.md).

The provisional G7 app proves AppKit/CAMetalLayer presentation from a translated checked-memory command. It intentionally does not claim Dawn, Aurora, GX, or game-frame acceptance.
