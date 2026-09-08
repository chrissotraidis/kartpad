# Android physical-device handoff

This runbook is for an explicitly chosen physical test candidate, including
handoff to another machine. Normal APK users should follow
[installation and update safety](INSTALL_ANDROID.md). Select the current
candidate from the [maintenance board](MAINTENANCE-BOARD.md); do not resume the
obsolete Preview 3 branch or use its installer defaults.

## Prepare the handoff

1. Record the exact source commit, APK version name/code, SHA-256, signer,
   package audit and intended test. Fetch that source into a clean separate
   checkout on the testing machine. For rebuilding, use
   [android/README.md](../android/README.md).
2. Obtain the audited APK from its release page or transfer a private candidate
   privately. Verify the digest against its evidence record. Git does not carry
   APKs, game data, generated code, saves or signing material.
3. Confirm the installed app's signer and version. Export each initialized save
   profile and retain owned game inputs. Never uninstall, clear storage or
   downgrade to force installation. A different signer needs a planned migration.
4. Connect exactly one authorized, unlocked physical ARM64 Android device with
   Vulkan and Android 9/API 28 or later. Enable USB debugging for this test,
   disconnect emulators, and allow at least 6 GiB free on `/data`.

Run from the repository root:

```sh
./scripts/check-android-physical-device.sh
```

The read-only preflight rejects emulators, unsupported hardware, low space and
ambiguous targets. Its output redacts the ADB serial. Passing it does not
establish controller, audio, gameplay or performance acceptance.

## Guarded installation and capture

The installer still defaults to the old Preview 3 artifact. **Always supply
all candidate fields explicitly**, replacing the placeholders with the exact
reviewed record. Permit an update only after preserving the installed state:

```sh
KARTPAD_ANDROID_EXPECTED_PREVIEW_SHA256=REVIEWED_APK_SHA256 \
KARTPAD_ANDROID_EXPECTED_VERSION_NAME=REVIEWED_VERSION_NAME \
KARTPAD_ANDROID_EXPECTED_VERSION_CODE=REVIEWED_VERSION_CODE \
KARTPAD_ANDROID_ALLOW_PREVIEW_UPDATE=1 \
  ./scripts/install-android-hardware-preview.sh /absolute/path/to/reviewed.apk
```

The script audits a non-debuggable APK, checks the hash/version, uses only
`adb install -r`, verifies the selector and starts the UID-scoped capture.
For a fresh capture on an already installed reviewed candidate:

```sh
./scripts/capture-android-a2-session.sh start
# Perform the chosen device checks below.
./scripts/capture-android-a2-session.sh summarize
```

The summarizer streams bounded UID-scoped data through a strict sanitizer.
Keep a failed signal result as evidence; do not weaken the checker to obtain a
pass. Audible quality, tactile output and completed gameplay require observations.

## Physical acceptance

Use the matching pinned game/profile and compare against the previous candidate
with the same scene, resolution, controller and charging/thermal conditions.
Record only checks actually performed:

- cold chooser, Original/Retro launch, clean relaunch and retained licenses;
- a completed race, save mutation and restored progress after relaunch;
- touch steering plus A/R/Z, acceleration lock/unlock and layout editing;
- controller connect/disconnect/reconnect, player slots and tactile rumble;
- both landscape directions, cutouts, large text, background/foreground,
  lock/unlock and recovery without stale inputs;
- audible audio, motion steering, frame pacing and thermals after 15/30 minutes;
- matching offline save/rating transfer when it is the candidate's purpose;
- separately scoped online login, race, results and reconnect checks.

Stop at a failure that risks state and preserve the installed app for follow-up.
Report model, OS/API, page size, build/hash, settings, procedure and observations;
never publish device identifiers, private captures or saves. Existing Pixel/Kishi
acceptance is recorded in [STATUS.md](STATUS.md); it does not accept a new build.
