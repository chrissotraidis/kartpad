# External display work and device checks

AirPlay and external output on iPhone/iPad, plus Android external output, are
accepted product priorities. This is an implementation and acceptance plan,
not a claim that the current builds support every output path. Apple report
[#100](https://github.com/chrissotraidis/kartpad/issues/100) describes a visible
chooser followed by black video with audio continuing.

## First delivery target

Keep the running game visible through system mirroring. Start with wired
output so the renderer/surface behavior can be isolated, then validate AirPlay
and Android's available wireless mirroring separately. A TV-only game view with
controls retained on the handheld is a subsequent feature with separate input
and surface ownership; it should not block correcting broken mirroring.

| Path | First acceptance |
| --- | --- |
| iPhone/iPad wired mirroring | Chooser → Original → offline race, then Retro; connect before and after launch; disconnect returns usable local video/input. |
| iPhone/iPad AirPlay mirroring | Repeat the same sequence; check video/audio continuity and steering latency separately from wired results. |
| Android USB-C mirroring or desktop window | Record the actual device mode; check launch, display move/resize, game menu and unplug/reconnect. USB-C alone does not establish video-output capability. |
| Android wireless mirroring | Identify the actual receiver/mirroring route and compare the same offline scene; do not infer support from a wired pass. |

Start at 1x/4:3, with Android Renderer Validation off. Use an offline race and
change one setting/connection condition at a time. Record device/OS, app build,
TV/monitor, adapter/cable or receiver, which screen fails, and whether the
handheld, audio and game menu keep responding. A short clip of both displays
is useful; hide notifications and do not include personal identifiers.

## Android emulator check, 8 November (0.8.9 candidate `d60a79da…`)

With Original running on the arm64 emulator, a simulated 1920×1080 external
display (`settings put global overlay_display_devices 1920x1080/320`) was
connected during the title/demo loop. The second display mirrored the game
live, and was still showing current frames 40 seconds later, captured from
that display directly. The phone kept rendering at 60 FPS. After the display
was removed, the game kept running in the same process and kept rendering on
the phone. This covers Android system mirroring on an emulator only; it says
nothing about a real USB-C or wireless receiver, or about iPhone/iPad (#100),
which still needs a device or the Simulator's I/O → External Displays.

## Source findings and next implementation boundary

The Apple game build uses `apple/ios/RuntimeInfo.plist` and SDL's UIKit scene
and Metal-view path. The native shell app delegate alone is not the game
renderer. Its manifest currently declares an application scene, and there is
no KartPad-owned dedicated external game scene. The pinned SDL backend observes
screen connections and sizes its Metal drawable from the view. Those paths need
hardware evidence at the chooser-to-game transition before a fix is asserted.
A dedicated external scene is a separate UIKit role; see
[Apple's external-display scene documentation](https://developer.apple.com/documentation/uikit/uiscenesession/role-swift.struct/windowexternaldisplaynoninteractive).

Android currently renders through a single SDL `KartPadSurface`, with native
locking around create/change/destroy callbacks. There is no KartPad-owned second
presentation surface. First validate this activity as the display/context and
surface change; do not add a second runtime instance. Android's
[connected-display guidance](https://developer.android.com/develop/adaptive-apps/guides/support-connected-displays)
requires handling display changes and resizing. A later separate output view
can evaluate [Presentation](https://developer.android.com/reference/android/app/Presentation)
against the existing renderer's surface ownership.

No external-output fix or physical acceptance is established by this source
review. For this release cycle, an iPhone/iPad candidate must remain local for
owner testing before a formal IPA is published. Each platform needs its own
acceptance; Android or Mac success does not establish iPad support.

## Surface recreation ownership finding

The [bounded recovery audit](artifacts/2026-09-09/external-display-surface-ownership.md)
identified new SDL Metal views replacing the root during surface recreation while
KartPad controls remain on the previous root. Reuse/destruction and control
ownership need a forced-recovery test; display attachment causing that recovery
and TV-only black video remain unconfirmed. This is separate from dedicated
external output and does not authorize a scheduled IPA publication.

The [native recovery correction and tests](artifacts/2026-09-09/apple-metal-surface-recovery.md)
now preserve one Metal view per window. macOS and iPhone/iPad simulator probes
pass repeated descriptor recreation, presentation and teardown, with failing
unpatched controls. tvOS probe compilation also passes. Full-game surface loss
and physical external-output acceptance remain open; this does not close #100.
