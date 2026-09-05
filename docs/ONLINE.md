# KartPad online ledger and execution loop

Online multiplayer is implemented and passes the local Apple-to-Apple
development checkpoint. A native macOS client and the exact iPad Simulator
client can log in to a compatible isolated WFC service, match, form a room,
vote, exchange live race packets, finish through the retail online result path,
apply ratings, and return to the shared lobby.

That evidence does not yet establish public Retro WFC service compatibility,
Wiimmfi compatibility, Wii interoperability, or physical-device online
acceptance. `v0.4.0-preview.1` is the public online-capable dual-mode preview, but
it is not accepted for live public Retro WFC or physical-device online play
while the external service is unavailable. The local harness result does not
establish either claim.

No account, credential, public-service authorization, or production-service
compatibility is currently claimed. This loop uses the pinned authorized local
server first and never commits credentials, payloads, private keys, captures,
game data, translated code, or saves.

## Production Retro WFC service boundary on 1 September 2026

Production online acceptance is waiting on Retro WFC service recovery. This is
an external-service limitation, not a blocker for KartPad's accepted Retro
Rewind installation, launch, or offline gameplay. The official Retro Rewind
documentation says Retro WFC is in testing/maintenance mode after sustained
DDoS and cyber attacks, and the official status page currently shows no live
room data.

The exact released KartPad 0.3.0 build reaches the production Retro WFC flow,
receives a successful NAS authentication response, and advances to GameSpy
profile login. The public gameplay-login endpoint then does not accept a TCP
connection, and the game reports `61070`. The same endpoint also times out from
the macOS host. This is the furthest currently available production gate; it is
not evidence of production matchmaking or race acceptance.

Retest NAS authentication, GameSpy login, matchmaking, room entry, a complete
race, results, and reconnect when both the
[official service notice](https://mkwiiki.org/wiki/Retro_Rewind) and
[Retro WFC status page](https://status.rwfc.net/) show recovery.

The released `0.3.0` dual-mode build has also been signed locally, installed
over the existing KartPad app on a physical iPad without uninstalling it, and
launched to the Original / Retro Rewind chooser. On build 7, a fresh hands-on
run downloaded, verified, and installed the official 6.12.4 pack without a
crash, launched Retro Rewind, and reached a playable single-player match. Build
8 was then installed in place without removing KartPad's data and carries the
final iPad multiplayer-guidance polish, validated in the exact iPad Simulator
candidate. This closes the physical pack-install, launch, and initial
offline-gameplay gates. The production connection sequence above remains the
authoritative online boundary until Retro WFC recovers, but it does not hold
this build open.

Retro Rewind online compatibility is version-locked. KartPad reads the official
`RetroRewindVersion.txt` feed before starting that mode. When the official
version is newer than KartPad's pinned translated profile, the app blocks the
online-capable launch and directs the user to a compatible KartPad update. A
new asset pack alone cannot update the ahead-of-time translated `Code.pul`
graph embedded in KartPad.

## Local checkpoint completed on 1 September 2026

- Clients: native arm64 macOS plus `iPad Pro 13-inch (M5)` Simulator.
- Service: isolated, pinned WiiLink-compatible WFC backend on loopback.
- Identity: separate local profiles, friend codes, QR2 sessions, ports, and
  storage roots.
- Flow: login, matchmaking, two-player room, forced Luigi/Mach Bike metadata,
  unanimous Luigi Circuit vote, race start, bidirectional race packets, native
  finish/results, rating update, and return to `Racers / OK`.
- Runtime evidence: both clients held 60 FPS during the automated run; macOS
  logged player 1 and Simulator logged player 0 entering the native finish path
  at fixture frame 1,800. Both then consumed the complete 5,001-frame fixture.
  macOS closed with 3,596 sends and 3,606 receives; Simulator closed with 3,621
  sends and 3,577 receives.
- Harness boundary: the input fixture is a Time Trial ghost and cannot finish
  naturally from different online VS grid poses. The test-only environment
  therefore invokes `RaceinfoPlayer::UpdateRealLocal` after a sustained packet
  window. Production builds do not set that environment variable. This proves
  the real result/rating/lobby protocol path, not human steering skill.
- Safety: both original save files were restored after the run and matched
  their pre-test SHA-256 digests exactly.

No crash, missing translated target, controller-interruption modal, network
disconnect, or save mismatch occurred in the accepted run.

## Remaining goal loop

Work from the first incomplete goal. Every implementation step must have an
immediate local test and evidence before advancing.

1. **O1 — Apple transport — local pass:** implement and contract-test BSD socket, DNS, TLS,
   plaintext Retro-WFC routing, timeout, error, and cleanup behavior on macOS
   and the iOS Simulator.
2. **O2 — Online product — local pass:** add a fail-closed private workflow that consumes an
   explicitly supplied Retro Rewind folder and payload, translates the pinned
   `Code.pul`, emits nonzero Retro Rewind shards, and builds the separate
   `RetroRewind` executable without publishing generated inputs.
3. **O3 — Local server:** build the pinned WFC server and payload, provision a
   disposable local PostgreSQL database, disable only the documented local
   version gate, and expose deterministic start/stop/health commands.
4. **O4 — Single-client state machine — local pass:** prove DNS, payload/bootstrap, TLS or
   documented plaintext transition, profile/authentication, server login, and
   clean logout from one macOS client.
5. **O5 — Local race — superseded by cross-Apple pass:** run two isolated macOS clients through matchmaking,
   room formation, voting, race start, live race state, results, and cleanup.
6. **O6 — Simulator client — local pass:** repeat the single-client flow on one iPad
   Simulator, including termination, relaunch, and network failure handling.
7. **O7 — Apple-to-Apple race — local pass:** complete the local race/results flow between
   macOS and the Simulator with separate client identities and storage roots.
8. **O8 — Resilience:** run local latency, jitter, loss, disconnect, server
   outage, reconnect, and resource-leak fixtures; never stress a public server.
9. **O9 — Claim gate — local claim only:** only after the exact candidate passes the documented
   local matrix and any normal authorized external-service prerequisites may
   KartPad say online multiplayer is supported. Physical-device acceptance
   remains separate and is excluded from the present machine-only loop.

## Per-state iteration

For each protocol state: name the expected transition, read the pinned client
and server implementations, add the smallest deterministic fixture, run one
client, compare encoded state/timing/error mapping/cleanup, record sanitized
evidence, and continue. Two identical failures require a changed hypothesis or
instrumentation before a third attempt.

## Baseline on 1 September 2026

- Base translation: 29,065 shared base functions.
- The private online graph and isolated WFC payload build and run locally.
- BSD socket, DNS, local HTTP routing, UDP peer negotiation, race traffic, and
  cleanup pass on macOS and iPad Simulator.
- Local login, matchmaking, room, voting, race, results, ratings, and lobby
  return pass end to end.
- External service, impairment, reconnect, physical-device online, and
  cross-client interoperability rows remain open. Production Retro WFC testing
  is specifically waiting on the documented service outage to end.

## Android local-server boundary on 5 September 2026

The pinned server can now be reconstructed with
`scripts/test-android-local-wfc-server.sh`. Its PostgreSQL 17 image is locked by
digest and uses tmpfs-only state; the unchanged upstream schema is imported
after explicitly creating its assumed non-login `wiilink` owner. The runner
builds the clean server pin, requires frontend/backend RPC, NAS, all four
GameSpy TCP listeners, QR2 UDP, and NATNEG UDP, then proves the API 36 emulator
can reach the isolated NAS endpoint through `10.0.2.2`. It stops the exact
server/container and removes the temporary state on every exit.

This closes Android reachability to the pinned local service, not a game-client
state. Retro payload/bootstrap, translated guest routing, authentication,
profile login, matchmaking, race traffic, results, reconnect, and physical
networking remain open. Evidence:
`docs/artifacts/2026-09-05/android/a5-local-wfc-server-boundary.md`.
