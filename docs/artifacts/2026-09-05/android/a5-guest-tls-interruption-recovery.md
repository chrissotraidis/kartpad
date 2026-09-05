# Android A5 guest TLS interruption recovery

Date: 2026-09-05

Branch: `codex/android-a4-touch-settings`

Parent commit: `4b02fc7`

Classification: **Pass for deterministic handshake interruption followed by a
clean-process guest TLS recovery on the API 36 ARM64 emulator.** Same-process
reconnect, network transitions, retail WFC, and physical hardware remain open.

## Subgoal

Extend the existing translated `/dev/net/ssl` fixture with a real transport
failure before treating its trusted happy path as recovery evidence. The fault
must occur after TCP establishment, inside TLS negotiation, and the following
product process must traverse the same production guest-memory IOCTLV path to
a complete verified response.

## Harness correction

The first clean product rebuild showed that the earlier cached prepared source
predated the guest IOCTLV fixture. A fresh dual-runtime preparation included
the complete current patch stack, and the packaged `libmain.so` was checked for
the exact fixture marker before execution.

The runner also stopped assuming every rapid relaunch creates a differently
named transcript. It records the prior byte length and scans only appended
bytes when Android reuses the same timestamped log path, preventing both stale
matches and false timeouts.

## Fault and result

The runner starts two independent ephemeral host peers:

- the existing loopback-only OpenSSL server for the valid and hostname-failure
  cases; and
- a one-connection Python peer on a kernel-selected port. It publishes the port
  only after `listen()`, waits 500 ms after accepting so native `connect()` has
  completed, applies abortive close, then exits.

No private key is copied to Android. The runner installs with `-r`, verifies the
approved app-private `main.dol`, never clears application data, and removes the
exact fixture before returning to the selector.

The fresh version-code 7 debug product APK passed with SHA-256
`81b46c904ae2a81ed9b0a2edaa2fc2b4c472b3d70b56dbc10c3cafa69231744b`:

```text
A5 guest TLS IOCTLV fixture handshake=-5 expected=0
A5 guest TLS IOCTLV trusted exchange passed response_bytes=4797 peer_close=-6
A5 guest TLS IOCTLV hostname rejection passed result=-9
interrupted_handshake_recovered=yes private_key_on_device=no game_data_preserved=yes
```

This proves that an interrupted guest TLS process leaves no durable poison for
the following cold process. It does not prove an in-process retry, Wi-Fi or
cellular transition, local WFC protocol recovery, public-service behavior, or
physical-device networking.
