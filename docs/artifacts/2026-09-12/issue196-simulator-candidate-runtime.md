# Issue #196 simulator candidate runtime evidence

This is simulator evidence for the corrected candidate; it is not iOS 27
hardware acceptance and does not authorize IPA publication.

## Candidate

- Source: clean merged KartPad revision `cf47944d1a841f60e7e774dd44e44dc99341fd92`
- Target: cloned iPhone 17 Pro Max / iOS 26.5 Simulator
- Candidate: iOS Simulator `0.4.16`, build `38.96.2`
- Retro pack: official Retro Rewind 6.12.8 pin matched the installed `code.pul`
- Install mode: local ad-hoc simulator install; no certificate identity

## Runtime gates

- Original: existing license, 50cc Mushroom Cup, live Luigi Circuit race,
  88.36-second bounded soak, deliberate termination, relaunch, and title
  boundary confirmation.
- Retro: official 6.12.8 pack, live 200cc SNES Mario Circuit 1 race, timer
  advanced from `00:07.848` to `03:10.699` during a 133.83-second bounded
  soak, deliberate termination, relaunch, and a second live race.
- Four session logs were summarized. Every log recorded zero occurrences of
  `func_8000A440`, `SIGSEGV`, `SIGBUS`, `[mod] FATAL`, `fatal error`, and
  `abort trap`.
- Present telemetry ranged from 47.542–60.592 FPS in the Original session
  and 59.002–60.026 FPS across the Retro sessions.

## Data and release boundary

- The complete protected-data comparison found 5,727 files, zero missing and
  zero changed after the candidate lifecycle run.
- The original simulator was preserved; only the isolated clone was used.
- No physical device was touched.
- No IPA was signed or published.

## Remaining gate

Issue #196 still requires a uniquely signed candidate and a data-preserving
Original and Retro launch/race/relaunch check on the matching iPhone 17 Pro
Max running iOS 27. Simulator success does not substitute for that target.
