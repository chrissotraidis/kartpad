# Android A6 guarded physical-preview handoff

Date: 2026-09-05

Classification: **Pass for a fail-closed, privacy-safe bridge from the exact
audited preview APK into the existing physical-session capture workflow.** No
physical device was attached, so installation, gameplay, performance, audio,
haptics, controller, and physical acceptance remain unproved.

## Falsifiable subgoal

Make the first phone session a single guarded command that cannot accidentally
install on an emulator, silently replace an unknown KartPad build, clear app
data, downgrade a package, expose the ADB serial, or begin testing with the
wrong preview bytes/version.

## Implementation

`scripts/install-android-hardware-preview.sh [APK]` defaults to the retained
local preview and requires:

- the exact approved APK SHA-256
  `24e977d497d5c587eb79771d09e3176932633fe0671f6e5444ddca335bc8bd92`;
- a successful strict package/privacy audit;
- the existing physical preflight's single authorized non-emulator target,
  API 28+, ARM64, 4/16 KiB page size, and 4 GiB free-space gates;
- explicit `KARTPAD_ANDROID_ALLOW_PREVIEW_UPDATE=1` before replacing any
  different existing KartPad APK;
- ordinary `adb install -r` only—never uninstall, package-data clear, or
  downgrade;
- exact installed `0.4.0-android-preview.1` / version code 6 metadata;
- the visible Original/Retro Rewind selector; and
- successful start of the existing UID-scoped physical capture window.

If the exact preview is already installed, the script pulls only the public
installed base APK into a guarded local temporary directory, verifies its hash,
and skips reinstallation. A different installed package fails closed unless the
tester explicitly opts into an update after preserving any test save. A
signature mismatch still fails without uninstalling the existing app. Raw ADB
failure output, package paths, and target serial are suppressed.

## Negative live result

The only connected target was the canonical Pixel Tablet emulator. The new
installer was invoked against it and rejected it through the physical preflight
before any install:

```text
Android hardware-preview installer emulator rejection passed:
serial_redacted=yes
package_unchanged=yes
```

The installed emulator version remained 5. Source contract checks also reject
the presence of `pm clear`, uninstall, or downgrade behavior and require the
preview digest/version, update opt-in, selector, capture handoff, redacted
output, and guarded temporary cleanup.

No physical device was connected and no phone state changed. No package,
capture, identifier, game data, save, signing material, or private artifact was
committed, uploaded, hosted, or published.

The 104-test Python suite with one intentional skip, focused installer
contract, strict AAB and retained-preview APK audits, pinned-source/input
verification, repository safety, shell syntax/lint, and whitespace checks pass.
