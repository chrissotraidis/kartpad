# Android A4 touch activity recreation

Date: 2026-09-05

## Outcome

KartPad now enables SDL 3's activity-recreation policy before a recreation can
occur. This prevents SDL's default second-activity guard from terminating the
Android process when the system recreates `KartPadActivity`.

A source-only fixture calls the real `Activity.recreate()` path while A is held.
It requires the outgoing overlay to clear its Classic Controller state during
`onPause`, then requires the new overlay to start neutral. The fixture also
persists a normalized A position, 1.25x A size, and hidden B state before the
recreation and verifies that the new view renders those settings afterward.
The debug intent and saved-state marker cannot activate in a game-runtime build.

## Emulator evidence

The visible API 36 ARM64 Pixel 6 run retained PID 6026 across all three markers:

```text
A4 activity recreation fixture armed held=0x10 owners=1
A4 activity recreation fixture outgoing old=neutral
A4 activity recreation fixture passed new=neutral a_center=1378,559 a_size=1.25 b=hidden
```

The visible API 36 ARM64 Pixel Tablet run retained PID 3351 and passed at its
independent geometry:

```text
A4 activity recreation fixture armed held=0x10 owners=1
A4 activity recreation fixture outgoing old=neutral
A4 activity recreation fixture passed new=neutral a_center=1408,845 a_size=1.25 b=hidden
```

The first diagnostic run intentionally exposed SDL's default behavior: the old
activity cleared input, but SDL logged `activity finished` and exited before the
new instance could initialize. The final JNI-owned hint fixes that actual
lifecycle boundary rather than weakening the fixture.

## Build and audit

The complete translated dual-runtime APK rebuilt at SHA-256
`7e85ffc806a14db2e0954f4da8481f9e8ab9f1728c3e64e2cd74203c82af87d1`.
The strict package/privacy audit, Android lint, 89-test suite with one
intentional skip, repository safety, shell syntax, and whitespace checks pass.
No APK, AAB, or private artifact was published.

## Classification

**Pass for same-process SDL activity recreation, outgoing touch neutralization,
new-overlay neutrality, and touch-layout restoration on both canonical
emulators.** OS-driven process death and physical touch interruption remain
separate acceptance gates.
