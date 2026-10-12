# Current goal loop: after 0.8.0

Written 10 October 2026. It replaces the
[5 October loop](archive/current-loop-2026-10-05.md), whose setup, sound,
file-check and WiiCompiled-sync work shipped in 0.7.11 to 0.7.15 or is merged
for 0.8.0.

## What we're doing next

**Paused on 11 October.** Start from the
[11 October handoff](RESEARCH-HANDOFF-2026-10-11.md): it records Chris's
decisions (no test phone) and the proposed plan, which puts the Adreno
character fix first. 0.8.0 shipped on 12 October with that fix, and
PadMint 0.5.1 brought KartPad's Mac copy back the same day.

1. **0.8.0 is out** (12 October, build 262). What's left of
   [Phase 0](#phase-0-publish-080-done) is the hands-on iPad checks.
2. **Make Android faster (#339).** The slowness is one CPU-bound game thread.
   Measure the two ready candidates first, then take on the large structural
   change.
3. **Keep players unblocked.** Act on Android graphics and crash reports when
   evidence arrives, and leave new features in the backlog unless Chris pulls
   one in.

Released state is in [STATUS.md](STATUS.md). Speed details are in the
[performance handoff](ANDROID-PERFORMANCE-HANDOFF.md).

## Ground rules

- **Devices:**
  - Use the Android emulator on this Mac, the iPad Pro, the iPhone 14 and this
    Mac, plus Chris's Pixel 9 Pro XL when he connects it.
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
  - The PadMint chat owns the PadMint repository. PadMint 0.5.1 carries
    KartPad 0.8.0 support.

## Phase 0: publish 0.8.0 (done)

Published on 12 October as build 262, tagged at `41c07740`. It added the Mac
controller fix and the Adreno 6xx/7xx character fix to the build 261 draft.
These were the steps.

- **Publish:** done, marked as latest.
- **Check the published files:**
  - download every file anonymously and check it against `SHA256SUMS`;
  - confirm the update path from 0.7.15 on the emulator once more if anything
    changed.
- **Post the 0.8.0 replies:** #437 (app icons) and #430 (Shake to Trick) can
  close (done); #377 (update notices) and #202 (Fill Screen under the cutout)
  stay open for confirmation. #411 (iPhone/iPad sound) shipped in 0.7.15 and
  stays open for a hands-on check with Spotify.
- **PadMint 0.5.1** (Intel Mac iPhone builds, KartPad's Mac copy): published
  right after 0.8.0, so README's "Mac: build with PadMint" is true again.
- **Hands-on checks** on the iPad that no automation can do: **Display → App
  Icon**, **Controls → Shake to Trick…**, and the **Update available** notice
  once a newer release exists.

**Done when:** 0.8.0 is latest, the files verify, the replies are posted, and
PadMint 0.5.1 is out.

## Phase 1: Android speed (#339)

The [performance handoff](ANDROID-PERFORMANCE-HANDOFF.md) has the evidence. In
order:

- **P1. Measure PGO** for the game pack on a quiet Mac (about an hour; the
  pipeline is built).
  - Collect the profile on a different track from the bench, and include a
    Retro Rewind race.
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

Act when evidence exists; don't chase reporters.

| Issue | State | Next step |
|---|---|---|
| #104, #301 Adreno 6xx/7xx invisible characters | 0.8.0's native uniform buffers plus character repack ran on the S24 Ultra and still drew no bodies (#104, 12 October); #301 untested on 0.8.0 | Dolphin-style matrix rows ([candidate 1](RESEARCH-HANDOFF-2026-10-11.md#research-adreno-invisible-characters)) merged as **Character Graphics Test → Experimental: matrix rows like Dolphin** (#463, runtime fa8ee6b), emulator-checked; ships with the next release. Then post once to Deivmsr and PeriTheFrost asking them to try it. If rows fail too, candidate 2 (index as a vertex attribute) |
| #304 PowerVR exploding characters | Vertex layout and shader limit ruled out; the matrix read is the remaining suspect, and Dawn decomposes it on every Vulkan GPU | 0.8.0 has the native-uniforms option: ask Quiridel once to try **Character Graphics Test → Experimental: native uniform buffers** and send the self-check line |
| #380 iPhone/iPad folder picker: Open does nothing | Reopened 12 October: a second real-device report (iPad A16), plus Cas on Discord (iPhone). 0.7.4's fix was Simulator-only | Folder-only picker and always-report-back import merged (#462), checked on the iPad (A16) Simulator; ships with the next release, then ask the reporter to confirm on a device |
| #431 Honor textures | One screenshot and log requested | Waiting |
| #390 launch flicker on 60 Hz iPhones/iPads | The FPS panel vanishes with the game image while touch buttons stay, so presentation timing is suspect | Needs a 60 Hz Apple device to reproduce; no fix yet |
| #332 Moto G75 crash at load | No diagnostic | Waiting for a log |
| #370 game opens briefly | Black but live surface on an M2 iPad | Waiting |
| #131 crash after a cup | Not reproduced on 0.7.10+ in automated full cups | Waiting for a player retest |
| #127 Mac two-player characters outside karts | Known | Mac renderer; low priority |

## Phase 3: controllers and saves

- **#378 generic controllers:** fixed in 0.7.6 to 0.7.8; waiting for
  confirmation.
- **#324 single Joy-Cons; #306 Mac Wii Remote with Classic Controller Pro**
  (lag, no D-pad): open, not scheduled.
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
  - #203 assorted requests.
- **PadMint:** one-click rebuild on new KartPad releases ([to-do](TODO.md)).

## Support, every pass

- **Reply** to new issues within the pass: classify each as performance (fold
  it into #339), graphics, crash, controller or feature.
- **Keep the docs in step:** update [KNOWN-ISSUES.md](KNOWN-ISSUES.md) and
  [STATUS.md](STATUS.md) when an issue's state changes.
- **Pixel:** when it's connected, install the current release on it in place,
  keeping its data.

