# Android controller routing verification — September 20

Three source defects were independently reproduced with SDL 3.4.4 virtual gamepads and the maintained Android input/PAD modules. They are corrected in runtime `ba52d22`.

| Decision | Before control | Fixed result |
| --- | --- | --- |
| Assigned SDL controller must use Android's mapped Classic route | Remapped South produced Classic B while the same press still produced guest GameCube A | The guest GameCube port is disconnected for that SDL assignment; mapped Classic B remains |
| Explicit Unassigned must override first-use convenience | Clearing Player 1 immediately reconnected its lone unassigned controller | Disconnected after clear, reconnect, and a fresh process reading the saved preference |
| Both controller settings surfaces must update the same assignment | Legacy `PADSetPortForIndex` changed SDL's index without changing the Classic bridge's cached index | Legacy assign/clear use the existing locked, persisted assignment service |

The change preserves keyboard-only GameCube ports and the separate USB GameCube-adapter override. Ownership remains in effect while native settings suspend Classic input, so suspension does not expose a second route. It does not consume latched button presses. The first-use single-controller fallback remains available until a port preference exists.

## Evidence

`prototypes/stabilization/android_controller_routing_probe.cpp` links the actual Android Aurora input, PAD, SI and logging modules against the pinned host SDL. It compiles the actual `PAD__Read_HLE` function with guest memory and the separate USB-adapter service replaced by fixtures. It exercises two virtual controllers, A/B remapping, suspension, release, reassignment, explicit clear, reconnect, process restart, legacy settings, keyboard-only ports, and the adapter override.

Private local logs under `work/controller-routing-20260920/` preserve three failing controls (`before.log`, `assignment-before.log`, `legacy-before.log`). Each failed at its named behavioral assertion. `final.log` and `final-reopen.log` pass. The clean-runtime sanitized build and both processes also pass (`sanitized-clean.log`, `sanitized-clean-reopen.log`). Its adjacent build receipt records source hashes, clean runtime revision, compiler command and executable SHA-256.

The first sanitizer attempt mixed instrumented Abseil container headers with release Abseil objects and failed before the behavior checks. Abseil changes its container ABI and poisoning behavior under ASan. Rebuilding the exact pinned Abseil source with matching ASan/UBSan flags corrected the harness; no product code or sanitizer checks were disabled. SDL and remaining prebuilt dependencies are uninstrumented.

Three production-function tests now run with ASan/UBSan in CI. They cover every ownership mask, saved empty versus unset selection, legacy service dispatch, keyboard preservation and adapter precedence. All **286** local Python tests pass. The linked SDL probe is additional local evidence; the smaller CI fixtures do not substitute for it.

Reproduction from the existing prepared Mac build:

```sh
python3 prototypes/stabilization/build-controller-routing-probe.py \
  build/stabilization-20260919/macos-build /tmp/kartpad-routing/probe
/tmp/kartpad-routing/probe /tmp/kartpad-routing/fresh-user
/tmp/kartpad-routing/probe /tmp/kartpad-routing/fresh-user reopen-empty
```

For sanitizer validation, configure and build the prepared build's pinned `_deps/abseil-cpp-src` in a separate directory with C++20, Release, `-fsanitize=address,undefined -fno-sanitize-recover=all`, testing disabled and `ABSL_PROPAGATE_CXX_STD=ON`. Supply that directory with `--sanitized-abseil-build`. Always use a fresh user directory for the first process.

## Acceptance limits

This establishes real SDL-to-runtime behavior on the host, not physical ipega firmware/mode behavior or complete Android gameplay acceptance. The USB override is a service fixture, not a hardware-adapter test. Issue #197 may include additional controller-mode or online problems. macOS #306 follows a different input path and is not claimed fixed. No new reporter testing requests or issue closures were sent. New app packaging and runtime acceptance follow this source verification.
