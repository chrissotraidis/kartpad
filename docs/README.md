# KartPad documentation

**[Bug-fix priorities: Android performance, build time and acceptance](MAINTENANCE-BOARD.md)**

[Latest issue loop and build findings](INVESTIGATION-2026-10-08.md) ·
[GitHub inventory and intake trend](GITHUB-REVIEW-2026-10-07.md) ·
[To-do: things we decided to do later](TODO.md)

[Coordinator runbook and implementation plan](MAINTENANCE-AUTOMATION.md) ·
[Canonical active queue](MAINTENANCE-BOARD.md).

For downloads, start with [Get KartPad](../README.md#get-kartpad) in the
project README.
The [expandable FAQ](../README.md#frequently-asked-questions) answers common
setup, controls, compatibility and troubleshooting questions.
Guides below describe current workflows; dated records describe only the build
and observations named in them.

## Install and use

| Task | Guide |
| --- | --- |
| Install or update | [Android](INSTALL_ANDROID.md), [iPhone/iPad](INSTALL_IPA.md), [Mac](INSTALL_MACOS.md), [Apple TV](INSTALL_TVOS.md) |
| Transfer saves, collect diagnostics or report a problem | [Support](SUPPORT.md) |
| Set up controllers or multiplayer | [Multiplayer](MULTIPLAYER.md) |
| Check support and limitations | [Current status](STATUS.md), [known issues](KNOWN-ISSUES.md), [online](ONLINE.md) |

## Build and test

| Task | Guide |
| --- | --- |
| Build for Apple | [Build workflows](BUILDING.md), [Personal IPA Builder](BUILDER.md) |
| Build for Android | [Android source builds](../android/README.md), [architecture](ANDROID.md) |
| Test hardware | [iPhone/iPad](PHYSICAL-ACCEPTANCE.md), [Android handoff](ANDROID-PHYSICAL-HANDOFF.md), [tvOS](TVOS-TESTING.md) |
| Work on platform behavior | [tvOS architecture](TVOS.md), [external displays](EXTERNAL-DISPLAYS.md), [UIKit menu repair](IOS-THREE-DOT-MENU-FIX.md) |
| Target Android FPS, stalls and geometry | [Investigation handoff](ANDROID-PERFORMANCE-HANDOFF.md) |
| Investigate runtime correctness | [Portability](PORTABILITY.md), [PPC semantics](SEMANTICS.md), [performance](PERF.md) |

## Maintain and release

| Task | Guide |
| --- | --- |
| Resume current work | [Current goal loop](CURRENT-LOOP.md), [handoff](HANDOFF.md), [maintenance workflow](MAINTENANCE.md), [work/test board](MAINTENANCE-BOARD.md) |
| Check requirements | [PRD](PRD.md); original [engineering](GOAL-LOOP.md) and [Android](ANDROID-GOAL-LOOP.md) goal loops (history) |
| Prepare a release | [Release checklist](RELEASE-CHECKLIST.md), [Android publication](RELEASING_ANDROID.md), [upstream updates](UPSTREAM_UPDATES.md) |
| Plan deferred work | [Technical debt](TECH-DEBT.md), [future features](FUTURE-FEATURES.md), [research](RESEARCH.md) |
| Review attribution and rights | [Rights and licenses](../RIGHTS_AND_LICENSES.md), [third-party notices](../THIRD_PARTY_NOTICES.md), [artwork provenance](../branding/PROVENANCE.md) |

## History and evidence

- [Release notes](releases/) describe individual shipped versions. The completed
  [0.4.4 validation record](releases/v0.4.4-validation.md) was formerly `NEXT.md`.
- [Artifacts](artifacts/) hold dated, sanitized test/build records and referenced
  captures. [Iterations](iterations/) retain device-specific development results.
- [Engineering journal](archive/JOURNAL.md), [early status ledger](archive/status-through-2026-09-07.md),
  [Android bring-up plan](archive/android-bringup-plan.md) and
  [old release checkpoints](archive/release-checkpoints-through-0.4.11.md)
  are historical. Their old candidates, local paths and pending actions are not
  instructions for the next session.

Keep the README focused on introduction, downloads, usage and its expandable FAQ.
Preserve useful user answers and controls guidance when shortening a page; move
detailed instructions to a linked guide rather than silently deleting them. Update current
summaries in place and link one dated record for detailed evidence. Preserve
release notes, license/provenance records and referenced artifacts; remove
superseded duplicate summaries rather than copying them into more running logs.
