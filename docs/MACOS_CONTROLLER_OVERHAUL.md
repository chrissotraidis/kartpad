# macOS controller improvements

This document describes the macOS controller and settings implementation.

## Run the current build

From a checkout of this repository, build the app and then run:

```sh
open "$PWD/build/KartPad.app"
```

The build uses the supported game-data and profile configuration already
selected on the machine. It does not include game data, extracted assets,
saves or signing material; provide your own supported PAL `RMCP01` revision 0
data as described in the normal macOS installation documentation.

Open **Controls → Controller Settings** (also accessible from KartPad Settings).
The device selector always includes **Keyboard** alongside connected physical
controllers. Select Keyboard to edit keyboard buttons and steering axes; select
a physical controller to edit its controller profile, assignment, triggers and
dead zones. Keyboard bindings use Aurora's `keyboard_bindings.dat` persistence
and remain separate from `ControllerProfiles.json`.

To use **A or RT for Accelerate / Select**:

1. Keep A in the first binding slot.
2. Click **+ Add** beside it.
3. Release buttons and triggers, then fully pull RT.
4. Click **Save Profile**.

Either input activates the same action in menus and races; this does not switch mappings based on game context. Each action supports two alternative inputs, not a simultaneous-button chord. LT and RT use the configured trigger threshold. If a control is shared with another action, remapping succeeds and shows a warning. Clear removes both bindings for the action. Clearing Item or Drift restores its underlying analogue trigger behavior. Bind Drift to RB if RT should accelerate without also drifting.

## Findings and changes

- macOS GameController and the pinned SDL 3.4.4 both detected the connected Xbox One controller and SDL opened it successfully.
- The old native Controller Settings menu only synthesized F10 to toggle the toolbar. It now opens a dedicated AppKit controller panel.
- Newly discovered controllers were explicitly left unassigned. The first controller now takes Player 1 only when no saved Player 1 preference exists.
- Assignment and unassignment updated SDL without updating Aurora's cached player index. Both now change together, including when displacing another device.
- The raw joystick wizard emitted `platform:Windows` on macOS. It now uses SDL's actual platform name.
- SDL suppresses controller events when an AppKit panel owns focus instead of an SDL window. The panel scopes the background-input hint to its active lifetime and restores the prior value on close.
- The initial remapper listened only to buttons, so analogue triggers could never bind. Trigger capture and runtime translation now use explicit LT/RT binding identifiers and the real trigger thresholds.
- The initial duplicate-binding restriction made most already-mapped buttons unavailable. Shared bindings now work with a visible warning.
- Primary and alternative bindings are independently editable and persisted per hashed GUID/serial identity. Existing legacy primary/secondary bindings and dead zones are retained when first saving a profile. Identical devices without serials share a profile.
- Profiles are atomically saved in `~/Library/Application Support/KartPad/ControllerProfiles.json`. Invalid JSON is preserved rather than overwritten.
- The existing diagnostics report includes controller subsystem state, detected devices, assignments and profile status. Raw serials and profile keys are not included.
- The package audit now accepts its actual build product instead of requiring dual-game-only selectors for a supported base build.

## Relevant files

- `apple/macos/KartPadControllers.inc.mm`: native panel, capture, profile persistence, live tester and diagnostics.
- `apple/macos/KartPadMacShell.mm`: menu and Settings integration.
- `patches/aurora-macos-controller-assignment.patch`: default assignment and cached-index corrections.
- `patches/aurora-macos-trigger-bindings.patch`: shared binding predicate and trigger-to-game-input handling.
- `patches/wiicompiled-macos-controller-settings.patch`: runtime panel integration and wizard platform correction.
- `scripts/prepare-g7-game-runtime.sh`: applies the patches to disposable runtime sources.
- `tests/macos/controller_profiles.mm` and the two controller test scripts: profile, binding and assignment regression coverage.

## Validation

- Full ARM64 base-game runtime compiled, linked, packaged and passed the product-aware macOS package audit and strict codesign verification.
- Earlier native-panel build launched with existing game data; the panel showed the physical Xbox as Player 1 and retained the user's existing bindings.
- User confirmed input after reconnecting; subsequent game rendering reached race results.
- Automated tests cover profile round trips, legacy secondary bindings, dead zones, malformed-profile preservation, shared bindings, clearing, and Xbox labels.
- Real SDL virtual input verifies that A and RT independently activate the binding predicate used by the runtime, and release deactivates it. The A/RT pair survives save/reload.
- Tests exercise the prepared runtime's actual player-assignment functions for cached-index fallback, displacement, unassignment and Player 4.
- Applying both Aurora patches to clean pinned sources reproduces the compiled input sources exactly.

## Build from a repository checkout

The supported local macOS build entry point is the repository's self-build
workflow. It requires a supported Mario Kart Wii WBFS image and prepares the
private extraction and translation outputs before building and auditing the
app:

```sh
./scripts/self-build-macos.sh /path/to/your/Mario-Kart-Wii.wbfs
open build/KartPad.app
```

For lower-level runtime preparation after a translation graph already exists,
use `scripts/build-macos-app.sh`; its arguments and product names are defined
by that script. The repository README documents the corresponding preparation,
packaging, and audit commands.

## Manual checklist

- Launch with Xbox already connected; verify button and axis feedback. If input is absent, reconnect and record that it was necessary.
- Assign to Player 2, back to Player 1, then unassign/reassign; verify the displayed assignment and game behavior.
- Add RT as the alternative to Accelerate / Select's A. Verify both work independently and releasing either clears that input.
- Save, quit and reopen; verify A + RT remain configured.
- Test Cancel, Clear, shared bindings and trigger threshold changes.
- Verify steering, brakes, drift, item, pause, D-pad and keyboard in a race.
- Disconnect/reconnect while the controller panel is open and during gameplay.
- Select Keyboard, change a button and steering-axis binding, clear or reset a
  binding, quit and relaunch, and verify the changes reload. Confirm that
  editing Keyboard leaves each physical controller profile unchanged.

Remaining scope: a broader first-run wizard, game-context-dependent mappings,
more than two bindings per action, and raw-unmapped-device native remapping
are not included. Testers should exercise the available Original and Retro
Rewind products, fullscreen/notch behavior, and additional controllers when
those products and devices are enabled.
