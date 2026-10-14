# KartPad issue triage, 14 October 2026

Latest public app: **0.8.1, build 263**, published 13 October. Intake found
31 open issues and one open PR, draft #375. This pass does not publish a new
app or close any affected-device report. The follow-up found new issue #475
(Mac certificate failure); current open count is 32. Discord was not contacted; no physical
iPad was used. Work reuses the existing clean task worktree; the dirty primary
checkout is untouched.

## New evidence and replies

| Issue | Finding | Disposition / next actor |
| --- | --- | --- |
| [#470](https://github.com/chrissotraidis/kartpad/issues/470) | Both attached logs read. First runtime 0.7.15/260, next 0.8.1/263; Adreno 810, 1×, automatic all-draw repack. Low FPS with a busy game thread, no pending shaders in slow samples. Later 0.8.1 health reaches severe thermal status | Keep as a regression report alongside #339; engineer compares equivalent warmed work. [Reply](https://github.com/chrissotraidis/kartpad/issues/470#issuecomment-6159854879). No further log/settings request |
| [#202](https://github.com/chrissotraidis/kartpad/issues/202) | Photos prove 0.8.1 on the Thor still has bands. One shows Android status/navigation bars. The cutout change did not settle this | SDL window correction below; affected Thor confirmation remains open. [Reply](https://github.com/chrissotraidis/kartpad/issues/202#issuecomment-6160040078) |
| [#301](https://github.com/chrissotraidis/kartpad/issues/301) | Moto G85 0.8.1 still lacks bodies; log says `matrix_rows=false native_uniforms=false`. Reporter says Dolphin renders them correctly | This is not a failed rows test. Keep graphics and input-dependent frozen picture separate. [Reply](https://github.com/chrissotraidis/kartpad/issues/301#issuecomment-6159855329), no repeat experiment |
| [#472](https://github.com/chrissotraidis/kartpad/issues/472) | New OnePlus OPD2403, API 36, 0.8.1/263: faces remain visible, bodies invisible, graphics options reportedly tried | GPU/driver absent; one reviewed diagnostic log requested in [reply](https://github.com/chrissotraidis/kartpad/issues/472#issuecomment-6159856023). Link the graphics family without assuming a duplicate cause |
| [#380](https://github.com/chrissotraidis/kartpad/issues/380) | Follow-up uses third-party IPA/DATA and no computer/PadMint; reporter adds iPadOS 26.6.1 and anti-revoke DNS | App provenance/version unverified; not confirmation of the 0.8.1 picker failing. [Explained the supported build route](https://github.com/chrissotraidis/kartpad/issues/380#issuecomment-6159855691); no evidence blaming DNS, no reinstall request |
| [#473](https://github.com/chrissotraidis/kartpad/issues/473) | New request for touch L item-hold similar to A acceleration lock, Android and iPhone/iPad | Enhancement labelled and [acknowledged](https://github.com/chrissotraidis/kartpad/issues/473#issuecomment-6159856629). Optional/off by default, lifecycle clearing; [scope](TODO.md#optional-touch-item-hold-473), not implemented |
| [#465](https://github.com/chrissotraidis/kartpad/issues/465) | Already closed by reporter after 1× avoided the heat-related slowdown seen at 4×. Their 1.5× option request was still actionable | Android menu now offers 1.5×. [Reply](https://github.com/chrissotraidis/kartpad/issues/465#issuecomment-6160331947). This is a quality/performance choice, not a fix for #470 or a measured speed gain |

The new #475 report fails HTTPS certificate validation before compilation.
The Mac preflight recipe could switch to a different Python on PATH; it now
retains PadMint's interpreter. This is a tested routing correction, with the
reporter's TLS cause still unconfirmed. [Reply and launcher question](https://github.com/chrissotraidis/kartpad/issues/475#issuecomment-6161775955). See the [follow-up evidence](artifacts/2026-10-14/android-input-cpu-renderer.md#new-mac-build-report-475).

No other recent player reply changes the next action. Existing pending device
checks remain pending; silence is not acceptance. No duplicate closures in this
pass. #472's GPU/driver and #301's frozen-picture behavior must not be erased by
consolidating them into #104.

## Performance evidence used

The [performance handoff](ANDROID-PERFORMANCE-HANDOFF.md#new-regression-evidence-470-14-october)
contains the bounded numbers and interpretation. Health records were matched
to the console PID and time, excluding version-65 historical heat readings.
Both sessions run Retro Rewind according to their console/health records; the
new export's session directory is misleadingly prefixed `base`.

The observed slowdown is real. These are different sessions, with different
thermal conditions and unlabelled offline/online boundaries, so their medians
cannot establish a before/after speed difference or identify a commit. No
whole-game performance gain is claimed. The follow-up reduced vertex-repack
CPU cost in a controlled microbenchmark; see below. Do not disable the Adreno 8xx repack that fixed
real rendering failures merely because it costs CPU time.

## Android window correction (#202)

SDL 3.4.4 calls `setWindowStyle(false)` during activity startup; the game's
native window is also created without SDL's fullscreen flag. The style command
is queued. It can run after KartPad's resume/focus callback, restoring
`FLAG_FORCE_NOT_FULLSCREEN`, clearing `FLAG_FULLSCREEN`, and setting SDL's
`mFullscreenModeActive=false`. The last part also disables SDL's automatic
bar re-hide after a swipe.

`KartPadActivity.sendCommand` now passes fullscreen for window-style commands,
leaving all other SDL commands unchanged. The existing aspect/cutout policy
still lives in `hideGameSystemBars`. No renderer or game-pack change is needed.
Reference: [pinned SDLActivity source](https://github.com/libsdl-org/SDL/blob/release-3.4.4/android-project/app/src/main/java/org/libsdl/app/SDLActivity.java).

Validation:

- Baseline fixture from main `61e64930`: Android 14/API 34 shows black bands
  and `FORCE_NOT_FULLSCREEN` after cold launch. The added regression script
  fails against this baseline at the fullscreen assertion.
- Changed fixture: fills the same screen and reports `FULLSCREEN`,
  `HIDE_NAVIGATION`, and `IMMERSIVE_STICKY`. Cold launch, Home/resume and a
  system-bar swipe pass on API 34 and API 36. API 34 menu dismissal also passes.
- On the fresh API 36 emulator, the first run during initial rotation/setup
  lost its native window. After setup settled, a fresh process passed the
  sequence; that first attempt is not counted as a pass.
- 1.5× selection persists in preferences and remains checked after process
  restart on API 34. The production framebuffer-sizing test covers 1.5× at
  4:3, wide and portrait aspects within allocation limits.
- Fixture and actual game-app builds compile. Repository suite: **354 passed,
  221 subtests passed**, plus the framebuffer-sizing test. The unrestricted
  pytest discovery command first found a command-line prototype; rerunning
  against the repository's `tests/` directory is the reported suite.
  Follow-up runtime checks: 40 targeted tests and 4 subtests, scheduler
  event-service ASan/UBSan, shared-runtime parity and framebuffer bounds pass.

Reproduce the window check after `scripts/build-android-fixture.sh`:

```sh
python3 scripts/test-android-immersive-window.py emulator-PORT \
  android/app/build/outputs/apk/debug/app-debug.apk
```

Use a disposable emulator with an existing debug-signed KartPad or no install.
The script refuses physical targets. It does not clear app data or uninstall.
An emulator pass does not establish that the Thor firmware's window behavior
is resolved; #202 remains open until the affected path is confirmed.

## Cursor/JNI crash found during game validation

The first actual-game Android 14 run aborted in `SDL_HideCursor` called by
`settings_overlay::Draw` from the guest fiber (`VIWaitForRetrace_HLE`). ART
reported an invalid JNI transition-frame reference in the Java pointer-icon
path. A debug baseline made from unchanged main reproduced the same abort on
its second cold launch; its first launch survived. This is a timing-dependent
existing path, not proof that any particular player crash has this cause.

Android cursor visibility now updates in `HandleEvents`, reached through the
existing scheduler-stack event service. `Draw` no longer makes that Java-backed
call on Android. ImGui's per-frame cursor changes are disabled on Android so
its frame worker/guest path cannot bypass that ownership rule. Mouse activity
still restores the system cursor and inactivity hides it. Other platform pins
are unchanged. Runtime source: [WiiCompiled #7](https://github.com/chrissotraidis/wiicompiled/pull/7),
commit `c74f7d059b6fa6e8c457e3dc02fe7847d1017249`. Staged source was verified
against that pin after the build.

The cursor candidate starts on API 34/36; API 34 reaches a Luigi Circuit race.
Mouse/idle, Home/resume and system-bar swipe retain the same process and
fullscreen window without the baseline JNI abort. These are smoke checks,
not completed-cup, performance or Adreno acceptance.

The seeded-data title-screen observation was investigated further. Android's
fullscreen tutorial and the game's idle demo confounded the first attempts;
the original run recovered to license selection without restarting. Separately,
a real short-tap defect was found: unified WPAD status and KPAD drained the same
pending edge. Each now has its own latch, with held-state and lifecycle tests.
The final private build passes a **normal fresh folder import, license creation,
a race and Home/resume in its first native game process** on API 34.
[Exact scope and evidence](artifacts/2026-10-14/android-input-cpu-renderer.md#short-taps-and-first-launch).

## Review status

[KartPad #474](https://github.com/chrissotraidis/kartpad/pull/474) and
[WiiCompiled #7](https://github.com/chrissotraidis/wiicompiled/pull/7) remain draft.
The inherited desktop workflows were replaced by the maintained Android
compile/link/behavior lane, retaining translator tests. Both runtime jobs pass
on `ac118be`; KartPad's three checks passed on `83096695`. No checksum or
architecture guard was weakened. This is not a fix for the old desktop Dawn
archive mismatch. Final release-signed update/fresh races, artifact audits,
PadMint player checks and affected-device evidence remain required.

## Open PR and remaining work

Draft [#375](https://github.com/chrissotraidis/kartpad/pull/375) is mergeable with
passing hosted checks, unlike the older conflict snapshot. It still has
unresolved sustained rendering/replay, custom course/variant/mode coverage,
and physical iPhone picker/gameplay acceptance. No change or merge in this pass.

Graphics candidate 2 (bone index through a vertex attribute) is implemented,
built and off by default. The separate synthetic probe passes 49,152 checks
on Vulkan SwiftShader; affected Adreno acceptance is still missing. The rows
path failed on S24 and is a separate experiment. For #470, a loop change reduces
vertex-repack CPU time by roughly 27–34% in the larger synthetic cases, preserving
all output hashes; no phone FPS improvement or regression cause is established.
[Follow-up tests and measurements](artifacts/2026-10-14/android-input-cpu-renderer.md),
[bounded #470 progress reply](https://github.com/chrissotraidis/kartpad/issues/470#issuecomment-6161798518).
The [PGO follow-up on unprofiled Mario Circuit](artifacts/2026-10-14/pgo-cross-track.md)
also favors the candidate, with variable baseline timing and 9% code growth.
Retro coverage, final-runtime/phone validation and a distribution decision remain.
#473 remains behind this correctness/performance work.

## Local evidence

Private logs and reply receipts are preserved in ignored
`private/triage-20261014/`; screenshots are in ignored `build/perf/ui/`.
The tested private APK is under
`build/triage-20261014-cursor/20261014-122105/out/`, SHA-256
`2580dbd669ee284ccb66d2286c3af76880795fb131163c9c30c2c09f05d6e364`.
It retains a development 0.8.1/263 label and is not a public update. Public
records contain only reviewed findings and issue links. No player archive,
game data, saves, translated game library or device
identifier is added to Git.

Follow-up private build, fingerprint, tests and log locations are recorded in
the [14 October engineering evidence](artifacts/2026-10-14/android-input-cpu-renderer.md).
