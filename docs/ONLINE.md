# KartPad online ledger and execution loop

Online multiplayer is implemented and passes the local Apple-to-Apple
development checkpoint. A native macOS client and the exact iPad Simulator
client can log in to a compatible isolated WFC service, match, form a room,
vote, exchange live race packets, finish through the retail online result path,
apply ratings, and return to the shared lobby.

The local checkpoint does not establish Wiimmfi compatibility or Wii
interoperability. Later owner-reported Android Retro WFC login, worldwide
matchmaking and live racing are recorded in the
[first Android release evidence](artifacts/2026-09-07/android/first-release-verification.md).
Complete public-service results/reconnect and broad physical-device coverage
remain open; the historical service outage below is not a current blocker.

## Wiimmfi and console identity

Wiimmfi for Original Mario Kart Wii is an open compatibility request
([#90](https://github.com/chrissotraidis/kartpad/issues/90)), with no accepted
implementation or release date. KartPad executes an ahead-of-time compiled
game graph: importing a patched ISO does not replace that native graph. A
server address or MAC field alone does not implement the game's service patch,
authentication/identity handling, or interoperability. A future integration
needs a reproducible matching executable profile, private identity handling,
and verification through race/results/reconnect on the intended platforms.
Do not upload NAND backups, certificates, or console identifiers to an issue.

Issue [#94](https://github.com/chrissotraidis/kartpad/issues/94) exposed a separate
numeric serial defect. The first corrected packages were Android `v0.4.10-android.1`,
iPhone/iPad `v0.4.11`, Mac `v0.4.11-macos.1`, and experimental Apple TV
`v0.4.11-tvos.1`; later previews retain the correction. See
[current downloads](../README.md#downloads). Older affected packages should remain offline. The client correction
preserves identities and saves; it cannot remove bad historical CSNums or
reverse existing service bans. Affected histories require service-admin review,
not save deletion or identity regeneration. See the
[backport evidence](iterations/issue94-csnum-hotfix.md).

## Historical production Retro WFC boundary on 6 September 2026

Retro WFC's public health endpoint and room feed are reachable again and report
active service. This clears the external outage that previously prevented a
production retest; it does not itself establish KartPad compatibility.

During the earlier outage, the exact released KartPad 0.3.0 build received a
successful NAS authentication response and advanced to GameSpy profile login.
The public gameplay-login endpoint then did not accept a TCP
connection, and the game reported `61070`. The same endpoint timed out from the
macOS host. That historical result is not evidence for the recovered service or
the 0.4.4 candidate.

The 0.4.4 candidate was awaiting a retest of NAS authentication, GameSpy login,
matchmaking, room entry, a complete race, results, and reconnect before making
a production-online claim. Physical-device acceptance remains separate.

The released `0.3.0` dual-mode build has also been signed locally, installed
over the existing KartPad app on a physical iPad without uninstalling it, and
launched to the Original / Retro Rewind chooser. On build 7, a fresh hands-on
run downloaded, verified, and installed the official 6.12.4 pack without a
crash, launched Retro Rewind, and reached a playable single-player match. Build
8 was then installed in place without removing KartPad's data and carries the
final iPad multiplayer-guidance polish, validated in the exact iPad Simulator
candidate. This closes the physical pack-install, launch, and initial
offline-gameplay gates for the tested version only. It is not relabeled as
6.12.7 or 0.4.4 acceptance.

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

## Baseline updated 6 September 2026

- Base translation: 29,065 shared base functions.
- The private online graph and isolated WFC payload build and run locally.
- BSD socket, DNS, local HTTP routing, UDP peer negotiation, race traffic, and
  cleanup pass on macOS and iPad Simulator.
- Local login, matchmaking, room, voting, race, results, ratings, and lobby
  return pass end to end.
- The external service is reachable again. Production compatibility,
  impairment, reconnect, physical-device online, and cross-client
  interoperability rows remain open until the exact candidate is run.

## Historical Android local-server boundary on 5 September 2026

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
