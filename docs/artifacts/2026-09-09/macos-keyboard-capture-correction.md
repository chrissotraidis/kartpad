# macOS keyboard capture corrections for PR #112

9 September 2026. This follow-up is based on contributor head
`d18d3e6c0aefb06a857da35ac2dd78c1ceaa919d` of
[PR #112](https://github.com/chrissotraidis/kartpad/pull/112), rather than main.
It addresses the two reproduced keyboard review findings without replacing the
contributor's controller work or declaring the whole proposal accepted.

## Corrections

- Cancel, Escape, window close, loss of key-window focus, device selection and
  leaving the Controllers tab now clear both controller and keyboard capture.
  Keyboard labels refresh when capture is cancelled. A subsequent keypress
  cannot silently overwrite the cancelled binding.
- Capture converts the physical AppKit keycode with the same Darwin table and
  hardware ISO correction used by pinned SDL 3.4.4. It no longer converts the
  layout-dependent character name into a physical scancode. Thus keycode 12
  emitting `a` on an alternate layout binds the Q-position scancode the runtime
  polls, rather than the A-position scancode. Keypad, function and navigation
  keys retain their distinct physical identities; Escape is reserved for cancel.

The unchanged SDL mapping table retains its zlib notice and source attribution
in `apple/third_party/sdl`. Its SHA-256 matches both inspected SDL 3.4.4 builds:
`a06bfbb5a52b09bd06d0f25db64e054c8a1e37b46b5311a3e4a314874faacd9f`.

## Evidence

- The previous native reproducer still confirms cancelled capture remains armed
  and physical keycode 12 with character `a` incorrectly binds A on d18d3e6.
- The expanded actual-class native profile harness passes cancellation,
  Escape, close/reopen, focus loss, the shared tab-cancellation method, alternate
  character layouts, special keys, ISO swapping, axis capture, repeat and unknown
  key handling. Its existing virtual SDL controller/profile/trigger tests pass.
  These use a temporary profile directory, not the owner's saves or settings.
- The actual KartPadMacShell.mm compiles for all three existing Mac product
  targets against the prepared runtime and dependencies. No full game was linked
  or packaged. Four existing toml11 deprecation warnings remain in the profile
  harness; no new warning is introduced by these fixes.
- Existing native settings bridge, controller assignment and 200 final PADStatus
  trigger cases pass. Six macOS dual-mode Python contracts pass.

Reproduce the native checks with `scripts/test-macos-controller-profiles.sh`
using the existing prepared Mac runtime/build arguments. The settings, assignment
and trigger scripts take the prepared runtime source as their first argument.

## Remaining acceptance

This is an isolated follow-up for integration with PR #112. Contributor changes
were not overwritten, and the PR remains open. Actual keyboard-layout switching,
physical controllers and owner Original/Retro races still need final-candidate
acceptance. The two-player visual report #127 is separate; neither its root cause
nor a rendering fix is established here. Android, iPhone/iPad and tvOS behavior
is unchanged by this Mac-only follow-up.
