# KartPad future features

This document records credible product opportunities that are not part of the
current release priority. An entry here is not a shipping promise and should
not be presented as supported until its implementation and acceptance gates
pass.

## RetroAchievements

**Status:** Researched; deferred.

RetroAchievements could add community-authored achievements, leaderboards, and
rich presence to the original Mario Kart Wii mode. Mario Kart Wii already has
an active achievement set and a supported PAL disc hash. The feature should be
optional and eventually entered through a `RetroAchievements…` item in the
three-dot menu.

### Recommended reusable design

- Pin an official stable `rcheevos` release as the shared C runtime.
- Provide a small adapter per static-recompilation runtime: console ID, memory
  reads, frame processing, reset/pause state, and imported-game identity.
- Put Apple-specific HTTP, token storage, badge caching, notifications, and UI
  in a reusable Objective-C++ layer.
- Store the returned login token in Keychain; never persist the password.
- Keep credentials per app initially. A cross-app Keychain access group depends
  on consistent signing teams and entitlements and is unsuitable as the first
  sideloaded implementation.
- Expose the menu item only when the client is compiled in. Show whether the
  current game hash is recognized before enabling a session.

### KartPad integration points

- The Wii runtime exposes MEM1 and MEM2 through `Memory::GetPointer`; map the
  official Wii achievement address ranges onto those buffers.
- Call `rc_client_do_frame` once for every emulated frame, not merely every
  displayed frame. Call the idle path while gameplay is paused.
- Hash the user's WBFS/ISO during import, before KartPad removes a temporary
  picker copy, and persist only the resulting hash/game identifier.
- An extracted DATA folder cannot safely reproduce the official encrypted-disc
  hash. Do not infer identity solely from `main.dol`, even though KartPad uses
  that file as one compatibility check.
- Do not identify Retro Rewind as the retail Mario Kart Wii set. Leave
  RetroAchievements disabled for that mode unless its exact hash or a compatible
  subset is officially registered.

### Delivery stages

1. Build a developer-only Casual-mode proof with login, hashing, memory reads,
   per-frame evaluation, and log-only unlock events.
2. Add achievement list/status UI, unlock popups, badge caching, rich presence,
   leaderboards, network error handling, and secure offline retry behavior.
3. Validate retail PAL memory semantics and supported hashes with
   RetroAchievements administrators before public release.
4. Extract the Apple client layer only after KartPad proves the interface; keep
   console and engine mappings in per-project adapters.
5. Consider Hardcore only as a later project. It requires strict reset and mode
   transitions, disabled cheats/rewind/slowdown/frame advance/save-state loads,
   offline queuing, complete UI visibility, a stable unique user agent, privacy
   documentation, and RetroAchievements compliance approval.

### Priority decision

Do not schedule this ahead of current import reliability, lifecycle stability,
performance, physical-device coverage, or production online acceptance. It is a
medium-to-large reusable feature, not a small menu addition.

## DSU / Cemuhook motion controllers on Apple TV

**Status:** Reviewed; deferred for an optional experimental build. Not implemented
or scheduled. This is a product enhancement, not technical debt.

Issue [#91](https://github.com/chrissotraidis/kartpad/issues/91) proposes using a
phone or a controller bridge on the local network for Wiimote-style tilt
steering on Apple TV. The
[maintainer review](https://github.com/chrissotraidis/kartpad/issues/91#issuecomment-5568259122)
found the approach feasible with moderate implementation complexity. DSU input
would map into KartPad's existing Classic Controller controls; it would not
provide Dolphin's full Wii Remote/Nunchuk emulation.

### Recommended first scope

- tvOS only, disabled by default, with manual server address/port entry and
  selection of one DSU pad for Player 1.
- One verified phone app and layout, providing buttons and calibrated tilt,
  with sensitivity, inversion, recentering, and clear connection status.
- Keep a button available for tricks. Validate shake detection separately.
- Defer motion-only pairing with a physical pad, DSU players 2–4, additional
  platform UIs, discovery, rumble, IR, and DSU server mode.

### Integration work and limits

- Parse and validate DSU packets separately from asynchronous UDP reception.
  Keep network work off the game thread, bound sample handling, and clear held
  input on timeout, disconnect, or shutdown. Handle packet reordering, sequence
  wraparound, and server restarts.
- Convert sensor orientation and timestamps, estimate gravity for tilt, and
  separate gravity from acceleration before reusing the shake detector. The
  existing CoreMotion helpers and tests do not establish DSU motion support.
- Extend controller source bookkeeping and reconciliation explicitly; the
  current manager only retains GameController devices. Preserve physical-pad
  assignments and button-edge latching. Do not use a DSU MAC alone as identity,
  since the protocol permits an all-zero value.
- Start the client during tvOS setup so a connected full DSU pad can satisfy
  the gameplay gate before runtime installation. Preserve Siri Remote setup
  navigation and provide recovery when a phone sleeps or loses its connection.
- Verify button mappings for the selected app. DSU carries generic pad fields;
  apps do not necessarily expose the same Wii Remote layout. DSUController's
  documented Wii Remote/Nunchuk setup uses two phones.

Protocol details should follow the
[Cemuhook reference](https://v1993.github.io/cemuhook-protocol/): its controller
payload offsets exclude the first 20 bytes of the packet, analog R2 is at
payload offset 34, and L2 is at 35. Compatibility references include the
[WiiMoteDSU profile](https://github.com/marcowindt/WiiMoteDSU/blob/master/WiiMoteDSU.ini)
and [DSUController guide](https://github.com/breeze2/dsu-controller-guides#faq).

### Acceptance and next decision

Require protocol fixtures, malformed-packet rejection, calibration and motion
tests, and connection lifecycle tests before a hardware trial. Physical Apple
TV acceptance must cover setup, phone-only game-menu navigation, Original and
Retro Rewind races, steering feel and latency under Wi-Fi jitter, phone sleep,
disconnect/reconnect, and coexistence with physical controllers.

The requester has offered Apple TV testing. Confirm their Apple TV/tvOS and
phone/app versions, and whether they want sideways phone steering or a bridged
physical Wii Remote/Nunchuk, before choosing the first compatibility target.
Keep this deferred until separately prioritized; listing it here does not
commit it to the next build or establish hardware support.
