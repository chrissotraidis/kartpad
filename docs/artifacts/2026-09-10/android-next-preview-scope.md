# Next Android preview: integrated candidate scope

This is a candidate for review and release-configuration validation, not a
published APK or an accepted across-device performance fix. Integration starts
from main 1a724728a6dedf980f5241cde658326b328f399c. The measured local source is
2adae79 on codex/android-measured-preview; installed local62 remains unchanged.
Public support and distribution remain coordinator-owned. This task owns source,
build, signing and testing. The owner is playing: no physical input or install.

## Included source

- Adapt the accepted iOS chooser structure and setup help to Android. Preserve
  import, resume, game switching and existing data actions.
- Report a Problem requires either a selected readable text log with explicit
  review confirmation or a reason logs cannot be included. Export does not
  automatically attach or approve logs. GitHub attachment remains manual;
  neither path uploads automatically. Existing bounded private export retained.
- Guard stale ImGui snapshot bounds during Android resize/surface changes.
- Decode the first GEN_MODE write even when its raw value equals the initial
  cached value. This is a demonstrated cold-state defect, not an Adreno fix.
- Retain main's already-reviewed redirected-save preservation on Retro pack
  replacement (#173). Ordinary-exit progress-loss reports remain unconfirmed.
- Enable native frame overlap in the release candidate. A sealed frame owns its
  debug markers and depth mapping; VI/aspect reads are synchronized. Deferred
  ImGui setup occurs after the previous draw lists finish encoding. The existing
  worker protocol and presentation slot/deadline counts remain unchanged.
  Debug builds retain explicit 0/1 property control for matched comparisons;
  release builds take the enabled path without consulting debug properties.
- Preserve bounded phase metrics and their private-log export. Debug-only xxHash
  optimization is retained for comparable local builds, not a public speedup.

No shader experiment, custom driver, speculative arithmetic change or private
GPU-capture instrumentation is added. Test fixtures are host/emulator tooling,
not installed application assets. The guarded installer experiment is excluded.

## Evidence and claim boundaries

Historical Pixel 2x/Fill warm GP-menu comparison: OFF 39.52–49.96 FPS, ON
57.80–58.58 FPS, conservative improvement 15.7%. Stationary Retro comparison:
OFF 51.363–54.157, ON 54.894–55.728 FPS, conservative improvement 1.36%.
These are debug/property comparisons, not measurements of this release artifact.
The owner session's 59.05 FPS mean is unmatched and supplies no gain percentage.
Main-to-Single-Player transitions still took 2.580–2.732 seconds. Neither save
preservation nor chooser changes demonstrate an additional game-FPS gain.

The initial local62 title trial overlapped the owner's active Yoshi/bike race on
Delfino Square and is rejected as a controlled input-duration comparison.

## Current validation and remaining release gates

Fresh Android preparation from this integrated source passed. Actual prepared
resize bounds, sealed debug-marker ownership and captured depth mapping passed
ASan/UBSan harnesses; VI/aspect callback reentrancy and unchanged viewport-policy
access passed ThreadSanitizer harnesses. These extract relevant real source
bodies and do not certify the whole native engine or GPU submission lifetime.
37 touch-overlay/data-action contracts and executable reviewed-log/export policy
checks passed. Previous physical/emulator evidence is retained in the measured
worktree; integration checks do not substitute for release runtime acceptance.

Next: build the non-debug candidate, verify compiled overlap policy and inspect
resource ownership on that configuration, then exercise representative Original
and Retro gameplay, input, Home/resume, report return and resize on a disposable
Android environment. A compatible physical update requires a safe owner handover.
Public candidate must use the existing public signing identity, increasing code,
matching notices/corresponding source/provenance, package audits and repeatable
packaging from clean reviewed/merged source. No public upload is authorized here.
Unrelated affected-Adreno, awards/cup and broad-device FPS issues are not blanket
release blockers; record them accurately rather than claiming they are fixed.

## Apple report-flow follow-through

The next IPA must retain the same explicit reviewed-log or inability-reason
contract across iOS/iPadOS/macOS/tvOS, with platform-appropriate document sharing,
manual GitHub attachment and no automatic upload. Apple implementation and
physical acceptance remain with the Apple owner; this Android integration does
not establish that the Apple build passed those checks.
