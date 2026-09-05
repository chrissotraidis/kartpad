# Android A5 translated guest DNS IOCTL

## Scope

Prove on the Android product runtime that a Wii `SO_GETHOSTBYNAME` request can
be copied from guest memory, resolved by the production deferred DNS worker,
and encoded back into the Wii `hostent` layout. This is a deterministic native
DNS primitive, not a Retro WFC login or local-race result.

## Implementation

- Added an opt-in app-private `KartPadDnsIoctlFixture` trigger. With no trigger,
  the release-present hook is a no-op.
- The fixture opens the production `/dev/net/ip/top` device and enters
  `StartScalarDeferredIoctl` with `IOCTL_SO_GETHOSTBYNAME`; it does not call the
  host resolver directly.
- A fixture-only completion route reuses the production request validator,
  guest-string copy, detached DNS worker, address normalization, and
  `ApplyDeferredDnsCompletion` result encoder without fabricating an IOS
  callback before the guest scheduler starts.
- The bounded timeout cancels its token so a late worker cannot write into
  restored guest scratch memory.
- The emulator runner reinstalls in place, requires the approved app-private
  game fixture, scans only transcript bytes from the current launch, deletes
  the trigger, and restores the two-game selector.

## Evidence

- Fresh dual-runtime preparation applied the complete patch stack, including
  `wiicompiled-android-dns-ioctl-fixture.patch`, with no rejection.
- The complete final ARM64 translated product built successfully in 9 minutes 26
  seconds.
- On the visible API 36 ARM64 Pixel Tablet emulator, guest input `localhost`
  resolved to `127.0.0.1`, and the product reported:

  ```text
  A5 guest DNS IOCTL fixture passed request_marshaled=yes worker_resolved=yes guest_hostent=yes
  ```

- Exact debug APK SHA-256:
  `5bf5018de8d8e8c2b59dfaf381bdade5668c40a890f483ca248f81ca5e244411`.
- The same APK then repeated the existing translated guest TLS interruption,
  same-process recovery, trusted exchange, orderly close, and hostname-
  rejection fixture successfully.
- The strict APK audit, 109-test suite with one intentional skip, all 493 patch
  hunks, pinned source/input verification, SunPad snapshot, shell lint,
  repository safety, and whitespace checks pass.
- App-private game data remained present. No private key, private game data,
  raw transcript, device identifier, APK, or AAB was committed or published.

## Classification

**Pass for deterministic translated guest DNS request/worker/result-marshalling
on the Android emulator.** The fixture uses the real product DNS machinery but
is invoked before the retail guest starts. Retro-WFC hostname routing, a local
WFC server, retail guest initiation, DNS/network transitions, cross-client
play, and physical-device networking remain open.
