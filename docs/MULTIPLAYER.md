# Multiplayer and controllers

Open **••• → Multiplayer…** on iPhone/iPad, **Controls → Multiplayer…** on
Mac, or **Multiplayer…** on the Apple TV game chooser. The menu covers
Original Mario Kart Wii and Retro Rewind; available online guidance depends on
the game profile. Apple mobile menu names below follow 0.4.10 and later.

## Local split-screen

Pair each controller in the operating system, select Multiplayer in the game,
and press the mapped A button on every pad at Register Controllers. iPhone/iPad
Controller Setup lists the four stable player slots and offers face-button
remapping. Touch shares Player 1 with the first physical controller. Disconnecting
a controller leaves the other players in their existing slots.

Issue #85 was caused by WPAD's connection probe consulting keyboard slots while
KPAD input reads also consulted Apple's physical controllers. The probe now
checks the same physical slots without consuming registration button presses.
The callback also samples immediately instead of adding another asynchronous
read that could lose a short press. The regression fixture fails against the
0.4.8 prepared source and passes after the patch. Apple snapshot-controller tests
cover four slots, repeated connection probes, short A presses, disconnect and
reconnect. These tests do not establish a physical three-controller race.

## DualShock and DualSense

DualShock 4, DualSense and DualSense Edge can pair with supported Apple devices
using [Apple's pairing instructions](https://support.apple.com/en-us/111100).
KartPad's Apple mobile input bridge accepts Extended Gamepads, including these
controller families. The default positions are Cross = A, Circle = B,
Square = X and Triangle = Y. Customize Face Buttons changes those assignments;
the D-pad, sticks, Menu and triggers remain direct. Mac uses its existing SDL
controller setup. Pairing and gameplay with each exact model remain hardware
checks, separate from the snapshot-controller regression tests.

## GameCube controllers on iPad

A GameCube-shaped controller or adapter can use this path **if iPadOS exposes it
as an Extended Gamepad**. An original GameCube controller plugged into a
Nintendo/WUP-028 USB adapter is not supported by KartPad's current iPad input
bridge. This update does not add a raw USB GameCube adapter driver. The original
controller, an adapter's operating mode, and a Bluetooth GameCube-style pad are
not interchangeable support claims.

## Private friend rooms

In iPhone/iPad 0.4.10, **Retro WFC Friend Rooms…** is shown only for Retro
Rewind. Its friend-room flow lives inside the game: **Nintendo WFC → Friends**.
Everyone must use matching Retro Rewind content and a compatible online service.
After a successful service login, exchange friend codes, create a room, and
join through the friend roster. Exact production login and races still need
acceptance for the distributed KartPad build.

Original Nintendo WFC is closed. Original Mario Kart Wii's Multiplayer menu
therefore has no private friend-room instruction action in 0.4.10. The
experimental server setting below does not restore that service by itself.

This is different from MeleePad's Dolphin/ENet synchronized-input rooms.
MeleePad room codes, native host/join controls, traversal, ready state and peer
chat have **not** been ported. A shared menu does not establish that parity.

## Experimental private Wii-server routing

**Experimental Server Settings…** on iPhone/iPad 0.4.10 saves a hostname or
IPv4 address for the next launch. The older Apple builds label it **Private
Wii Server…**.
Quit/fully close and reopen KartPad after saving or restoring the default.
The launch-time route is shared by both game profiles. This is a client route,
not a server installed or hosted by KartPad, and is not a room-code service.

Only game DNS names below `nintendowifi.net` and `play.rwfc.net` are redirected.
Content downloads and peer IP addresses keep their original destination. The
explicit private service uses the legacy plaintext Wii WFC protocol; unrelated
TLS requests retain their normal certificate validation. Use a service you
trust. The setting does not weaken server-side authentication.

A compatible backend must implement the game's NAS authentication, GameSpy
presence/friends/matchmaking, NAT negotiation, and race services. Standard service
ports must be available, including the initial logical HTTPS connection on 443
and legacy HTTP on 80. A generic web server or another player's app IP is not
sufficient. A backend requiring a downloaded PowerPC patch or a different
signature/payload is not automatically compatible: KartPad does not compile or
execute new downloaded game code. In particular, entering a WiiLink/Wiimmfi
address alone does not establish Original Mario Kart Wii compatibility.

The new routing path has host validation, destination-scope and compiled Apple
transport coverage. Login, a hosted/joined friend room, complete races and
reconnect on an exact compatible backend still require acceptance, especially
for Original Mario Kart Wii. Do not describe this setting as verified private
online gameplay or MeleePad parity.

## Android and Razer Kishi

The first Android release, `v0.4.10-android.1`, includes the shared Multiplayer
settings and Android SDL controller path. The maintainer accepted Original
Grand Prix play with Razer Kishi on Pixel 9 Pro XL and confirmed automatic touch
hiding. Retro Rewind Retro WFC login, worldwide matchmaking and live race play
were also owner-reported. Rumble, reconnect, multiple physical pads and complete
online results/reconnect are not established by that session. See
[Android installation and controls](INSTALL_ANDROID.md).
