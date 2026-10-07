# GitHub review: 7 October 2026

Snapshot: **7 October, approximately 09:35 JST**. Public baseline is
[0.7.14/build 258](https://github.com/chrissotraidis/kartpad/releases/tag/v0.7.14).
Reviewed all **26 open issues**, their complete comment histories, all **five
open PRs** and their review/check state, and recent comments on closed issues.
The [bug-fix priority board](MAINTENANCE-BOARD.md) owns the current decisions;
this is the dated evidence behind them. No issue was closed, no reporter was
messaged and no product code or release was changed in this review.

## Is intake slowing?

Not established. These are equal, complete seven-day windows in Japan time,
counting issues only (bugs, requests and support), excluding pull requests:

| JST dates, inclusive | New issues | Currently closed issues whose latest closure falls in window |
| --- | ---: | ---: |
| 2026-09-16 through 2026-09-22 | 17 | 3 |
| 2026-09-23 through 2026-09-29 | 14 | 14 |
| 2026-09-30 through 2026-10-06 | 19 | 56 |

The latest week has **19 versus 14 new issues (+36%)**, or 16 if only the three
known duplicate HONOR submissions are removed from that week. This is not an
exhaustive duplicate-adjusted rate across weeks. The current backlog is much
smaller, but **20 duplicate, 20 not-planned and 16 completed closure reasons**
make up the latest week's 56 currently closed entries. Forty-seven have their
latest closure on 3 October JST. Consolidation and stale-report triage explain
much of the reduction; even a `completed` label is not independently verified
player acceptance. These are latest closure timestamps, not an event replay:
reopened issues and multiple closures are not counted as historical throughput.

Daily creation counts for 1–6 October JST are **4, 2, 2, 2, 2, 4**. The newest
issue was created at **6 October 02:10 JST**; the partial day on 7 October is
excluded. A quiet interval of roughly 31 hours cannot establish a trend.
There is no active-user, download-cohort or play-hour denominator here, so these
counts cannot estimate the defect rate or establish that a release is healthier.

Reproduction: paginate `GET /repos/chrissotraidis/kartpad/issues?state=all&per_page=100`;
exclude objects containing `pull_request`, convert `created_at` and `closed_at`
to UTC+09:00, and use half-open windows Sep 16–23, Sep 23–30, Sep 30–Oct 7.
This snapshot contains 128 accessible non-PR issues; deleted/transferred-away
reports are outside its scope. Count `state == open` separately from GitHub's
repository `open_issues_count` of 31, which includes the five PRs. Raw API
responses and the calculated issue-number sets are retained privately in
`build/priority-review-20261007/`; raw diagnostics/email-quoted content are not
copied into this document.

## Recent responses and what changed

No issue comments created or edited after the previous #416 update
(6 October 23:35 JST) were found. No new PR review or PR conversation reply
was found in this refresh. The following recent replies remain material:

- [#200: playable again, still slow](https://github.com/chrissotraidis/kartpad/issues/200#issuecomment-6012081573),
  6 October: new positive gameplay report after closure, plus unresolved speed.
  Add the vivo report to #339's evidence without treating it as another crash or
  assuming its current installed build. No new logs requested.
- [#339: optimization scope and equivalence](https://github.com/chrissotraidis/kartpad/issues/339#issuecomment-6007676791),
  6 October: siahisaforker correctly distinguishes all FP helper cost (~17% of
  the cited sample) from context/TLS work (~3%). Inspect NaN/sNaN, signed zero,
  rounding modes, FPSCR exceptions, nested/reentrant contexts, and ARM64 register
  pressure. Passing a pointer cannot claim removal of all FP work. This substantive
  comment has no later maintainer reply in the snapshot; this plan incorporates it.
- [#390 acknowledgement](https://github.com/chrissotraidis/kartpad/issues/390#issuecomment-6012706453),
  6 October: no new log or validation. Keep using the existing video and diagnostic.
- [#402 positive DeX/menu result](https://github.com/chrissotraidis/kartpad/issues/402#issuecomment-5994763404),
  5 October: reporter says the fading menu works. This is actual narrow acceptance,
  unlike a closed stale report.
- [#304 PowerVR ZIP](https://github.com/chrissotraidis/kartpad/issues/304#issuecomment-5996163884),
  [#301 Adreno log/images](https://github.com/chrissotraidis/kartpad/issues/301#issuecomment-5989232524),
  and [#104 diagnostic](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5987853222),
  5 October: retained negative results already reviewed in the
  [6 October investigation](TRIAGE-2026-10-06.md). No newer attachment was found.
  A different image is not a known-good image; an empty self-check does not
  eliminate a vertex-path defect. Do not repeat the potentially disruptive
  PowerVR capture or promise a broad bone-layout rewrite from this evidence.

## Every open issue: disposition and next gate

The order here is issue number, not engineering priority. Related failures stay
separate until evidence establishes a shared cause.

| Issue | Lane | Evidence / next gate |
| --- | --- | --- |
| [#90](https://github.com/chrissotraidis/kartpad/issues/90) | Deferred | Original Wiimmfi is a separate translated/authentication path; Retro online does not implement it. Define that path before a build. |
| [#91](https://github.com/chrissotraidis/kartpad/issues/91) | Deferred | DSU target is Apple TV 4K gen 3 plus iPhone DSUController. Packet validation, calibration and stale-input release precede hardware acceptance. |
| [#100](https://github.com/chrissotraidis/kartpad/issues/100) | Deferred | USB-C chooser-to-game handoff and AirPlay need separate tests; positive #199 gameplay is not proof for either complete flow. |
| [#104](https://github.com/chrissotraidis/kartpad/issues/104) | Graphics | S24 Ultra/Adreno 750 still fails on 0.7.12. Empty self-check draws are inconclusive; retain the actual failing character draw and test vertex layout/matrix hypotheses separately. |
| [#127](https://github.com/chrissotraidis/kartpad/issues/127) | Rendering acceptance | Mac two-player character alignment remains open. Retained Mac race images are encouraging; exact candidate, sustained race and affected-M5 acceptance are still absent. |
| [#131](https://github.com/chrissotraidis/kartpad/issues/131) | Awaiting affected device | Three emulator cups on 0.7.10 reached endings, including trophy and 3x. No new affected Poco/AYN confirmation; do not repeatedly run the unchanged cup test. |
| [#202](https://github.com/chrissotraidis/kartpad/issues/202) | Display | AYN Thor top/bottom unused screen area is a surface/inset issue distinct from 3D aspect ratio. Compare navigation/inset transitions locally before more aspect toggles. |
| [#203](https://github.com/chrissotraidis/kartpad/issues/203) | Deferred | Keep RMCE01, complete NAND/identity transfer and cheats separate. None follows merely from an upstream sync or raw-save import. |
| [#234](https://github.com/chrissotraidis/kartpad/issues/234) | Storage safety / migration | Same-phone Wheel Witch restore lacks Mii/identity/country state. Checked-write fixes in #416 protect recovery but do not implement full migration. Next: process-death and launcher recovery checks with synthetic data. |
| [#295](https://github.com/chrissotraidis/kartpad/issues/295) | Deferred feature | Original export already confirmed; Retro transfer is the remaining scope in #375. #436 fixes a separate compressed Original import defect and does not close this request. |
| [#300](https://github.com/chrissotraidis/kartpad/issues/300) | Deferred | iOS 15.7/macOS 12 request requires dependency/API audit and those OS tests. Lowering a manifest minimum alone is not support. |
| [#301](https://github.com/chrissotraidis/kartpad/issues/301) | Graphics | Moto G85/Adreno 619 supplied 0.7.13 log and images on Oct 5. Character/idle-freeze failures remain; neither comparison alone fixed them. No repeat capture request. |
| [#304](https://github.com/chrissotraidis/kartpad/issues/304) | Graphics | Moto G54/PowerVR supplied 0.7.14 ZIP on Oct 5. Constant-index comparison matches original; alternate vertex layout differs. Neither result identifies a correct image or proves a bone-lookup cause. |
| [#306](https://github.com/chrissotraidis/kartpad/issues/306) | Input | Mac Wiimote + Classic Pro delay/D-pad remains independent of Android assignment. Reproduce raw event versus mapping/delivery behavior; physical extension test remains required. |
| [#324](https://github.com/chrissotraidis/kartpad/issues/324) | Awaiting affected device | Single Joy-Con iOS changes shipped in 0.5.3; reporter supplied iOS 26.7 but no result on the changes. Existing request remains pending. |
| [#332](https://github.com/chrissotraidis/kartpad/issues/332) | Awaiting evidence | Moto G75 launch exit reported on 0.5.4 without a matching crash diagnostic. Adreno 710 cause is speculative; retain the existing version/error/profile request. |
| [#339](https://github.com/chrissotraidis/kartpad/issues/339) | First priority | Canonical runtime/build performance issue. Retains 12 folded performance reports; #200 now adds working gameplay with poor speed. Separate CPU/stutter and compile goals; correct the 17%-versus-3% context-lookup estimate. |
| [#370](https://github.com/chrissotraidis/kartpad/issues/370) | Awaiting affected device | M2 iPad diagnostic showed an incomplete data copy (247/2,032 files in that report). 0.7.10 startup validation and re-import advice supplied; no affected-device success yet. |
| [#377](https://github.com/chrissotraidis/kartpad/issues/377) | Release acceptance | Android updater shipped in 0.7.14; first real next-release upgrade still needs validation with preserved state. Apple update notice/build handoff remains indexed in TODO.md. |
| [#378](https://github.com/chrissotraidis/kartpad/issues/378) | Input | ipega PG-SW023/038 still failed on 0.7.7. Assignment repair shipped in 0.7.8 after virtual-controller reproduction; actual controller success remains unconfirmed. |
| [#380](https://github.com/chrissotraidis/kartpad/issues/380) | Awaiting affected device | Reporter confirmed the workaround, not the 0.7.4 picker correction. Simulator passes; physical Files-folder selection remains the final scope. |
| [#390](https://github.com/chrissotraidis/kartpad/issues/390) | Startup presentation | Video/log sufficient: game image and FPS panel vanish while touch buttons stay. iPhone 16 and iPad Air 4, both modes, since 0.5.x. Oct 6 reply is acknowledgement, not a new test. |
| [#405](https://github.com/chrissotraidis/kartpad/issues/405) | Network | Reporter will use VPN; mobile-data peer matching still fails. Wi-Fi/VPN contrast supports a network-path hypothesis, not proof of this carrier's NAT configuration or that no app improvement is possible. |
| [#411](https://github.com/chrissotraidis/kartpad/issues/411) | Candidate delivery | Android Sound shipped in 0.7.14; iOS #420 is included in #416. Simulator persistence is verified; physical audible categories, other-app audio and relaunch remain open. |
| [#430](https://github.com/chrissotraidis/kartpad/issues/430) | Candidate delivery | Shake under Controls, default off and separate from steering, is in #435/#416. Sensor/menu tests pass; physical comfort, tricks/wheelies and takeover remain unverified. |
| [#431](https://github.com/chrissotraidis/kartpad/issues/431) | Awaiting evidence | HONOR LGN-NX3, 0.7.14/258, Retro, 0.5x/Fill Screen; report has context but no attached image/log. #432–434 are duplicates, not additional affected devices. Existing single request stands. |

## Open pull requests

Four drafts and one non-draft; all report mergeable at this snapshot. Mergeability
and passing checks do not establish gameplay or release acceptance. No submitted
reviews or approval decisions were returned for these five PRs.

| PR / head | Role | Remaining gate |
| --- | --- | --- |
| [#416](https://github.com/chrissotraidis/kartpad/pull/416), `e6bb7da7`, draft | Combined 0.8.0 candidate: upstream sync, sound, shake, Original import, checked storage writes. Two listed CI checks pass. | Rebuild final Android package after storage changes; exact signed fresh/update path, matching packs, physical sound/gesture/replay acceptance. No measured speed improvement. |
| [#420](https://github.com/chrissotraidis/kartpad/pull/420), `e279e6d5`, non-draft | iOS Sound; implementation included in #416. No checks listed on this PR head. | Physical audible levels, background/Done/relaunch and other-app audio. Non-draft does not mean accepted. |
| [#435](https://github.com/chrissotraidis/kartpad/pull/435), `378c668a`, draft | Isolated shake change included in #416. No checks listed. | Physical gesture/in-race/controller and Apple navigation acceptance. |
| [#436](https://github.com/chrissotraidis/kartpad/pull/436), `9810a1f0`, draft | Isolated Original compressed-import repair included in #416. No checks listed. | Matching final app/pack, physical/iOS replay; the combined Android emulator has one completed imported replay, not every course. |
| [#375](https://github.com/chrissotraidis/kartpad/pull/375), `a3651907`, draft | Separate unfinished Retro transfer; not wholly included in #416. Three listed CI checks pass. | Native Retro replay/rendering, compatibility and preservation gates; don't bundle merely to reduce the PR count. |

The first four rows represent overlapping integration work, not four independent
features waiting to be shipped. After an accepted integration, reconcile the
component PRs against the merged implementation and recorded gates. Do not merge
or close them simply because their code appears in a draft. This review adds
only documentation/queue changes to #416, so its head will advance from the
snapshot above; the product-code evidence remains tied to `e6bb7da7`.
