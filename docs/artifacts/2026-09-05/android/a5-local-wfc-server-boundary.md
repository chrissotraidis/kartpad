# Android A5 isolated local-WFC server boundary

## Scope

Reconstruct the pinned Retro WFC server and its PostgreSQL dependency in a
repeatable, isolated fixture, then prove the Android emulator can reach the
server through the Android Emulator host alias. This is server and network-
boundary evidence, not a translated guest login, matchmaking, or race.

## Fixture

- Server source: pinned `ref/upstream/wfc-server` commit
  `fbd30fa41a35fe8a407e3a49bc83fe4ff91fd35b`.
- Database image:
  `postgres@sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193`.
- PostgreSQL data exists only in a 512 MiB container tmpfs. The container uses
  an ephemeral loopback host port and `--rm`; no Docker volume is created.
- The pinned schema assumes a `wiilink` owner role without creating it. The
  runner explicitly creates that non-login role before importing the unchanged
  schema and requires exactly four public tables.
- The server is built with `-trimpath` from the clean pin. Upstream tests run
  with `go test -vet=off ./...` because Go 1.26 promotes two existing dynamic-
  format vet findings to failures; the actual test binaries pass.
- The local-only configuration binds GameSpy/NAS listeners to all host
  interfaces, keeps frontend/backend RPC on loopback, disables HTTPS and the
  production Code.pul hash gate, and names the response `KartPad Local WFC`.
- The runner refuses occupied service ports, a dirty/wrong server checkout,
  non-emulator targets, or a stopped Docker engine. Its trap stops the exact
  server/container and deletes the exact temporary directory.

## Result

The final clean run reported:

```text
Android local WFC server boundary passed: server_commit=fbd30fa41a35fe8a407e3a49bc83fe4ff91fd35b postgres_digest=sha256:742f40ea20b9ff2ff31db5458d127452988a2164df9e17441e191f3b72252193 server_sha256=7eac61307cf3c8e8ccad38830202c7af1a7185224905bd0702c63ee5bffccfd1 schema_tables=4 emulator_nas_reachable=yes public_service_used=no
```

Before that pass, the first run exposed a real readiness race: the official
image's temporary initialization server could satisfy `pg_isready` and then
stop before schema import. The final gate requires the image's init-complete
marker and readiness from the final server.

Host and emulator requests both received the pinned NAS server's `Server:
Nintendo` header and the isolated `KartPad Local WFC` body. The emulator request
used `10.0.2.2:29980`; it did not rely on Mac loopback from inside Android.
Frontend/backend RPC, NAS TCP, four GameSpy TCP ports, QR2 UDP, and NATNEG UDP
were all live. After each run, no fixture container, WFC process, listener, or
temporary server directory remained.

The 110-test repository suite passes with one intentional skip, along with the
fixture's shell lint, JSON validation, all 493 patch hunks, pinned source/input
verification, repository safety, and whitespace checks.

## Classification

**Pass for deterministic pinned local-WFC server startup and Android-emulator
host-boundary reachability.** The translated game client has not yet supplied
Retro WFC payload/auth/profile traffic to this server. Client routing, login,
matchmaking, local racing, resilience, and physical Android networking remain
open. No public WFC service, credential, APK, AAB, or private game data was
used or published.
