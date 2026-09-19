# One failing frame, one investigation

Use one willing technical reporter with a reproducible graphics failure. They reproduce the usual scene and capture one frame; the maintainer investigates that frame. Do not send every reporter a matrix of switches or ask them to diagnose the renderer.

This is an opt-in developer workflow, not an automatic upload or an in-app capture feature. It requires RenderDoc on a supported Windows/Linux host, Android SDK tooling and a USB-debugging connection to the affected phone. The owner does not need to possess that phone. Start with the shared Samsung corruption family; do not generalize its outcome to CPU slowdown or startup crashes.

## Prepare the capture APK

The existing Release build supports `-PkartpadFrameCapture=true`. It requires a version name ending in `-capture`, marks the package debuggable, permits direct launching of `dev.kartpad.android.KartPadActivity`, and explicitly retains native `RelWithDebInfo` optimization. Direct launching avoids attaching to the separate `:launcher` process. This opt-in does not add renderer experiments or enable native Vulkan validation.

The normal Release default remains non-debuggable with the game activity unexported. Existing release auditing rejects a debuggable APK when `KARTPAD_ANDROID_REQUIRE_RELEASE=1`.

Using the existing build script:

```sh
KARTPAD_ANDROID_FRAME_CAPTURE=1 \
KARTPAD_ANDROID_PACKAGE_FORMAT=apk-release \
KARTPAD_ANDROID_VERSION_CODE=120 \
KARTPAD_ANDROID_VERSION_NAME=0.4.25-diagnostics.3-capture \
scripts/build-android-game-app.sh \
  private/diagnostic-translation build/diagnostic-android/runtime
```

Choose a fresh version code if 120 has since been assigned elsewhere. This build script uses the existing local debug signer. A community tester needs a candidate signed with the same persistent identity as their installed app; the local-debug APK cannot update a community-signed installation. Never uninstall or clear data to switch identities. Preserve the installed package, saves and settings. Do not publish this developer APK as an ordinary release.

Retain the APK hash, native BuildID and matching symbols. Verify the final APK's debuggable flag, activity export and version, rather than trusting the Gradle option alone. `BuildConfig.DEBUG` is true in this developer package; explicitly selected debug extras can change behavior. Native optimization alone does not establish that instrumentation leaves reproduction unchanged.

## Reporter handoff

1. Install the matching-signer candidate in place. Open KartPad normally once and confirm the same problem still occurs with Character Graphics Test set to Normal. Keep the original failing settings.
2. In RenderDoc, select the connected Android device. Set Executable Path to `dev.kartpad.android/dev.kartpad.android.KartPadActivity`, which launches the game process directly. Leave arguments empty for this first Original-mode capture.
3. Reproduce the same scene, capture one frame and keep a screenshot showing the defect. Confirm the capture is of the game and that the captured image still has the defect. A chooser-only capture or a frame where the defect disappears does not satisfy the request.
4. Share the capture privately with the maintainer, together with the screenshot, app version and phone/GPU information. A frame capture may contain textures and meshes; do not attach it to a public issue or ordinary public log export.

Follow [RenderDoc's Android setup](https://github.com/baldurk/renderdoc/blob/v1.x/docs/how/how_android_capture.rst) for its host/device installation. Verify the capture/replay connection on the affected device before promising that a particular phone/driver is supported. Replay may need that device; receiving an `.rdc` file does not guarantee replay on the maintainer's Mac.

## Maintainer decision tree

Identify the missing body's draw from the frame's event/resource history and geometry. Do not identify it solely by one of the two previously tracked pipeline hashes. Aurora pulls vertex attributes from storage buffers, so an empty conventional vertex-attribute list does not mean the game omitted vertex data.

| Observation in the failing frame | Investigate next |
| --- | --- |
| Expected draw absent | Game submission, merge/state handling, pipeline readiness; shader arithmetic cannot explain an unissued draw. |
| Draw present, storage/index data wrong | Guest data, decoding, upload ranges, resource ordering and lifetime. |
| Input data plausible, post-vertex geometry wrong | Position/normal/texture transforms, projection, shader translation; compare the working iOS scene at this boundary. |
| Post-vertex geometry correct, pixels missing | Viewport/scissor, culling, depth/stencil, alpha discard, sampled textures and color-write state. |
| Defect disappears under capture or replay | Record that result. Timing/instrumentation became a variable; do not call it fixed or accept the clean capture as the failing case. |

Use the [mesh inspection workflow](https://github.com/baldurk/renderdoc/blob/v1.x/docs/python_api/examples/renderdoc/decode_mesh.rst), pipeline state and shader inspection to narrow the fault. Change one demonstrated cause afterward. Ordinary logs retain their role for crashes and performance; they do not need to grow into a second graphics debugger.

For iOS, use an Xcode Metal frame capture of the corresponding working scene when a reference is needed. The same questions apply; the capture file formats and tools differ. No second in-app capture implementation is required for this developer investigation.

## Acceptance boundary

Source/build/package validation establishes capture eligibility only. Actual attachment, failing-frame capture, replay and identification of the faulty boundary remain separate checks. This workflow does not require an intentional crash and does not itself establish a graphics fix.
