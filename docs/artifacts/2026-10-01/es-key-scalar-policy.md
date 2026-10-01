# Wii ES private-key scalar policy: 1 October 2026

## Result and source scope

The existing Wii ES header rejects some noncanonical private scalars that have
a valid nonzero residue. The narrow upstream modulo policy passes standalone
native Crypto++ regressions on macOS ARM64 and an owned Android ARM64 emulator.
This is synthetic identity/certificate/signature evidence, not a reproduced
KartPad login failure or a claim that login is fixed.

The maintained runtime pins examined remain unchanged:

| Runtime | Source pin |
| --- | --- |
| Android | `18685d137e7dcabbe61f5dfa3cda07a384b59713` |
| iOS | `8892a36125681adc8e4e3e6c7d560d83291a84fa` |
| macOS | `fa2f3d393385bc513ecb81ddee5c754c3bccd369` |
| tvOS | `70001a185633e1d5c1797cdae7642e5a58d31b4b` |

Their complete `runtime/include/wii_es_crypto.h` files are byte-identical:
SHA-256 `704ca358cdb49ee83bde931661cc618a80a8fb6ed9c3df4a3ae22973ced88e9a`.
Only an ignored copy of that header was changed for the candidate harness.

[Upstream PR #265](https://github.com/patchzyy/Wiicompiled/pull/265), merged on
29 September, identifies an imported-Wii-key login crash in WiiCompiled.
Its merge commit is
[`6b853ca37144c04239a7c4f2a9c31da525a01399`](https://github.com/patchzyy/Wiicompiled/commit/6b853ca37144c04239a7c4f2a9c31da525a01399).
The candidate copies that `MakePrivateKey` hunk: reduce the unsigned 30-byte
scalar modulo the sect233r1 subgroup order, then reject a zero result. The
candidate header SHA-256 is
`562cbfc3efee7f24894ee6b3fa2953d6682d0a6789d949f1bac16a0c32b17f51`.
This is an existing upstream fix, not a new upstream contribution.

## Actual KartPad caller

`LoadIdentityFromKeysBin` reads the scalar at offset `0x128` in `NAND/keys.bin`.
It rejects an all-zero key and missing identity IDs, but accepts a nonzero raw
scalar such as `n + 1`, where `n` is the curve's subgroup order.
`CurrentIdentity` supplies that loaded identity to the runtime's `/dev/es`
`GETDEVICECERT` (`0x1E`) and `SIGN` (`0x30`) handlers in `nand_isfs.cpp`.
Certificate creation calls `PrivToPub`; signing calls `SignMessage`; both reach
the stricter `MakePrivateKey` policy. This caller exists in all four runtimes.
A save-only import does not contain this identity and is outside this repair.

## Native regression evidence

Each policy executes nine scalar cases using the actual Crypto++ helpers:
`0`, `1`, `2`, `n - 1`, `n`, `n + 1`, `2n`, `2n + 2` and the largest unsigned
30-byte value. The existing header accepts the three canonical nonzero cases.
The candidate additionally accepts the three noncanonical cases with nonzero
residues. Both reject `0`, `n` and `2n`.

| Native execution | Policy | Scalar cases | Accepted / rejected | Certificate checks | Signature groups | Loader checks |
| --- | --- | --- | --- | --- | --- | --- |
| macOS ARM64 | Existing header | 9 | 3 / 6 | 3 | 3 | 9 |
| macOS ARM64 | Proposed modulo header | 9 | 6 / 3 | 6 | 6 | 9 |
| Android ARM64 emulator | Existing header | 9 | 3 / 6 | 3 | 3 | 9 |
| Android ARM64 emulator | Proposed modulo header | 9 | 6 / 3 | 6 | 6 | 9 |

For every accepted scalar, the harness verifies the private exponent and public
key agree with the canonical residue; explicit and synthetically loaded
identities produce equivalent certificate bytes. It verifies a direct ECDSA
signature, rejects an altered message, verifies the AP certificate signature,
and verifies the title signature. Randomized signatures are verified rather
than compared byte-for-byte. These checks do not establish certificate-authority
trust for the deliberately synthetic identities.

The loader fixtures contain only synthetic IDs, keys and signature bytes.
They are written under an explicit scratch-directory argument. The harness
never calls `CurrentIdentity` or discovers an owner's configured NAND. No
console identity, save, game input or owner data was changed or read for these
tests. Zero-residue rejection remains intact; no identity reset or server-state
change is part of the proposal.

## Dependency and execution provenance

Both retained Crypto++ 8.9.0 archives were matched against all 394 current
vendored `.h`/`.cpp` files. Recorded Ninja definitions include
`CRYPTOPP_DISABLE_ASM` and `CRYPTOPP_NO_GLOBAL_BYTE`, preserving header/archive
ABI agreement. Host compilation used Apple Clang 21, macOS ARM64 target 14.0.
Android compilation used NDK `29.0.14206865`, ARM64/API 28, with static libc++;
the ELF dependencies are only Android's `libm`, `libdl` and `libc`.

| Artifact | SHA-256 |
| --- | --- |
| Retained macOS Crypto++ archive | `fa05356d239152d9502a40fe62c16f0d322241c2363b5333c957ad45e550dc39` |
| Retained Android Crypto++ archive | `f1fb2d8d64ec7d96a80c50191919223b790507e090802eaff73e824e53c75689` |
| Android existing-policy harness | `018562b6e78dec2366a30fbdade689b7d6d856b3e3fd8bbf59df9189d54ea1d3` |
| Android proposed-policy harness | `477cb4dea165fa1b0ecee730a2067cb309755503edea788be70cee5f5f273127` |

Private harness sources, fixture files, compile commands, dependency hashes and
execution logs are retained in ignored `work/upstream-cert-20261001/`.
`native-provenance.json` and `native-results.json` record the host runs;
`android-native-provenance.json` records cross-compilation and
`android-native-execution.json` records the later emulator execution. Each
harness compilation reported four existing vendored toml11 deprecation warnings and
no errors. The earlier scalar-policy model and independent OpenSSL public-key
oracle remain separate evidence from these native runs.

The proposed header has not been promoted to a maintained runtime branch or
gitlink. No app or game-pack build was performed for this certificate pass.
iOS/tvOS compilation, physical-device behavior, authentic imported identities,
certificate trust, service login and online race/results/reconnect remain
unverified by these tests. The Android emulator result is standalone helper
execution and does not establish those gates.
