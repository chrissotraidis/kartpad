# Android A5 guest TLS same-process recovery

Date: 2026-09-05

Branch: `codex/android-a4-touch-settings`

Parent commit: `5f89f20`

Classification: **Pass for translated guest TLS session recovery inside one
Android process on the API 36 ARM64 emulator.** Network transitions, WFC, and
physical-device networking remain open.

## Subgoal

Strengthen the cold-process interruption checkpoint. After a deterministic
peer reset during TLS negotiation, KartPad must shut down the failed guest SSL
session, clean the Wii/native socket table, create a new session, and complete
the trusted exchange without restarting the application process.

## Implementation

The opt-in `RunAndroidTlsIoctlvFixture` reads an optional `recovery_port`. If
the primary expected-success handshake fails, it:

1. invokes the production guest `SSL_SHUTDOWN` path;
2. runs `CleanupAllWiiSockets()` and restores the guarded guest scratch region;
3. selects the trusted recovery port through a bounded thread-local recursion
   guard;
4. creates a new guest SSL session and Wii socket through the same production
   IOCTLV handlers; and
5. requires the complete verified response and orderly peer close before
   reporting recovery.

The recursion guard prevents retry loops. A failed recovery returns failure to
the product fixture; hostname-rejection cases do not enter recovery.

## Runtime evidence

A fresh complete dual-runtime preparation reproduced the updated fixture and
the Android 10 Vulkan compatibility patch. The exact marker was verified in
packaged `libmain.so` before installation. The strict-audited version-code 7
debug APK has SHA-256
`a5a09e08b0374810566181b59fe19d88572e2303b4327f40320dfbcedb1556dd`.

The visible API 36 Pixel Tablet emitted, in one fixture invocation:

```text
A5 guest TLS IOCTLV fixture handshake=-5 expected=0
A5 guest TLS IOCTLV trusted exchange passed response_bytes=4797 peer_close=-6
A5 guest TLS IOCTLV same-process recovery passed result=-5
A5 guest TLS IOCTLV hostname rejection passed result=-9
same_process_handshake_recovered=yes private_key_on_device=no game_data_preserved=yes
```

The runner removed its exact trigger, destroyed both ephemeral host peers and
all private keys, preserved the approved app-private game data, and restored
the production selector. Temporary prepared source was deleted. No APK or
private artifact was published.

This is a controlled guest TLS session/socket recovery result. It is not a
Wi-Fi/cellular transition, DNS/NAT impairment test, local WFC exchange, retail
Mario Kart reconnect, or physical-device result.
