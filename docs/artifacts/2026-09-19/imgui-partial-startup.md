# Partial-startup ImGui cleanup — September 20

The new [issue #309](https://github.com/chrissotraidis/kartpad/issues/309) reports
an iPad 9th generation crash on Play Game. Its form says 0.4.25/build51, but the
embedded Apple crash metadata identifies **0.4.24/build49**. The faulting frame
is `ImGui_ImplWGPU_InvalidateDeviceObjects()+28`, reading address `0xb0`, followed
by `ImGui_ImplWGPU_Shutdown`, Aurora ImGui shutdown, `aurora_shutdown`, and
`RuntimeMain`. No further reporter input was requested.

The maintained Apple wrappers still unconditionally shut down both ImGui
backends. Android already guarded missing contexts, but a context whose
renderer/platform backend had not initialized remained unsafe. The common
runtime exception handlers can request shutdown before complete initialization.
The newer explicit graphics-unavailable return bypasses cleanup on that one
failure route; it does not make every partial-startup exception route safe.

The correction checks the current context and each backend's own user-data
pointer before calling its shutdown. It destroys the context once, releases
retained textures, and resets frame/scale/backend state for a later lifecycle.
All four maintained runtimes carry the same cleanup behavior.

## Independent reproduction

A local ARM64 executable links the prepared build's real pinned ImGui core,
SDL/WebGPU backends, SDL and Dawn libraries. The wrapper function comes directly
from the maintained source; it is not a reimplementation. The driver creates
either no context or an ImGui context without initialized backends, then calls
cleanup twice. The wrapper is sanitizer-instrumented; the linked dependencies
are the existing release libraries, not fully sanitizer-instrumented builds.

- The previous Apple wrapper with no context crashes at **`0xb0` in
  `ImGui_ImplWGPU_InvalidateDeviceObjects()+28`**, matching the reported
  failure frame and invalid address.
- The previous Apple wrapper with a context but no renderer also crashes in
  that backend at `0x30`.
- The previous Android wrapper passes no-context cleanup but crashes with a
  context and no renderer.
- The corrected wrapper passes both cases, including repeated cleanup.

Separate ASan/UBSan production-function regressions run every maintained
platform through no-context, context-only, platform-only, renderer-only and
fully initialized cleanup, for both renderer choices. The surrounding service
fixtures enforce backend preconditions and exact release counts. They also
verify repeated cleanup and state reset. The test runs in shared-runtime CI.

Private local reproduction sources, exact linker commands and sanitizer output
are retained under `work/imgui-startup-20260920/`. This confirms the secondary
cleanup defect. It does **not** establish the initial reason the reporter's
renderer failed, or physical iPad acceptance of a new app.

## Candidate impact

Android code132 and Apple build56, including the coordinated archives created
earlier on September 20, **predate this correction**. Their existing validation
records remain valid for those exact binaries. They must not be published as
containing this fix. The next full relinks use Android code133 and Apple build57;
source delivery, symbols, artifact identities and runtime checks must follow
those new binaries.
