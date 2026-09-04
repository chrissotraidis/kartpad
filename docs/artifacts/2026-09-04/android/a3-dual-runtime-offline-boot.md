# Android A3 dual-runtime offline boot

## Falsifiable subgoal

Build the Android app from the complete Original/Retro Rewind translation
graph, select the Retro Rewind profile explicitly, and reach its main menu on
the API 36 ARM64 emulator with networking disabled. Then force-stop and cold
relaunch the same installed app, proving that it selects Retro Rewind again,
does not fall back to Original mode, and preserves the save bytes.

This is an emulator runtime-link and offline-boot gate. It is not a race,
general fresh-NAND setup, touch/controller parity, physical-device acceptance,
or release acceptance.

## Inputs and private-data boundary

- The dual translation graph was regenerated locally from the maintainer's
  authorized private inputs. It contained 29,065 base functions, 29,052 shared
  functions, 13 sensitive base functions, and 3,919 Retro Rewind functions.
- The installed Retro Rewind pack passed the production validator, including
  the pinned `Code.pul` and Riivolution XML hashes.
- The disc tree, installed pack, generated translation, save, logs, screenshots,
  APK, and emulator image remained ignored/private and were not committed or
  published.
- The strict APK audit found only `libSDL3.so`, `libc++_shared.so`, and
  `libmain.so` under `lib/arm64-v8a`; it found no private content or local path
  leakage.

## Failures exposed by the real dual graph

The first Android dual build requested every upstream product and therefore
attempted to link standalone executables that require a desktop `main`. The
Android Gradle build now requests only the product represented by the prepared
graph: `WiiCompiled` for base-only input or `KartPadDual` for a dual graph.

The next build showed that reusing `WiiCompiled`'s precompiled header made the
Android dual product depend on the standalone base executable. `KartPadDual`
now owns its Android precompiled header and is itself the sole shared library
with output name `main`.

The final compile failure came from generated Retro Rewind blob assembly using
the Windows-only `.rdata,"dr"` section spelling. Android preparation now emits
build-directory copies of `.S` inputs with the equivalent ELF
`.rodata,"a",%progbits` section. The private generated input is not mutated.

## Build and package evidence

- A fresh dual runtime preparation completed from the patch stack and emitted
  an Android `KartPadDual` shared product with a private precompiled header.
- The complete Android dual build completed successfully.
- Debug APK size: 119,088,910 bytes.
- Debug APK SHA-256:
  `d1490d5b6d9ed38012a5793e609c6c05dd4d26c1704abad9d6e423cac43867c9`.
- Strict package/privacy audit: pass.
- Android Retro Rewind source contract: pass.
- Generated link contract unit test: pass.
- Shell syntax and repository diff checks: pass.

## Emulator storage control

The preserved emulator initially exposed a 6 GiB data filesystem with roughly
2.3 GiB free. The validated installed pack is about 1.9 GiB and the extracted
disc tree about 2.5 GiB, so they could not coexist. This was a real simulator
capacity failure, not a runtime-profile failure.

After a recoverable copy of the AVD overlay was made, the disposable emulator
data image was expanded and wiped. The fresh guest exposed a 10 GiB filesystem
with about 9 GiB free; after staging the validated pack, disc, configuration,
and APK, about 3.8 GiB remained. The test then ran with airplane mode enabled
and Wi-Fi/mobile data disabled.

## Runtime evidence

The explicit debug route accepted `retro_rewind` only after the production
installed-pack validator passed. Log evidence then showed:

- the requested Retro Rewind profile and a valid installed pack;
- activation of profile `retro_rewind` with one deferred mod registration;
- selection of the `retro_rewind` translated-function profile;
- the canonical Retro Rewind overlay root;
- one active XML patch, 154 mappings, and 4,878 overlay registrations;
- a 2,037-file disc index;
- networking disabled;
- Vulkan presentation and non-silent PCM output;
- no fatal error and no base-profile fallback.

The app reached the branded Retro Rewind title and then the Retro Rewind main
menu. The best ignored evidence screenshots have SHA-256 values
`5cce863792c43de03afcaeab4dd3b7b91f14233adda51da333675daa5c32700a`
and `987d13a1a8e6dd795bfe7e9c0cfc9e9d80649cd6b8ffa4252c9963bb167d0c4d`
for the initial title/menu sequence.

Both Original and Retro Rewind initially displayed the same Wii system-memory
warning on the wiped NAND. That base-mode control isolates the warning from the
Retro Rewind link/profile changes. To continue this bounded runtime test, a
format-valid empty diagnostic `RKSYS` was seeded. It was a test precondition,
not proof that KartPad handles arbitrary fresh-NAND creation. Retro Rewind then
created a real KartPad license and updated the save.

Before and after a force-stop/airplane-mode cold relaunch, the save SHA-256 was
identically
`9c451f517267b800a7100bcf3f7445917ddca2361dc7deb1d184f76086600604`.
The cold process again reached the Retro Rewind main menu with explicit
Retro Rewind selection and no fallback. Its ignored screenshot SHA-256 is
`1c5c5ab4b12be915a53741ce0560dc0c19ab7b6a09398f0cbfd03152eb0e7e7d`.

## Classification

**Pass for linking the complete Android dual product and explicitly booting
the validated Retro Rewind 6.12.5 profile offline through title, license, and
main menu, including a save-preserving cold relaunch.**

Still open: a Retro Rewind race/gameplay proof, production mode chooser,
fresh-NAND creation without a diagnostic seed, touch controls, physical-device
Vulkan/controller acceptance, and release packaging. No APK or AAB was
published.
