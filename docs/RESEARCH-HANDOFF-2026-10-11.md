# Handoff: 11 October review and research

Written 11 October 2026. **Paused by Chris before any work started.** No code
changed; this page records where things stand, what was decided and what the
research found, so the next session can start from here.

## Decisions (Chris, 11 October)

- **0.8.0 stays a draft.** 0.7.15 was just published. Keep 0.8.0's changes and
  ship them with the next release that fixes something players hit.
- **No test phone gets bought,** and there is no Wii Remote or Classic
  Controller Pro here.
- **Solve hardware problems another way:** research, other projects' code,
  remote device labs, and at most one targeted request per issue per release
  to a reporter who has the hardware.

## GitHub on 11 October

- **31 open issues.** None needs a reply: Chris has the latest comment on every
  thread except #390, which ends with the reporter's "no worries". Nothing new
  since #449.
- **Nothing to consolidate.** Duplicates were already closed (#432 to #434,
  #444, #405). #301 stays separate from #104 because it also tracks the picture
  freezing without input, and #104's thread is in Portuguese.
- **Open PR:** draft #375 (Retro Rewind ghost transfer, #295). It conflicts with
  main (30 files, about 2,200 lines) and needs a rebase.
- **Promises to correct:** the 10 October replies on #437, #430, #377 and #202
  say 0.8.0 is "finished and waiting to be published". When the next release
  is scheduled, or if it ships under another version number, post a short
  correction on each.
- **Primary checkout:** `/Users/chrissotraidis/GitHub/kartpad` is on
  `codex/candidate-cpu-handoff-record` (last commit 9 September, 833 commits
  behind main) with 67 modified files and many untracked ones. Left untouched;
  sort it out before working in that folder.

## What 0.8.0 contains

- **Fixes:** Fill Screen draws races under the display cutout (#202, not yet
  confirmed on an AYN Thor). The WiiCompiled sync brings upstream #288 (a
  display list that overflows the staging batch no longer drops 3D models) and
  cleaner TLS shutdown after a failed write; neither is tied to an open report.
- **Features:** Shake to Trick (#430), app icon choice (#437), update notices on
  iPhone, iPad and Mac (#377), PadMint builds on Intel Macs and without Homebrew.
- **Not in it:** no speed work, nothing for Adreno characters.

## Small issues: actual state

Most small items already have code and are waiting on someone with the
hardware, not on new fixes.

| Issue | State | What clears it |
|---|---|---|
| #437, #430 | Built for 0.8.0 | Close when it ships |
| #377, #202, #411 | Built or shipped | Reporter confirmation |
| #378 controllers | Fixed in 0.7.8; no answer since 3 October | One check-in, then close |
| #324 single Joy-Con | Code on iOS (0.5.3) and Android; no answer since 27 September | One check-in, then close |
| #370 game opens briefly | Cause found (incomplete game data); 0.7.10 checks every file | One check-in, then close |
| #131 crash after a cup | Not reproduced in automated full cups on 0.7.10 | One check-in, then close |
| #390 launch flicker, 60 Hz screens | Not reproduced on the 120 Hz iPad Pro | Try the iPad Pro capped at 60 Hz (below) |
| #127 Mac two-player characters | Reproduces on this Mac | Fix here |
| #306 Mac Wii Remote with Classic Controller Pro | A synthetic test (`scripts/test-wii-classic-driver-mapping.py`) says the D-pad mapping is right | Source review, then one build for davidwtkk, who has the hardware |
| #234, #203 | Unsupported or grab-bag requests | Close #234 as not planned; split or trim #203 |

## Proposed plan (not started)

1. **Adreno invisible characters (#104, #301): copy Dolphin's matrix access.**
   This is the biggest player-facing bug that can be worked on without new
   hardware. Details below.
2. **Check it on a remote device lab,** then ask Deivmsr (#104) and
   PeriTheFrost (#301) once each for the standard log.
3. **Ship it with 0.8.0's changes** as the next release.
4. **Alongside:** #390 on the iPad Pro capped at 60 Hz, the Mac two-player bug
   (#127), and a PGO measurement for speed (#339, P1 in the
   [current loop](CURRENT-LOOP.md#phase-1-android-speed-339)).
5. **#306:** read SDL's HIDAPI Wii driver and KartPad's Mac input path for the
   latency and D-pad, then send one targeted build to davidwtkk.

## Research: Adreno invisible characters

**What we know.** On Adreno 6xx/7xx (#104 Galaxy S24 Ultra, #301 Moto G85),
skinned character bodies draw nothing. Karts, eyes and tracks are fine. The
0.7.12/0.7.13 self-checks showed neither the CPU vertex repack nor the constant
(switch) bone lookup draws bodies alone; both together drew them white at about
24 FPS. The 24 September review
([deep review](artifacts/2026-09-24/deep-review-handoff.md), section 2.3) found
the one structural difference between broken and working draws is a
per-vertex index into the uniform matrix array.

**How Dolphin does the same thing.** Dolphin renders these models and runs on
the same phones. Its vertex shader
([VertexShaderGen.cpp](https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/VideoCommon/VertexShaderGen.cpp))
takes the matrix index from a real vertex attribute (`in uint4 posmtx`,
unpacked from a ubyte4), then reads **three separate `float4` rows** from a
uniform `float4` array (`I_TRANSFORMMATRICES[posidx]`, `[posidx + 1]`,
`[posidx + 2]`) and transforms with dot products.

**How Aurora does it.** Aurora's generated WGSL (`aurora-main/lib/gx/shader.cpp`
in the Android runtime, around lines 942 to 1052) declares
`postex_mtx: array<mat3x4f, N>` and `nrm_mtx: array<mat3x4f, N>` in the
uniform, and reads the index out of raw vertex bytes in a storage buffer
(vertex pulling, shift and mask, then divide by 3). On Vulkan, Tint lowers the
whole uniform to `array<vec4<u32>, 208>` and rebuilds each matrix from a byte
offset.

So two things differ from Dolphin at once: where the index comes from (a
storage-buffer read versus a vertex attribute) and how the matrix is read (a
rebuilt `mat3x4f` versus plain `vec4f` rows). Either could be what the
Adreno compiler mishandles.

**Candidates, in order:**

1. **Dolphin-style rows.** Declare the palettes as `array<vec4f, 3N>` and read
   three rows with dot products, keeping today's index source. Smallest change.
2. **Index as a vertex attribute.** Pass the matrix index through a real vertex
   attribute like Dolphin, alone and combined with 1. The existing CPU repack
   already covers part of this, and its 24 FPS cost needs a look.
3. **Pre-transform skinned vertices** (compute pass or CPU) so the draw needs
   no bone lookup. Most robust. A compute pass reads a storage buffer, so the
   Bevy report below applies to it too; the CPU route costs game-thread time.
4. **Palette in a storage buffer.** Last:
   [Bevy #24926](https://github.com/bevyengine/bevy/issues/24926) reports
   skinned meshes corrupted on Adreno 650/730 Vulkan when bone data came from a
   storage buffer, while the uniform path worked.

The white bodies from the combined workaround also need explaining: texture
coordinate generation uses the same matrix lookups (`in_texmtxidx`,
shader.cpp around line 1234), and the [blind-spot
notes](artifacts/2026-09-17/graphics-test-blind-spots.md) list what the old
switch did not cover.

**Not established yet:** that Dolphin draws these characters correctly on an
S24 or Adreno 619 phone specifically. Check public Dolphin reports, or ask the
reporters in the same single request.

### Update 12 October: Dawn rewrites every uniform read

The pinned Dawn (`13abc3bc`, 3 June 2026) turns on
`decompose_uniform_buffers` for Vulkan and GL whenever it runs outside
Chromium (`src/dawn/platform/DawnPlatform.cpp`). Tint then lowers every
uniform buffer to `array<vec4<u32>>` and rebuilds each value from raw words
(`src/tint/lang/spirv/writer/raise/raise.cc`). That is why the September
review saw the whole block as `array<vec4<u32>, 208>`. It applies to every
dynamic uniform read: the bone matrices, and also the per-light loop, which
the old switch workaround never covered and which fits the white bodies.
Dolphin reads plain `float4` rows from a normal uniform buffer.

The toggle is adapter-level, so KartPad can turn it off, but only if every
uniform block keeps std140 layout: Dawn doesn't enable Vulkan's
standard-layout feature. Aurora's only non-std140 field was
`array_start: array<u32, 12>`; it is now `array<vec4u, 3>` (same bytes).

Built in the Android runtime (`codex/adreno-native-uniforms`, `a1db7a3`):

- `KARTPAD_RENDERER_NATIVE_UNIFORMS=1|0` or
  `adb shell setprop debug.kartpad.native_uniforms 1|0`; unset is automatic,
  which turns it on only for Adreno 6xx/7xx and adds the character vertex
  repack there.
- **Character Graphics Test** gains "Experimental: native uniform buffers";
  the older modes keep the rewrite on, so they behave as before.
- The log shows `KartPadUniforms mode=… native=…`, read back from Dawn's
  own toggle list, and the draw self-check line gains `native_uniforms=`.

Checked on the Android emulator with two Vulkan drivers (lavapipe, and the
host GPU through gfxstream): forced on and forced off both draw menus,
character select and a 12-racer Luigi Circuit race correctly, with no WebGPU
errors and the self-check matching. That proves the new path is valid and
doesn't change the picture; it doesn't prove it fixes Adreno. The next
release's self-check line from #104 and #301 answers that.

**Verifying without the phone:**

- The emulator, the Pixel (Mali), the iPad Pro and the Mac show whether a
  candidate draws the same picture as today; that is the regression gate.
- Ship it behind **Character Graphics Test**, with **Automatic** choosing it
  only on Adreno 6xx/7xx, so other phones keep today's path.
- The existing self-check reports whether bodies draw on the affected phones.

## Research: remote device labs

Found 11 October; check terms, availability and models again before use.

- **[Samsung Remote Test Lab](https://developer.samsung.com/remote-test-lab):**
  remote Galaxy phones you control from a browser. The Galaxy S24 Ultra uses
  Snapdragon 8 Gen 3 (Adreno 750), matching #104.
- **[Firebase Test Lab](https://firebase.google.com/docs/test-lab/android/available-testing-devices):**
  physical Galaxy S24 models (only Snapdragon variants have the affected
  Adreno 750). Firebase says Test Lab shuts down after 30 September 2027
  ([FAQ](https://firebase.google.com/docs/test-lab/migrate-faq)).
- **[AWS Device Farm](https://aws.amazon.com/device-farm/device-list/):** paid
  remote access to a wide list of Android phones.

**Game data:** KartPad needs the player's own game data to reach a race, and
these labs are shared devices. Prefer a small test app that draws a synthetic
skinned mesh through the same generated shader pattern, with no game files.
Putting real game data on a lab device is Chris's call.

The same labs could later prove speed changes on slow phones, which the
emulator cannot.

## Other leads

- **#390 flicker:** the iPad Pro can be capped at 60 Hz with **Settings →
  Accessibility → Motion → Limit Frame Rate**. Untested. The iPhone 14 (60 Hz)
  is paired but was not connected on 11 October.
- **Speed (#339):** PGO can be measured on the emulator if the gain is 10% or
  more. The other candidates need a slow phone or a lab device; see the
  [performance handoff](ANDROID-PERFORMANCE-HANDOFF.md).

## Resuming

1. Fetch main; check `gh release list`, open issues and PRs for changes since
   11 October.
2. Confirm 0.8.0 is still a draft and 0.7.15 is latest.
3. Start with candidate 1 in a worktree under `$CODEX_HOME/worktrees`, not the
   primary checkout.
