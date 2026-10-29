# Current goal loop: after 0.8.1

Written 10 October 2026 and updated 15 October. It replaces the
[5 October loop](archive/current-loop-2026-10-05.md), whose setup, sound,
file-check and WiiCompiled-sync work shipped in 0.7.11 to 0.7.15 or is merged
for 0.8.0.

## What we're doing next

**Update 29 October.** The owner requested a complete open-issue pass for the
next release, expanding the older three-item order below. See the
[31-issue disposition](ISSUE-TRIAGE-2026-10-29.md) for actual fixes, checks and
remaining work. Draft #536 contains the release-preparation fixes; #375 is
updated to current main with passing checks but retains its gameplay gates.
The public release remains 0.8.6. This pass does not publish a release or change
the device restrictions below.

**Update 27 October.** The next-build candidate in #522 combines experimental-server validation with an Android WiiCompiled beta resolution fix (runtime #9). The combined APK builds and passes its package audit; emulator checks confirm live resolution changes in menus and a race. No release is published or version-bumped. Phone acceptance remains open. See the [candidate record](artifacts/2026-10-27/next-build-resolution.md) for source pins, tests and remaining integration steps.

**Update 24 October.** 0.8.6 (build 268) is prepared. #509 blocked every fresh PadMint build after upstream WiiCompiled v0.9.0 turned `aurora-main` into a submodule; the builder now checks out the pinned commit directly (#512). Item 3's PGO now ships in the Android pack, measured on the emulator only ([record](artifacts/2026-10-24/pgo-release.md)). Draft #375 stays out: its own remaining gates (wider course/variant/mode replay, Apple and device checks) are still open. The next speed candidate is the game thread's Performance Hint target, from #504's Odin 3 log, and it needs a phone that shows the hitches.

**Update 21 October.** 0.8.5 (build 267) updates Retro Rewind to 6.13.4, adds Android rumble strength and L3/R3 trick mappings, and shortens touch item hold to 0.67 seconds (#473). The owner requested publication without gameplay/device testing. Open draft #375 remains excluded because it conflicts and its ghost replay work is unfinished. Graphics reports #104, #301, #472 and #492 remain unresolved.

**Update 20 October.** 0.8.4 (build 266) is the latest release. It adds
Android rumble ([#497](https://github.com/chrissotraidis/kartpad/pull/497)),
Retro Rewind soundtrack packs (#499, for #441), an optional touch item hold
(#500, for #473), and item 2's bone-index experiment as a Character Graphics
Test option ([#498](https://github.com/chrissotraidis/kartpad/pull/498)). The
Thor reporter confirmed on 0.8.3 that Fill Screen fills the screen, so item 1
is done and #202 is closed. Item 2 now waits for a log with the bone-index
option on from #104, #301, #472 or #492. Item 3 is unchanged.

**0.8.1 is the latest release** (13 October, build 263). 0.8.0 shipped on
12 October, and PadMint 0.5.1 brought KartPad's Mac copy back the same day.
PadMint 0.5.2 (15 October) adds GalaxyPad and does not change the KartPad
route. The [11 October handoff](RESEARCH-HANDOFF-2026-10-11.md) still records
Chris's decision not to buy a test phone.

Decided 15 October. Do these three things in order. Do not start another
documentation pass, and do not refresh the September compatibility matrix or
the dated maintenance-board snapshots.

1. **AYN Thor fullscreen (#202).** Photos on 0.8.1 still show black bars with
   Fill Screen on. An Android 14 emulator reproduced the bands, and a startup
   correction filled the screen there, including after returning from the
   background and dismissing the menu. That correction is not in 0.8.1 and has
   not been checked on a Thor. Land it, then ask once, on a build that contains
   it.
2. **One Adreno character path (#104, #301, #472).** Native uniform buffers and
   matrix rows both failed on the S24 Ultra. Do not ask for another matrix-rows
   log. The next attempt passes each vertex's bone index to the GPU. #472
   already tried the in-app options on a OnePlus tablet.
3. **One phone check of the speed draft (#339, #470).** PGO and a vertex-repack
   reduction are in draft #474. Both are emulator results. The Honor Magic 8
   Lite slowdown is part of this check. Do not publish a speed release from the
   emulator pairs. Flat-memory locals and moving GX off the game thread stay
   behind that phone check.

Leave the rest. #475 is a PadMint recipe, not another KartPad guide. #380 waits
for a PadMint-built app. #390, #332, #431, #131, #304, #411, and #378 wait on a
device, a log, or a hands-on check. #306 and #476 stay unscheduled. Feature
requests stay in the backlog. The iPad checks in
[Phase 0](#phase-0-publish-080-done) can happen when the iPad is connected.
They do not come before the three items above.

Released state is in [STATUS.md](STATUS.md). Speed details are in the
[performance handoff](ANDROID-PERFORMANCE-HANDOFF.md).

## Ground rules

- **Devices:**
  - Use the Android emulator, iPad Simulator and this Mac. **Do not use the
    hardware iPad** (Chris's current instruction). Other physical devices need
    an explicitly owned test session.
  - No test phones get bought (Chris confirmed this on 11 October). Remote
    device labs are the proposed substitute; see the
    [11 October handoff](RESEARCH-HANDOFF-2026-10-11.md#research-remote-device-labs).
- **Benchmarks:**
  - Only when the Mac is quiet (`sysctl -n vm.loadavg` low).
  - Use the bench in [`tools/android-perf`](../tools/android-perf/README.md).
  - Emulator FPS is not a result.
- **Players:**
  - Don't ask anyone to run settings experiments.
  - At most one request per issue per release, and only for the standard
    **Report a Problem** log.
  - Close an issue when someone affected confirms, or when the fix shipped and
    the reporter's own case is covered.
- **Replies:** first person, signed "Chris", in the reporter's language, short.
  No promises of dates.
- **Releases:**
  - Follow the [release checklist](RELEASE-CHECKLIST.md).
  - Drafts stay drafts until Chris says publish.
  - Docs change in the same PR as the behavior they describe.
  - Never publish game data, keys, saves or signing material.
- **PadMint:**
  - Keep `padmint.json`, the `published_app` names and `SHA256SUMS` stable.
  - The PadMint chat owns the PadMint repository. PadMint 0.5.1 or newer
    carries KartPad 0.8.0 and 0.8.1. PadMint 0.5.2 adds GalaxyPad.

## Phase 0: publish 0.8.0 (done)

Published on 12 October as build 262, tagged at `41c07740`. It added the Mac
controller fix and an Adreno 6xx/7xx character-drawing change to the build 261
draft. 0.8.1 later put Automatic back, because that change hid characters on
some phones.
These were the steps.

- **Publish:** done. 0.8.1 is the latest release.
- **Check the published files:**
  - download every file anonymously and check it against `SHA256SUMS`;
  - confirm the update path from 0.7.15 on the emulator once more if anything
    changed.
- **Post the 0.8.0 replies:** #437 (app icons) and #430 (Shake to Trick) are
  closed. #377 (update notices) stays open because iPhone, iPad and Mac still
  install through PadMint. #202 stayed open: 0.8.1 photos show the bars remain.
  #411 (iPhone/iPad sound) shipped in 0.7.15 and stays open for a hands-on
  check with Spotify.
- **PadMint 0.5.1** (Intel Mac iPhone builds, KartPad's Mac copy): published
  right after 0.8.0, so README's "Mac: build with PadMint" is true again.
- **Hands-on checks** on the iPad that no automation can do: **Display → App
  Icon**, **Controls → Shake to Trick…**, and the **Update available** notice
  once a newer release exists.

0.8.1 was published on 13 October as build 263. It returned Adreno 6xx/7xx
Automatic to 0.7.15 behaviour, accepted any RMCP01 image whose extracted game
files match, and shipped the folder picker and matrix-rows option. Matrix rows
did not bring riders back on the S24 Ultra.

**Done when:** 0.8.1 is latest, and the hands-on iPad checks above are recorded.

## Phase 1: Android speed (#339)

This is third. The [order above](#what-were-doing-next) finishes the Thor
correction and the Adreno bone-index attempt first. #470, the Honor Magic 8
Lite slowdown, is part of this phone check rather than a separate project.

The [performance handoff](ANDROID-PERFORMANCE-HANDOFF.md) has the evidence. In
order:

- **P1. Measure PGO** for the game pack on a quiet Mac.
  - 14 October: later matched cold-boot pairs on Mario Circuit, which was not
    in the training profile, used less game-thread CPU with PGO (about 6.9 ms
    per frame against about 7.7–8.7 ms). Executable code grew about 9%. This
    is emulator CPU time in draft #474, not a shipped change and not phone FPS.
  - Still needed: a Retro Rewind race in the profile, the final runtime, and
    an affected phone.
  - **Keep it** if the bench shows 10% or more.
  - **Then decide how it ships:** the APK can carry it, but PadMint builds need
    a published profile, which is Chris's decision.
- **P2. Phone A/B for flat-memory locals.** The change cuts 6.4% of the pack's
  code and hides on the Mac's cores.
  - **Prerequisite:** the Pixel for direction, or a slow phone for proof.
  - **If it wins:** implement it in the translator (an entry macro beside
    `EmitHoistedGqrPrologue`) and the Android and iOS runtimes, then offer it
    upstream through patchzyy.
- **P3. Design GX work off the game thread (21% of it).** Write the design
  before code:
  - which GX calls must stay synchronous;
  - how display lists and vertex arrays in game memory stay valid.
  This is multi-day work with a risk of garbled geometry. It needs Chris's go
  after the design.
- **P4. Small items,** only alongside other work: the vertex-layout hash, the
  display-list cache misses, the per-call TLS check in dispatch.
- **P5. Android 10 minimum** (native TLS): re-measure, then it's Chris's
  product decision.

**Done when:**
- every kept change has same-scene before/after numbers posted on #339, with
  emulator, Pixel and reporter results kept separate;
- the next speed release reaches a race as an update and as a fresh install.

#339's targets (10% lower CPU frame time on weaker hardware, 40% shorter
compiles) are goals, not promises.

## Phase 2: Android graphics and stability

The Thor bars are first in the [order above](#what-were-doing-next). The
character reports are one path: bone index next, and no further matrix-rows
log from the S24.

Act when evidence exists; don't chase reporters.

| Issue | State | Next step |
|---|---|---|
| #104, #301, #472 Adreno invisible characters | 0.8.0's native uniform buffers plus character repack ran on the S24 Ultra and still drew no bodies (#104, 12 October). 0.8.1's matrix rows also failed there (option on, 13 October). #301's 0.8.1 log still has missing bodies with matrix rows off. #472 (OnePlus OPD2403, 0.8.1) shows faces only after the in-app options; cause not confirmed | Next is candidate 2: pass each vertex's bone index to the GPU. Do not ask the S24 for another matrix-rows log |
| #202 AYN Thor black bars | 0.8.0 Fill Screen did not remove them. Photos on 0.8.1 still show the bars with Fill Screen on | An Android 14 emulator reproduced the bands and a startup correction filled the screen, including after background and menu. Not in 0.8.1, and not checked on a Thor |
| #304 PowerVR exploding characters | Vertex layout and shader limit ruled out; the matrix read is the remaining suspect, and Dawn decomposes it on every Vulkan GPU | 0.8.0 has the native-uniforms option: ask Quiridel once to try **Character Graphics Test → Experimental: native uniform buffers** and send the self-check line |
| #380 iPhone/iPad folder picker: Open does nothing | Reopened 12 October: a second real-device report (iPad A16), plus Cas on Discord (iPhone). 0.7.4's fix was Simulator-only | Folder-only picker shipped in 0.8.1 and works in the iPad (A16) Simulator. A later report used an unofficial IPA without a computer, so it does not confirm the 0.8.1 picker on a PadMint-built app |
| #431 Honor textures | One screenshot and log requested | Waiting |
| #390 launch flicker on 60 Hz iPhones/iPads | The FPS panel vanishes with the game image while touch buttons stay, so presentation timing is suspect | Needs a 60 Hz Apple device to reproduce; no fix yet |
| #332 Moto G75 crash at load | No diagnostic | Waiting for a log |
| #370 game opens briefly | Black but live surface on an M2 iPad | Waiting |
| #131 crash after a cup | Not reproduced on 0.7.10+ in automated full cups | Waiting for a player retest |
| #127 Mac two-player characters outside karts | Known | Mac renderer; low priority |

## Phase 3: controllers and saves

- **#378 generic controllers:** fixed in 0.7.6 to 0.7.8; waiting for
  confirmation.
- **#324 single Joy-Cons; #306 and #476 Mac Wii Remote.** #306 is lag and no
  D-pad with a Classic Controller Pro. #476 (0.8.1) adds a Plus remote that
  does not connect and an original remote that leaves Controller Settings when
  a Nunchuk or Classic Controller is attached. Open, not scheduled.
- **#295 Retro Rewind ghost transfer:** draft #375. Original ghosts already
  work, including compressed Chadsoft ghosts (0.7.15).
- **#234 full identity and Mii migration:** not supported. The save-transfer
  guide says so.

## Track D: upstream fixes, only when substantive

Send WiiCompiled fixes upstream only when they are real and measured: a
correctness fix with a test, or a speed change that passed P1 or P2. Chris
submits; the agent prepares the branch and notes.

## Backlog (not in this phase unless Chris pulls one in)

- **Online and networking:**
  - #449 LAN/direct play (would mean hosting a WFC-compatible server on one
    device);
  - #90 Wiimmfi;
  - #405 mobile data, which carriers block; a VPN works (closed).
- **Platforms:**
  - #445 Switch;
  - #300 older iOS/macOS;
  - #100 AirPlay/external display.
- **Input and content:**
  - #91 DSU input;
  - #441 original soundtrack mod;
  - #203 assorted requests;
  - #473 optional touch item-hold;
  - #454 dual-screen Android (a second race view is large; touch controls or
    the menu on a Thor's bottom screen is the smaller version).
- **PadMint:** one-click rebuild on new KartPad releases ([to-do](TODO.md)).

## Support, every pass

- **Reply** to new issues within the pass: classify each as performance (fold
  it into #339), graphics, crash, controller or feature.
- **Keep the docs in step:** update [KNOWN-ISSUES.md](KNOWN-ISSUES.md) and
  [STATUS.md](STATUS.md) when an issue's state changes.
- **Pixel:** when it's connected, install the current release on it in place,
  keeping its data.

