# Android preview 2 local candidate

Source `fdda4c1a941a563d130593a00f26f9a02a59b4dd`, clean. Version
0.4.13-android-preview.2 / code 29, ARM64 Android 9 / API 28+, includes the reviewed
alarm guard correction. Unmerged scalar context optimization is excluded.

APK SHA-256 `9e7b7a0942714c7a3c9d75397e71763dc16765b9b1ada0ed8ca3e6a57dcb81ac`,
110351769 bytes. Existing public release signer preserved. Full bundle/lint
build succeeded in 9m 5s; package/signature audits pass and repeat signed
derivation is byte-identical. Prepared/runtime provenance identifies clean
source with 876 runtime and 30030 translation files.

Source verification/safety, 585 translator tests/G6, prepared controller checks,
health/phase checks and alarm regression pass. Frozen source had one stale
metadata-test expectation for the removed APPROVED_MAIN_SHA256 symbol; independent
reviewed test-only repair PR145 verifies the current native map. All 66 contracts
pass in that repair checkout; this does not change frozen candidate identity.

Exact public-signer fresh install, chooser/artwork, validation-off default,
missing-data guard and DocumentsUI picker cancellation pass in a disposable
read-only Android emulator overlay. Seeded Original startup rendered Mario intro
frames with live presentation telemetry and a live process on lavapipe. An initial
SwiftShader attempt stopped at renderer initialization because that backend
exposed only four dynamic storage buffers; the matched preview 1 lavapipe
baseline exposes sixteen. This is bounded startup evidence, not a race or
online test.
No physical Pixel update or backing emulator-data change; no positive full-disc
import, online-freeze acceptance or gameplay improvement claim.

This is a local candidate, not a public download. Existing notices packager
remains pinned to preview 1; preview 2 notices/source/public-download validation
would be required before community distribution. No new IPA was built or
published by the maintenance coordinator.
