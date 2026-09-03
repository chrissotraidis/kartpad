# Android A1 ELF AArch64 scheduler and register stress

## Classification

**Pass, completing A1 on both pinned ARM64 emulator lanes.** Each cold-boot
run executes two million portable scheduler operations with the accepted
deterministic hash and one million real ELF AArch64 fiber switches with exact
callee-saved register checks.

This is source-only emulator evidence. It does not yet link the complete
private WiiCompiled runtime, run translated game code, establish physical
vendor-driver behavior, or make performance claims.

## Scheduler semantics

The Android library compiles the shared
`runtime/src/scheduler/guest_scheduler.cpp` implementation rather than a
parallel Kotlin or Android-only scheduler. Its fixture requires:

- suspended create followed by resume/start;
- yield followed by exit and exact exit code;
- logical sleep, idle alarm advancement, and wake;
- wait-for-thread, target completion, and join wake;
- cancellation and terminal cancelled state;
- two independent 1,000,000-operation, four-thread round-robin runs;
- exact 250,000-operation distribution per thread and 10,000 VI retraces;
- unchanged GPR, FPR including NaN bits, SIMD, and FPSCR fixture state; and
- deterministic state hash `0x7287563387fb1677` on both runs.

## ELF fiber contract

`fiber_switch_android.S` uses ELF symbols and AAPCS64. Its 192-byte context
saves/restores x19–x28, x29, x30, SP, d8–d15, FPCR, and FPSR. A dedicated
assembly fiber starts on an aligned 64 KiB stack, checks seeded x19–x29 and
d8–d15 values plus FPCR/FPSR around every yield, and relies on exact x30/SP
restoration to resume its loop. It completes 1,000,000 switches and returns to
the host context only through the switch primitive.

## Commands and result

```sh
./scripts/run-android-fixture.sh KartPad_API_36_ARM64
./scripts/run-android-fixture.sh KartPad_API_35_PS16K_ARM64
```

| Lane | Page size | Scheduler operations | State hash | ELF switches | Result |
| --- | ---: | ---: | --- | ---: | --- |
| `KartPad_API_36_ARM64` | 4,096 | 2,000,000 | `0x7287563387fb1677` twice | 1,000,000 | pass |
| `KartPad_API_35_PS16K_ARM64` | 16,384 | 2,000,000 | `0x7287563387fb1677` twice | 1,000,000 | pass |

The exact local debug APK is 33,673,035 bytes with SHA-256
`0846efc7058a5cae61ace508c9bdddd3b214c826275925164c148ba1e8b511b0`.
It retains the package's ARM64-only, 16 KiB alignment, RELRO,
non-executable-stack, exported-symbol, permission, and privacy properties. The
runner also rejects any error-level fixture line after all positive markers.
No APK/AAB was hosted or published.

## A1 closure and next gate

Together with the renderer, lifecycle, and guest-memory evidence in this
directory, this satisfies A1's source-only acceptance criteria on both
emulator page sizes. A2 is the lowest incomplete goal: prepare/link the
ignored private generated Original-mode graph and prove controller-driven
gameplay, while reserving physical Vulkan/controller authority for hardware.
