# macOS controller and native settings candidate

This contribution by Aedan Pilkington is under review in
[PR #112](https://github.com/chrissotraidis/kartpad/pull/112). It adds controller
assignment, two alternative bindings per action, saved profiles and native
settings. It applies to macOS; it does not change Android or iPhone/iPad input.
A local build is not a public release or hardware acceptance.

## Try the controller settings

Quit any running KartPad normally and back up its data folder first. The
standard app uses existing KartPad data; do not run two copies simultaneously.
Open your candidate app, then **Controls → Controller Settings** or
**KartPad Settings → Controllers**. Cmd-comma or F10 opens settings
(Fn–F10 if the keyboard uses media keys).

To use A or RT for Accelerate / Select:

1. Keep A as the primary binding and click **+ Add** for its alternative.
2. Release the controls, then fully pull RT.
3. Bind Drift to RB if RT should accelerate without also drifting.
4. Click **Save Profile**, quit normally and reopen to check persistence.

Either binding activates the action in menus and races. These are alternatives,
not a simultaneous-button chord or context-dependent mapping. Trigger capture
uses the configured threshold. Shared bindings are allowed with a warning.
**Clear** removes both bindings; clearing Item or Drift restores its default
analogue-trigger behavior. Explicit Item/Drift bindings suppress that fallback.

Profiles are saved atomically to
`~/Library/Application Support/KartPad/ControllerProfiles.json` using hashed
GUID/serial identities. Identical devices without serials share a profile.
Invalid profile JSON is preserved rather than overwritten. Diagnostics include
controller subsystem/assignment/profile status without raw serials or profile keys.

## Build from your checkout

Follow the repository's source-build prerequisites and prepare your own pinned
translation inputs first. Run from the repository root. These example output
paths must be fresh; choose new names if they already exist.

```sh
translation="$PWD/private/self-build/translation"
scripts/build-macos-app.sh "$translation" \
  "$PWD/build/controller-review-source" \
  "$PWD/build/controller-review-build" \
  "$PWD/build/KartPad-controller-review.app" base
scripts/test-macos-controller-profiles.sh \
  "$PWD/build/controller-review-build" "$PWD/build/controller-review-source"
python3 scripts/test-macos-controller-assignment.py "$PWD/build/controller-review-source"
python3 scripts/test-macos-trigger-output.py "$PWD/build/controller-review-source"
open "$PWD/build/KartPad-controller-review.app"
```

The example builds Original. For a dual candidate, use translation inputs that
contain both Original and Retro shards and pass `dual` as the final build-script
argument. A base build does not establish Retro acceptance. Changing a patch
requires fresh prepared sources; editing the patch alone does not update an
existing build tree. Build version and source are recorded in the app fingerprint.

## Acceptance status and test checklist

The contributor reported Xbox use, assignment/remapping and profile persistence.
Earlier input required reconnecting, so cold-connected behavior still needs a
specific check. Maintainer checks on contributor head `271fdc1` passed a full
Original/Retro dual build, package/signature audit, profile tests, 200 final
trigger-output cases, Original launch and the default native controller layout.
The previous trigger-pressure overwrite and clipped Clear buttons are corrected.

On the final candidate, test:

- Cold launch with the controller connected; check live buttons/axes and game input.
- Assign Player 2, restore Player 1, then unassign/reassign; check game behavior.
- Check A and RT independently, releases, Item/Drift, steering, brake, pause and
  D-pad in an offline race. Confirm the saved profile after quitting/reopening.
- Disconnect/reconnect in settings and gameplay; try multiple controllers if available.
- Check Original and Retro separately, windowed/fullscreen transitions, settings
  access in fullscreen and controls at a smaller available screen height.
- Test the optional notch-area mode separately; its presence is not proof that
  every MacBook/display combination works.

Report the app fingerprint, controller model/connection and specific failing
step. Do not post profiles, serials or personal game data. Broader setup wizards,
context-dependent mappings, more than two bindings and native raw-device remapping
remain outside this contribution.
