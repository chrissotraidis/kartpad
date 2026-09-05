# A6 retained game-data runtime-root repair

## Falsifiable subgoal

A validated Original game-data import retained across an Android update must
repair its relative `dvd_root`, launch from an APK derived from the unsigned
release AAB, and leave durable private state unchanged on a repeat run.

## Rejected runs

The first bundle-derived run reached SDL/audio initialization and then crashed
on the SDL thread with `SIGSEGV` at address `0x50`. The retained `GameData`
tree validated, but its existing `Config.toml` had no `dvd_root`; the selector
therefore enabled Original without making the runtime path usable.

After adding runtime-path repair, the next run rendered successfully but the
durable-state gate correctly rejected first-boot creation of the runtime NAND
and video configuration. A repeat then exposed non-idempotent blank-line growth
in `Config.toml`; this was also rejected and fixed.

## Accepted result

The selector now validates retained game data, idempotently ensures
`dvd_root = "GameData"`, and fails closed with a bounded message if that repair
cannot be written. Three consecutive selector launches retained the same
configuration SHA-256:
`188c51fd6aaf0c5f0bf85e8c24e44a8a7a947944f3c0da68d64dc8a5be26dad5`.

The final unsigned AAB audit passed for SHA-256
`25346d13084154ff75e4fdfd70c7a832a55d664a5679bea86900b49ad33f34d1`.
Its bundle-derived universal APK SHA-256 was
`9bd0df67e6bb9e56456732ef1b4b8a2e9f38edf167f1da5757ca9d2d9137c328`.
The API 36 ARM64 gate passed for both universal and four device split APKs:
release non-debuggable, selector visible, Original runtime stable, diverse
rendered frames, consistent split signers, exact native bytes, debug APK
restored, and durable state preserved.

The final exact unpublished dual debug APK SHA-256 is
`1db15ed1033e39f3fef7bced0039320dd57e6cc21edfe1d01e3fea50906a1535`.
It was installed with update-in-place semantics and left on the visible
Original/Retro selector. The repository suite passed 110 tests with one
intentional skip, and strict APK/AAB audits passed.

Private game data, Retro content, saves, and runtime state remained only in the
application sandbox. No APK, AAB, or private artifact was published.

## Classification

**Pass for retained validated Original data-path repair and release-derived
Original runtime/state stability on the API 36 ARM64 emulator.** This is not
physical-device, vendor-Vulkan, thermal, subjective audio/touch, controller, or
online acceptance.
