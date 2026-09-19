# New issue evidence and implications for the Android candidates

19 September 2026, Japan time. Follow-up to the [depth and coverage review](../2026-09-18/android-depth-and-coverage-pass.md). All 37 issue threads updated since 17 September 00:00 UTC were included, with full comment histories and edited content. There are now 56 open issues. See the [per-thread disposition inventory](github-review-inventory.md).

**Result:** #303 strengthens the existing missing-debug-utils startup classification. #304 establishes a different PowerVR capability rejection that the current candidates do not correct. #302 reproduces an authentic upstream payload change that blocks clean self-builds. Replies were posted and read back on all three. No additional build, settings sweep, log or game-file request was sent. No APK, runtime pin, device, release or application source was changed in this pass.

## What the new Android evidence changes

| Case | New evidence | Effect on current work |
|---|---|---|
| [#303 Redmi Note 11](https://github.com/chrissotraidis/kartpad/issues/303) | Xiaomi 2201117TG; reporter states Android 17/API 37, HyperOS 4; selected Original/base session on diagnostics.2/code119. Missing `vkCmdBeginDebugUtilsLabelEXT` → no supported adapter → fatal renderer startup. | Same precise loader mechanism as #301 and the newer Tab A9+ subcase of #216. Code123/124 contain the narrow loader backport. This additional failure supports the target, but is not a test of either candidate. |
| [#304 Moto G54 5G](https://github.com/chrissotraidis/kartpad/issues/304) | Reporter states Android 15, Dimensity 7020, 8 GB; the actual log identifies PowerVR BXM-8-256 and B-Series driver `1.15@6133110 1.473.1398`. Original/base session, diagnostics.3-mergefix/code121. | A distinct startup mechanism: `Insufficient Vulkan limits for maxInterStageShaderVariables`, before any gameplay. Neither the optional-loader correction nor the depth change addresses this adapter capability check. |

For #303, the log is sufficient for the next engineering decision. The chipset and OS claims are kept as supplied; no unsupported inference about every Redmi, Android 17 installation or driver family is made.

For #304, the selected session and latest OS native-crash entry match by process and timestamp. All three retained build121 crashes have signal 6 and the same relevant native call chain. The exported frames have BuildID `be9930491e079cf1945685104afd9ace791cc941`, which matches the retained code121 symbols. Symbolization reaches `aurora::Module::fatal`, Aurora initialization, and `RuntimeMain`. The latest console identifies the adapter-limit rejection immediately before the fatal path. This is evidence of the application aborting after renderer rejection, not an unexplained in-game driver fault or a demonstrated out-of-memory kill.

Raw archives, process identifiers and OS traces remain in ignored local storage. No private archive contents were reposted. The public reply includes only the failure mechanism and next engineering step.

## PowerVR: a concrete upstream lead, with an additional integration requirement

The exact Dawn baseline used by code123/124 checks the Vulkan vertex-output and fragment-input component limits against the default WebGPU inter-stage requirement. Core uses 16 variables plus two reserved vec4 slots: 72 components. Its lower compatibility requirement uses 15 variables plus those slots: 68 components. The physical-device initializer already retries compatibility limits if the core limits fail. Therefore simply requesting compatibility mode at the app level is not established as a solution to this rejection.

The reporter's log does not print both numerical Vulkan component limits. Do not invent a measured value of 64 for this particular device.

Current upstream Dawn contains a relevant opt-in mechanism. This pass pinned and inspected upstream commit `99807f37d56c1dfe375807f108fe435d7ea303b5`:

- [PhysicalDeviceVk.cpp](https://dawn.googlesource.com/dawn/+/99807f37d56c1dfe375807f108fe435d7ea303b5/src/dawn/native/vulkan/PhysicalDeviceVk.cpp) permits an ImgTec-specific floor of 14 variables/64 components when the instance toggle is enabled.
- [Toggles.cpp](https://dawn.googlesource.com/dawn/+/99807f37d56c1dfe375807f108fe435d7ea303b5/src/dawn/native/Toggles.cpp) defines `vulkan_relax_max_inter_stage_shader_variables` at the **instance** stage. It is not a setting that an existing KartPad build can enable through its UI.
- [Limits.cpp](https://dawn.googlesource.com/dawn/+/99807f37d56c1dfe375807f108fe435d7ea303b5/src/dawn/native/Limits.cpp) still restores unspecified or lower requested limits to the core/compatibility defaults. [Device.cpp](https://dawn.googlesource.com/dawn/+/99807f37d56c1dfe375807f108fe435d7ea303b5/src/dawn/native/Device.cpp) uses that default restoration when constructing the device limits. Thus adapter admission alone is not a complete proof of an honestly bounded rendering device. Passing 14 in a descriptor is not sufficient evidence that downstream device limits remain 14.

KartPad currently leaves this inter-stage limit unspecified in its required-limits descriptor. The main GX shader generator uses two color-channel outputs and up to eight texture-coordinate outputs with per-pixel lighting disabled; this suggests a bounded compatibility path may be feasible, but it does not audit every auxiliary shader, generated variant, compiler workaround or driver requirement. No shader or advertised hardware limit was changed here.

The next local investigation has a concrete scope: review/backport the instance toggle, verify the complete adapter → device → pipeline limit contract without advertising unsupported capabilities, enumerate actual GX and helper shader interfaces, and test rejection and graceful startup recovery. An accepted adapter must then render correctly on the affected driver before claiming Moto G54 support. Turning an abort into a clear launcher error is a separate useful acceptance gate from making the game playable.

This is a stronger lead than a generic Android refactor. It remains outside code123 and code124, and no device test is requested yet.

## #302: clean self-build blocked by mutable Retro-WFC payload

[The report](https://github.com/chrissotraidis/kartpad/issues/302) correctly identifies the payload endpoint. Current GitHub main and the primary checkout both pin:

| Identity | Pinned | Observed in this pass |
|---|---|---|
| Bytes | 28,968 | 28,992 |
| SHA-256 | `fd8f26d6af26f1a0cfaecd1e472fe744a25d75f5136910533b7c75e3eca2f1d2` | `099097a0f85a97c348123d91438438b24b112362f1fb23c94df6a343c5366471` |

The current `_download` function reproduced the exact reported “pinned Retro Rewind download is larger than expected” error. It removed the partial output and did not publish a final file. The generic message is misleading in this case: the failing input is the small Retro-WFC executable payload, not the approximately 1.86 GB Retro Rewind track pack.

The observed file passes header, declared-size and RSA signature validation against the existing pinned production signing key when its observed size/hash are supplied in a temporary validation configuration. This supports an authentic payload update. No profile pin or verification check was changed.

The payload is fed into `translate-mod --retro-wfc-payload`, so a size/hash update is not just a downloader repair. The new executable must be reviewed and translated, and the resulting self-build/runtime must be checked before pin promotion. Existing cached translations and the archived code123/124 artifacts remain unchanged; the report does not establish that those APKs suddenly fail offline or that an online session succeeds with the newer payload.

Next action: review the payload delta and translator compatibility, retain the old input identity, reproduce a clean supported self-build, then promote the reviewed pin. Improve the error to identify which pinned input changed. Removing the size/hash check is not the proposed remedy.

## Recent replies that do not justify another request

- #275 supplied the exact Coconut Mall racing context and has already been acknowledged. The new reply says they will wait. Record it once; it is neither a performance result nor a reason for a further log request.
- #198 likewise expresses willingness after existing warm CPU-heavy evidence was acknowledged. No new expensive function has been identified by that reply.
- #102/#104/#166/#193 still contain negative build121 geometry results. #104 explicitly tested Normal. Their later acknowledgments already record those outcomes. Nothing in this new intake accepts the depth laboratory as a fix for stretched characters.
- #137's symbolized uniform-capacity abort remains separate from #304's startup abort. Similar “crash” wording does not merge these mechanisms.
- #135's build51 log and reported Original improvement were already answered with the correct limits: startup remains accepted, warm performance remains open, and the measured functions do not explain the whole frame. No new Apple request is needed.
- #199's black local/TV image with continuing sound/input remains a presentation case. It is not the startup adapter-rejection mechanism.
- The remaining recent threads have an existing answer or outstanding request and no newer reporter result. The inventory records each disposition. The current instruction to hold additional build distribution remains in effect.

## Verified replies and preservation

- [#303 reply](https://github.com/chrissotraidis/kartpad/issues/303#issuecomment-5737578364): classified the loader signature, explained that internal correction is unverified on the reporter's device, and stopped additional collection.
- [#304 reply](https://github.com/chrissotraidis/kartpad/issues/304#issuecomment-5737578636): classified the separate capability rejection using matched native evidence; no repeat launches or archive requested.
- [#302 reply](https://github.com/chrissotraidis/kartpad/issues/302#issuecomment-5737579079): confirmed the exact size mismatch and authentic payload, while keeping translation/self-build acceptance open.

Each post used the shared action-receipt ledger, checked for intervening comments immediately before posting, and was read back byte-for-byte. No issue was closed. The final comment refresh found only these three maintainer replies and no intervening new reporter comment.

The queue, maintenance board and compatibility matrix now carry the three classified mechanisms and their separate acceptance gates. A fresh full-open-issue query confirmed all 37 reviewed reporter revisions were unchanged; their exact fingerprints and reply/disposition references were recorded in the shared review state. The existing coordinator's active engineering selection was preserved. Five older pending revisions outside the time window remain outside this intake rather than being silently acknowledged.

Validation: 53 maintenance-loop tests and two compatibility-matrix checks pass. The matrix check exposed an older release row missing an issue citation; its existing D-pad context now links to #238 without changing the historical acceptance claim. Final APK hash checks confirm that archived code123 and code124 remain byte-for-byte unchanged. No native build was needed for this evidence/support pass.

The laboratory worktree remains clean on `codex/stabilization-depth-lab-20260918`; its source and previously archived artifacts are unchanged. This pass updates local support records and engineering dispositions, not product implementation or release state. Ignored evidence snapshots, downloaded inputs, crash symbolization and receipt records are under `work/issue-followup-20260919/` in the primary checkout.
