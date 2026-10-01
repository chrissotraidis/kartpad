# PowerVR adapter and device limits, 1 October 2026

Issue: [#304](https://github.com/chrissotraidis/kartpad/issues/304).
Status: corrected dependency and empty Android app validated locally; actual
PowerVR Vulkan execution remains a separate gate; the dependency is hosted and verified.

## Failure and correction

The retained Moto G54 report identifies PowerVR BXM-8-256 rejecting Dawn's
72-component interstage requirement. The earlier local candidate accepted the
64-component Vulkan floor and reported 14 variables, retaining eight reserved
components. That candidate was absent from published KartPad 0.7.3.

A real native consumer exposed a second defect: Dawn's device constructor
reified an omitted or explicit 14-variable request to the Core default of 16.
Adapter rejection alone did not protect shader validation after device creation.
The retained candidate fails with `expected device limit 14, got 16`.

The maintained patch now accepts the 64-component floor only for ImgTec and
clamps the constructed device's interstage limit to its adapter's limit only for
Vulkan on ImgTec. Other vendors and backends keep their existing policy. Higher
ImgTec limits still support normal defaults and valid larger explicit requests.
Existing optional-debug-utils and SwiftShader patches are retained.

## Validation

- Extracted actual Vulkan capability branches pass 264,196 control/candidate
  component pairs, including Core/Compatibility floors, both input/output
  directions, below-floor rejection and non-ImgTec parity.
- A standalone Android consumer links the actual rebuilt Dawn library. Eleven
  native cases pass: omitted/undefined/14 requests, explicit 15/16 rejection,
  tiered limits, vendor/backend guards, defaults and larger supported limits.
  Real WGSL reflection and pipeline validation accept the exact boundary and
  reject both an oversized variable count and an out-of-range sparse location.
- The renderer's actual largest generated shader, with eight texture coordinates
  and two colors, passes pipeline validation on all four successful native
  fixture devices reporting 14. Its SHA-256 is
  `eda6afd7ef1d3fe82bb7736df3dae54c41bcbf57fb8be913cdf0aef221aa23f9`.
- Physical identity/limits are controlled fixtures; device implementations use
  Dawn's unchanged Null backend. These checks prove native limit/reflection
  behavior, not Vulkan driver execution, handset performance or gameplay.
- The full pinned Android Dawn build passes all 1,425 build steps and installation.
  Pinned source dependencies and all three patch applications were checked.
  Independent review confirms source/generated-version/manifest/lock identity
  agreement, complete archive coverage and preservation of existing patches.
- Two package runs produce identical archives. All 78 members are read back;
  77 payloads have size/hash records. Headers, library, notices and 12 recipe/test
  files are included. Private work, generated WGSL and builder paths are absent.
  PadMint 0.2.8's content audit passes with zero address-named game functions.
- The current empty-app builder completes with the corrected archive. The APK
  passes the repository and PadMint audits. Its interface fingerprint remains
  compatible with the existing player pack; the actual shared-state/TLS checker
  passes with the one allowed lookup cache. The app links the locked corrected
  library and contains its raw 20-byte Dawn identity three times; the former
  identity is absent. The unchanged disc importer was
  reused byte for byte from the audited published 0.7.3 APK.
- Both debug and release-style empty APKs build and pass repository/PadMint
  content audits. The release-style APK also passes the compatible-pack state
  check. Only the local test signature is added for emulator installation.
- A fresh owned Android API 36 ARM64 emulator imports the compatible PadMint
  pack through the system file picker and the RVZ-exported game-data folder
  through the directory picker. App-side readback matches all 2,043 exported
  files. The initial smaller partition rejects insufficient space and retains
  the pack; that AVD and the later app data are preserved separately.
- The release-style APK creates a new test license and reaches a 50cc Luigi
  Circuit race. Acceleration, changed steering orientation and pause are visible
  through 3:13 of the race timer. This is a played race segment, not a completed
  race or handset performance result. The emulator reports host Apple M3 Max
  graphics, not an ImgTec device. Direct encrypted-RVZ picker import remains a
  separate gate; this run imports the folder exported from the validated RVZ.
- An apparent title-input failure occurred with both the published 0.7.3 APK and
  the candidate. HLE logs show A delivery. Prior active-page evidence identified
  the opening movie above the title and the long-press gas lock. After a neutral
  restart, three distinct 300 ms presses with 800 ms gaps advance the candidate
  normally. No input rewiring is warranted; the initial failure interpretation
  is withdrawn.
- Existing graphics-startup regression checks pass for all four runtime pins:
  unavailable backends preserve the first adapter error and return a failure;
  the runtime displays that error and exits before installing game callbacks.
  This source/fixture result does not establish every handset's dialog behavior.

## Artifact identities

| Artifact | SHA-256 or Dawn identity |
| --- | --- |
| Patched Dawn source identity | `5b8cc623f665a44645e77fa0a2a730c749333de4` |
| Android dependency archive, 10,790,325 bytes | `804d37929accae440a4a92e10aede9752ea223e4e5bb3227a4d73f308ef24e87` |
| Packaged Dawn static library | `752903e7fb24343db9cf09c70aaf63c2b861b5f85a77c29a2ab60e9556514286` |
| Empty debug APK | `3c9c1c88cfaf8992177d4e1a8ff826813acca773a160217ce248d22b6c53a118` |
| Debug APK runtime library | `e4a58ef7644d600488f7058e44ae8caa485a47c436d33c33cdf08dd5b721c9d5` |
| Empty release-style unsigned APK | `af67912b84ccca1bf30c4da014912fa7c00696a381ddc754742a2042fd2865ae` |
| Release APK runtime library | `ccc8b5a5b4ebfb4c58fda090b703cdf7d00e9ebd087f5e5197cd48a3c6132efa` |

Dawn upstream source is pinned at `13abc3bc8ea2d3c2050f9e77a12d012108ceee24`;
Android NDK is `29.0.14206865`, arm64-v8a/API 28. Apple dependency artifacts and
all maintained runtime/translator gitlinks are unchanged. The local translator
`bltl` experiment is outside this dependency change.

## Reproduction and remaining gates

Use `prototypes/stabilization/build-dawn-android.sh` with the populated pinned
source, verified source archive, host protoc and a fresh output directory.
Package that output with `package-dawn-android.py` and the pinned NDK `llvm-strip`.
The device regression runs as:

```sh
python3 prototypes/stabilization/test_dawn_powervr_device_limits.py \
  PATH_TO_CANDIDATE PATH_TO_TEST_OUTPUT --serial EMULATOR_SERIAL \
  --production-wgsl PATH_TO_PRODUCTION_GENERATED_WGSL
```

`--build-only` cross-compiles without deploying. It installs no app. The fixture
uses native internal APIs, so its compile flags come from that candidate's own
`compile_commands.json` rather than assuming another archive's ABI configuration.

The lock names the hosted dependency candidate
[`dawn-android-20261001.2`](https://github.com/chrissotraidis/wiicompiled/releases/tag/dawn-android-20261001.2).
Anonymous downloads of the archive, manifest and checksum file return HTTP 200.
The downloaded archive matches the exact locked size and SHA-256; all 77 payload
hashes and the separately downloaded manifest match. The normal
`prepare-android-dependencies.sh` consumer then downloads and validates the
hosted archive with an empty Dawn cache. The previous locally seeded cache is
retained separately. The older proposed `20261001.1` archive lacks the device
clamp and must not be substituted. No new public KartPad app is released by this pass.
Keep #304 open until the actual affected PowerVR driver reaches its launch/race
boundary; do not request repeated reporter launches while integration can advance.
