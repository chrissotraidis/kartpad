# iPad stutter: local log investigation, 25 September 2026

Release remains on hold. This pass used evidence already copied to the Mac;
no device installation, launch, configuration change or cache deletion occurred.
No performance fix is claimed.

## Finding

The strongest lead is first-use graphics pipeline compilation during transitions,
combined with mandatory waits for shaders used in texture copies. Existing logs
correlate pipeline creation with delays but do not measure those waits directly.
They cannot establish a single root cause for every reported menu slowdown.

Latest captured session: Original, build 72, M2/Metal, iPadOS 26.7, Immediate
presentation, interpolation off, normal diagnostics, nominal thermal state and
power-save off. The older diagnostic export is stale; use the session console log.

## Measured delays

At 60 presents/second, 300 presents normally take five seconds:

| Present interval | Elapsed | New pipelines |
| --- | ---: | ---: |
| 900–1200 | 6.819 s | 57 |
| 1500–1800 | 11.250 s | 102 |
| 1800–2100 | 6.517 s | 74 |
| 2400–2700 | 6.234 s | 42 |

The 11.250-second interval includes Luigi Circuit loading. Its full excess is
not a menu-only stall or a shader compile measurement. Course replay reported
zero recorded/queued pipelines for that load. The device database copied after
this session contains course recipes, which does not prove they existed before it.

The displayed/logged FPS is a one-second rolling window sampled only every
300 presents. It reported about 60 FPS even after the 11.250-second interval:
that sample cannot establish that the preceding transition was smooth.

## Why shaders are the leading suspect

Source under `vendor/runtimes/ios`:

- `aurora-main/lib/dolphin/gx/GXFrameBuffer.cpp`: texture copies require persistent
  results, including menu thumbnail textures.
- `aurora-main/lib/gfx/common.cpp`: those passes require ready pipelines.
- `aurora-main/lib/gfx/pipeline_cache.cpp`: required pipelines are promoted and
  waited on until compilation completes. Startup prewarming is bounded to 128.
- `runtime/src/hle/storage/dvd.cpp`, `NotePipelineSceneForRead`: scene replay
  recognizes course/track archives, not menu UI archives. Thus the current
  course replay cannot proactively cover first entry into each menu.

Do not bypass the required waits: a previous attempt to exempt streaming copies
produced missing vehicle thumbnails and was withdrawn in runtime commit 99ccd5e.

## Important historical complication

Build 60 and 64 logs report iPadOS 26.6.2; build 70 and 72 report 26.7. Build 70 startup
prewarming took 13.8 seconds with only 70/305 Dawn cache hits and 235 stores.
Build 72 startup was warm: 297/297 hits, zero stores, reported 0.0 seconds.
This confirms a cold cache in the earlier 26.7 session, but not a cold startup
cache in the latest session. Menu/course shaders beyond the startup set may
still need first-use compilation.

The Dawn source supplied with the release source archive includes the OS version
in Metal's driver description, includes that description in adapter info, and
serializes adapter info into the device cache key. An OS change therefore has a
concrete mechanism to invalidate that cache in the inspected source. This is a
plausible trigger, not proof that the OS update alone caused the regression.
Source inspected: Dawn 13abc3bc8ea2d3c2050f9e77a12d012108ceee24,
`PhysicalDeviceMTL.mm`, `Adapter.cpp`, `Device.cpp`, `api_StreamImpl.cpp`.

Some build 60 intervals created similar numbers of pipelines with little extra
time. Conversely, build 64 had delays without new pipelines. These are unmatched
sessions, not a controlled build comparison; compilation is not a universal
explanation and game work/disc reads remain possible contributors.

## Other checks

- Both seed and copied device pipeline databases pass SQLite integrity checks.
- Latest session does not show thermal throttling or expensive diagnostic mode.
- No presentation-job warning above its 250 ms threshold or device-loss error was
  found. This reduces evidence for a single large presentation-stage block;
  it does not exclude shorter repeated waits or earlier rendering work.
- Audio reports full queues/dropped blocks, with no empty-before-push samples.
  These counters do not demonstrate audio starvation as the initiating cause.

## Next step

Private build 74 already contains rate-limited pipeline-wait durations and long
present-interval logs, with expensive renderer validation off. It has not been
installed or played. Correlate a reproduced menu transition with those durations
before selecting a fix. If required compilation dominates, the narrow candidate
is bounded menu-specific prewarming/readiness before displaying the menu,
retaining texture correctness. Do not delete caches or disable required draws
to conceal the symptom. Rebuilding alone does not clear this release hold.

Private evidence remains under `work/ipad-stutter-20260925/`, including
`present-interval-analysis.json`, `stall-correlation.json`, copied logs/cache,
and the extracted Dawn source. Do not publish raw device evidence.

## Build 75 change (26 September 2026)

Private build 75 adds menu scenes to the existing course pipeline replay. When the
game reads a menu archive under Scene/UI (language suffix removed; Race and Font
excluded), the renderer records the pipelines that menu uses. On later visits,
including after relaunch, it compiles them on every pipeline worker while the
archive loads. Draw correctness is unchanged: the required texture copy waits
remain. Course recording keys are unchanged, and post-race menu pipelines are no
longer recorded inside the preceding course scene.

Limits: each menu's first visit after installation still compiles on demand
because nothing has been recorded for it yet. The improvement applies to later
visits. Only the iOS runtime has this change. Android, macOS and tvOS are unchanged,
so the prepared Android 0.5.1 package remains valid.

- iOS runtime `9d4cde3` (branch codex/ios-menu-stall-20260925); root pin `037b273`.
- Built incrementally in `build/ios74/xcode-device` using `XCODE_XCCONFIG_FILE`
  (build 75, diagnostics candidate NO). The app audit passed. dSYM UUID
  `ADAE8BA4-5433-3032-9723-529D8C6B23BB`.
- Signed with the existing development profile/certificate, and the strict signature check passed.
- Installed in place on the iPad Pro. Before/after user data manifests (34 files) are
  identical. The installed version reads 0.5.1 (75). Not launched: an AgePad console session
  was active on the device.

Gameplay acceptance is pending. To check, open the Single Player and Online menus
twice, relaunching between visits, then collect logs. The second visit should
log `Pipeline scene replay` with a nonzero queued count, and wait messages
should mostly disappear.

