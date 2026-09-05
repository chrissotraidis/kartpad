# Android A5 translated Retro local-WFC request

- Date: 2026-09-05
- Baseline: `2dcccb3` on `codex/android-a4-touch-settings`
- Target: API 36 ARM64 phone AVD, 4 KiB pages, `ranchu`, native
  `2400x1080`
- Runtime: complete private `KartPadDual` Original/Retro graph with validated
  Retro Rewind 6.12.5 content
- Exact local debug APK SHA-256:
  `fdb3cb3c995ddeaf1daef37acfb82dc45f1ffffe41f764fdc6362bcc21ae9a9c`
- Public service used: no

## Falsifiable subgoal

Start the pinned isolated local-WFC service, launch the actual translated
Retro Rewind product, enter its one-player Retro WFC flow, and observe a
guest-originated request at the local service. A host-side `curl` or synthetic
pre-guest network fixture was not sufficient.

## Implementation

`KartPadActivity` now accepts the boolean debug extra
`dev.kartpad.android.TEST_LOCAL_WFC_ROUTE`. The route is inactive unless all
of these conditions hold:

- `BuildConfig.DEBUG` is true;
- the selected runtime profile is `retro_rewind`; and
- Android reports the official-emulator `ranchu` or `goldfish` hardware.

The destination is fixed in source to emulator host alias `10.0.2.2` and NAS
port `29980`; no intent can supply an arbitrary host or port. Release builds
cannot activate the route. The local-server runner also has an opt-in hold
mode so the disposable server remains alive while a human drives the product;
future runs print a sanitized marker when both QR2 availability and the
`RMCPD00` NAS payload request appear.

## Execution and result

The pinned server commit
`fbd30fa41a35fe8a407e3a49bc83fe4ff91fd35b` started against digest-pinned,
tmpfs-only PostgreSQL. Its binary SHA-256 was
`7eac61307cf3c8e8ccad38830202c7af1a7185224905bd0702c63ee5bffccfd1`.
Every NAS, GameSpy, QR2, and NATNEG listener passed before the game launched.

The real product then:

1. reached the branded Retro Rewind title;
2. loaded an existing isolated test license;
3. entered **Retro WFC — 1 Player**;
4. displayed both product privacy notices and required explicit **Permit**;
5. sent an 18-byte translated guest UDP request to local QR2 and received its
   7-byte reply; and
6. caused the local NAS server to receive `GET /payload?g=RMCPD00&…` for host
   `nas.play.rwfc.net`. The salt and hash query values were not retained.

The client transcript contained only the following sanitized route evidence:

```text
[net] local-wfc udp send fd=0 call=1 size=18 dest=0a000202:27900 host-ret=18 host-err=0
[net] local-wfc udp recv fd=0 packet=1 size=7 from=0a000202:27900
[net] local-wfc udp summary fd=0 sends=1 recv-calls=1 recv-packets=1
```

The server logged `QR2 AVAILABLE`, the `RMCPD00` NAS request, and then
`Failed to read payload file`. The game reported error `20913`, which maps to
the stage-1 payload response/header boundary. The isolated server intentionally
contained no executable WFC payload or production signing key.

## Classification

**Pass** for an actual translated Retro client crossing Android DNS/socket
routing and reaching the isolated local QR2 and NAS service. This supersedes
the prior host-only reachability boundary.

**Incomplete** for payload validation, authentication, matchmaking, racing,
reconnect, cross-client play, and physical-device networking. Supplying an
unsigned placeholder would not be valid evidence. Continuing this path needs
a locally controlled client/payload pair with a matching test key, without
shipping that key or using public infrastructure.

The staged test save was backed up before launch. After the result, the prior
fresh save was restored byte-for-byte, the temporary backup was removed, and
the selector was restored. Cleanup left no WFC process, database container,
listener, or temporary server directory. No APK/AAB, payload, save, key, raw
transcript, private capture, or game content was published.

## Validation

- Complete dual-product Android build: pass.
- Repository Python suite with `PYTHONPATH=builder`: 110 tests passed with one
  intentional skip. An initial invocation without that module path ran 89
  tests and failed discovery only because `kartpad_builder` could not be
  imported; the corrected invocation passed without a source change.
- Strict APK identity, ABI, ELF, asset, permission, and privacy audit: pass.
- Pinned source/input and 494-hunk patch verification: pass.
- Repository safety, shell lint, shell syntax, and whitespace checks: pass.
