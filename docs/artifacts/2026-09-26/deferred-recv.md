# Deferred blocking TCP receive (2026-09-26)

## Problem

On a Pixel running Retro Rewind online (build code 227), the game thread froze for
230–1,200 ms about every 5 s. Logcat showed
`KartPadNetStall: operation=socket_ioctlv command=12`, which is IOCTLV_SO_RECVFROM.
The direct handler (`network_socket.cpp`) handles a logically blocking TCP receive
with nothing readable by calling `WaitForReadable` → `poll()` for up to 5,000 ms on
the emulation thread. Sync and async `IOS_Ioctlv` both reached that handler, so
every guest thread and frame production stopped for the whole wait. See
`android-second-review.md` (2026-09-25).

## Change

`network_deferred.cpp` now parks receives the same way it already parks blocking
`SO_CONNECT` and `SO_POLL`:

- `Network_HLE_StartIoctlvSync/Async` claim `IOCTLV_SO_RECVFROM` on `/dev/net/ip/top`
  only when the direct handler would have waited. That means a stream socket, no source-address
  vector (or one under 8 bytes), not guest-nonblocking, no `0x04` force-nonblocking flag,
  and a zero-timeout poll that shows nothing readable.
  Everything else returns NotApplicable and runs through the unchanged direct handler.
  This includes malformed vectors, route setup failures, data that is ready now, UDP, and
  receives that ask for a source address. Those requests produce the same results as before.
- A parked sync caller sleeps on its IOS wait queue. An async caller gets its callback later.
  A 5,000 ms deadline is recorded, taken from `StreamReceiveWaitMilliseconds`.
- Each scheduler pump (`Network_HLE_ProcessCompletions`) runs a zero-timeout readability
  probe. The operation settles on readable, EOF, error, deadline, or socket identity change.
  The `recvfrom` and the guest-buffer write run on the emulation thread. Results use the same
  `SocketResult` / `SocketErrorResult` mapping and `lastLoggedRecvError` NetFail reporting
  as the direct path.
- At the deadline the receive still runs once. Data that arrived in time is returned;
  otherwise the guest gets the same would-block result as before (`-SO_EAGAIN`).
- If the Wii socket is closed or its slot is reused while parked, the result is `-SO_ENOTCONN`.
  Dolphin uses this result for operations still pending when a socket closes. The old
  code could not hit this case, because nothing else ran during its blocking wait.
- If a sync waiter is cancelled, its parked receive is dropped, as with parked polls and connects.

Commits (local, not pushed; root gitlinks not updated):

- Android runtime `codex/android-input-menu-20260926`: `c5ad680` (on top of `f7347f4`).
- iOS runtime `codex/ios-menu-stall-20260925`: `cbe43de`. The iOS change is the same, and it
  also makes `TraceWfcTcp` visible to the deferred completion so that
  `KARTPAD_WFC_TRACE=1` still traces parked WFC receives.

## Verification

- Android: compiled the `unity_network_ios_cxx` unit with the exact NDK 29.0.14206865
  command from `android/app/.cxx/RelWithDebInfo/3w515k5m/arm64-v8a/compile_commands.json`,
  substituting the new `network_deferred.cpp`. It compiled cleanly with no warnings.
- iOS: ran `-fsyntax-only` for arm64 against the iphoneos SDK on `network_deferred.cpp`,
  `network_socket.cpp`, and `network_core.cpp`. There were no errors, and only existing
  warnings.
- New `scripts/test-deferred-receive.py <runtime>` extracts the receive functions and the
  pump loop from the runtime source, then drives them over real loopback TCP. It covers park
  when empty, a pump under 50 ms with no delivery, completion with the guest bytes written, and
  NotApplicable when data is ready, the socket is nonblocking, forced nonblocking, has a
  source address, is UDP, the fd is unknown, or route setup fails. It also covers expiry to
  `-SO_EAGAIN`, data winning at the deadline, the default 5 s deadline, close to
  `-SO_ENOTCONN`, cancelled waiter drop, and peer EOF to 0. It passes for both
  runtimes, eight Android runs in a row. A mutation that gives the probe a 200 ms poll fails it.
- `scripts/test-network-receive-semantics.py` still passes for iOS. For Android it fails
  before and after this change, because its stub declares `fd` for the iOS-only
  `TraceWfcTcp` and `-Werror` rejects the unused variable. The direct handler it
  tests was not modified.

No device, emulator, or Retro Rewind session was run.

## Risks

- Latency: a parked receive completes on the next scheduler pump, not the moment data
  arrives. Blocking connects and polls already work this way. If the pump runs rarely
  while every guest thread sleeps, NAS/HTTP replies could arrive slightly later. That is
  still far better than freezing the whole emulation thread.
- The pump now runs one zero-timeout `poll()` per parked receive. Usually zero or one
  receive is parked.
- Guest-visible behavior changes in one way: during the wait, other guest threads run and
  frames continue. Guest code that assumed the receive froze the world is not expected. On
  real IOS the receive blocks only its caller.
- Whether the Pixel stalls stop still needs a device run. Watch that
  `KartPadNetStall command=12` disappears and that NAS login, matchmaking, and races
  behave as before.

