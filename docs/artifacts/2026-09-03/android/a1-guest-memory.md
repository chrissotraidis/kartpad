# Android A1 guest-memory alias and protection fixture

## Classification

**Pass for the source-only guest-memory primitive on both pinned ARM64
emulator lanes.** The fixture reserves a dynamic sparse 4 GiB virtual range,
maps two runtime-page-sized spans of the same Android shared-memory object,
verifies deterministic contents through both views, and exercises protection
changes without ever requesting executable memory.

This proves the Android primitives required by the eventual checked/table
guest-memory implementation. It does not yet integrate the production
WiiCompiled memory layer, deliberately fault guarded pages, run translated
code, or establish physical-device behavior. A1 remains in progress.

## Exact checks

1. Read and validate the runtime page size.
2. Create a two-page `ASharedMemory` object and restrict its allowed mappings
   to read/write.
3. Reserve 4,294,967,296 bytes at a kernel-selected address with `PROT_NONE`,
   `MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE`.
4. Replace a centered two-page span with a fixed shared mapping and create a
   second shared mapping at another kernel-selected address.
5. Fill the primary view with a deterministic byte pattern and verify every
   byte through the secondary view.
6. Make the primary read-only, write through the secondary, and verify
   cross-alias visibility.
7. Cycle the primary through `PROT_NONE` and back to read-only, then verify
   that the shared data remains intact.
8. Unmap the alias and complete reservation and close the shared-memory file
   descriptor on every success or failure path.

## Commands and results

```sh
./scripts/run-android-fixture.sh KartPad_API_36_ARM64
./scripts/run-android-fixture.sh KartPad_API_35_PS16K_ARM64
```

| Lane | API | Runtime page | Reservation | Shared span | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| `KartPad_API_36_ARM64` | 36 | 4,096 | 4 GiB | 8,192 bytes | pass |
| `KartPad_API_35_PS16K_ARM64` | 35 | 16,384 | 4 GiB | 32,768 bytes | pass |

Both were wiped cold boots. The combined runner also retained the exact
Vulkan readback, initial surface presentation, background observation, and
post-foreground replacement-surface presentation checks.

The exact local debug APK is 33,540,035 bytes with SHA-256
`b9401bfb23c50a8256d6ef336c99085159d403873cf508a759d389e7f64e0635`.
It passes the inherited SDK, package, ARM64-only native-library, 16 KiB
ZIP/ELF alignment, dependency, RELRO, non-executable-stack, exported-symbol,
permission, and privacy audit. No APK/AAB was hosted or published.

## Next gate

Add explicit orientation/surface-generation observation and bounded repeated
recreation stress, then implement the ELF AArch64 fiber/register scheduler
fixture. Integrate production checked memory only after these source-only A1
primitives remain green together.
