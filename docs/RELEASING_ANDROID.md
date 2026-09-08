# Android release maintenance

This is the maintainer's publication checklist, not a restriction on GPL rights.
Normal users should follow [installation](INSTALL_ANDROID.md) or
[source builds](../android/README.md). Never publish a hardware debug-signed APK.

1. Review current main and the Android changes; preserve dirty work and phone
   data. Distinguish current-build physical acceptance from historical evidence and check
   open release blockers. Record limitations instead of declaring the entire
   device/performance matrix passed. Issue #94's console-serial fix is required
   before the first Android release; the pre-fix candidate is not publishable.
2. Merge approved source, run repository/semantic/native/controller tests and
   `scripts/verify-sources.sh`. Rebuild the exact source with fresh prepared
   runtime inputs after any patch change. Never assume an existing prepared
   directory automatically receives new patches.
3. Build the complete dual graph using the instructions in `android/README.md`.
   Choose an explicit version name and forward version code for the candidate;
   record the actual ABI, minimum API, target SDK and non-debuggable status. Retain the unsigned AAB privately and audit it. Do not
   reuse the old candidate if native source changes after testing.
4. Derive the universal APK with `scripts/derive-android-release-apk.sh`, using
   the persistent private release key. The key and password stay outside Git;
   maintain a secure independent backup. Never rotate the key merely to make a
   local build work. A signing change prevents ordinary update-in-place.
5. Verify the single certificate's SHA-256 against the approved release identity,
   verify APK metadata and alignment, and repeat derivation to check identical
   bytes. Use a disposable emulator for fresh public-signature install/chooser/
   import checks. Do not uninstall a user's preview for a release-signature test.
6. On a clean source tree, collect the companion notices/provenance. The Dawn
   release identifies source `13abc3bc8ea2d3c2050f9e77a12d012108ceee24`; fetch only
   its public license and let the packager verify the pinned license hash:

   ```sh
   curl --fail --location \
     https://raw.githubusercontent.com/google/dawn/13abc3bc8ea2d3c2050f9e77a12d012108ceee24/LICENSE \
     -o .android-bootstrap/dependencies/Dawn-13abc3bc-LICENSE.txt
   python3 scripts/package-android-release-notices.py \
     /absolute/path/to/the/audited-release.apk \
     android/app/build/outputs/bundle/release/app-release.aab \
     /absolute/path/to/the/exact/arm64-v8a/cmake-build \
     --certificate-sha256 c1dbe0a0d72d830a5779476b346a750d0a37515adef992cad2f3863058f7f2f2
   ```

   The native-build directory is the Gradle CMake build containing `_deps` for
   the exact runtime source (inspect its `CMakeCache.txt`). Do not substitute
   unrelated license copies. The packager writes the allowlisted notices ZIP
   and checksums beside the APK, not raw logs, generated source or the AAB.
   Inspect `PROVENANCE.json` and every ZIP member before upload. The public
   certificate above is not a private key; never put key material here.
7. Publish only the APK, companion notices ZIP and `SHA256SUMS` at the exact
   audited source tag, with its matching versioned file under `docs/releases/` as release notes.
   Publish unaccepted testing builds as prereleases with `--latest=false`. This Android-only release must not replace the Apple downloads.
   No Google Play, store submission, private game data, translated source or
   signing material is authorized by a successful package audit.
8. Download all assets anonymously to a fresh ignored directory, compare bytes
   and checksums, re-audit the downloaded APK and signature, and inspect hosted
   provenance. Record exact source commit, hashes, bytes, signer and validation
   limits in the public evidence ledger, never the phone's ADB serial.

The first release uses a dedicated RSA-4096 signing identity created locally on
2026-09-07. The maintainer's working Preview 15 uses the old debug identity;
it is deliberately not migrated by deleting app data. Future public releases
must retain the dedicated release identity and increase versionCode.
