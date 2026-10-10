# Current goal loop: after 0.8.0

Written 10 October 2026. It replaces the
[5 October loop](archive/current-loop-2026-10-05.md), whose setup, sound,
file-check and WiiCompiled-sync work shipped in 0.7.11 to 0.7.15 or is merged
for 0.8.0.

## What we're doing next

1. **Ship 0.8.0.** It is merged and staged as a draft. Publishing waits only on
   Chris's word.
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
  - No test phones get bought unless Chris decides otherwise. A slow phone is
    the main thing that would let speed work prove itself (see P2).
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
  - The PadMint chat owns the PadMint repository. Its next release (0.4.14)
    waits on KartPad 0.8.0.

## Phase 0: publish 0.8.0 (on Chris's word)

- **Publish:** `gh release create`/publish the existing draft at `c0056a6f`,
  marked as latest.
- **Check the published files:**
  - download every file anonymously and check it against `SHA256SUMS`;
  - confirm the update path from 0.7.15 on the emulator once more if anything
    changed.
- **Post the 0.8.0 replies:** #437 (app icons) and #430 (Shake to Trick) can
  close; #377 (update notices), #202 (Fill Screen under the cutout) and #411
  (iPhone/iPad sound) stay open for confirmation.
- **Tell the PadMint chat** that 0.8.0 is out, so PadMint 0.4.14 (Intel Mac
  iPhone builds, KartPad's Mac copy) can ship. From then, README's "Mac: build
  with PadMint" is true again.
- **Hands-on checks** on the iPad that no automation can do: **Display → App
  Icon**, **Controls → Shake to Trick…**, and the **Update available** notice
  once a newer release exists.

**Done when:** 0.8.0 is latest, the files verify, the replies are posted, and
PadMint 0.4.14 is unblocked.

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
| #104, #301 Adreno 6xx/7xx invisible characters | Self-check logs show bodies draw only with both changes together | A different way to hand bone matrices to the GPU. **Chris decides** whether to try it |
| #304 PowerVR exploding characters | Vertex layout and shader limit ruled out | Waiting for a 0.7.13+ log |
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

