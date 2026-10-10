# Agent instructions

## Where to start

**What we're doing next:** [docs/CURRENT-LOOP.md](docs/CURRENT-LOOP.md), whose
first section answers it in three lines. Released state:
[docs/STATUS.md](docs/STATUS.md). Performance work (#339, slow
phones): [docs/ANDROID-PERFORMANCE-HANDOFF.md](docs/ANDROID-PERFORMANCE-HANDOFF.md).

## Releases

**Current distribution (from v0.7.14, 5 October 2026):** Android keeps the
KartPad-only ready-to-play exception. iPhone, iPad and Mac are built through
PadMint from the player's own disc. This supersedes the 4 October v0.7.9–0.7.13
asset list; see the published v0.7.14 notes and README.

Each release, at the version in `version.json`, publishes:

- `KartPad-v…-android.apk`: the Android app with the matching game pack built in,
  signed with the existing Community Release key.
- `KartPad-v…-ios-for-padmint.ipa`: the iPhone/iPad application without translated
  game code, for PadMint to combine with the player's own build.
- `KartPad-v…-padmint.json`, source archive, notices archive and `SHA256SUMS`.

Do not add ready-to-play Apple IPAs or Mac app downloads unless the owner
explicitly changes this distribution decision. Personal Apple test builds stay
private. Keep candidate releases as drafts until their acceptance gates and the
owner's final publication instruction are satisfied.

The game pack must match the app's pack fingerprint. Never publish disc data, extracted game files, saves, console keys or signing material. This exception is for KartPad only; other Pad projects still publish through PadMint.

Before any public release, every artifact must pass the repo's own APK/IPA audits, and `python3 -m padmint audit <artifact>` may flag the documented translated-code findings only in the ready-to-play APK (address-named functions and the embedded data-section marker; see RELEASE-CHECKLIST). Source-scanner hits must be traced to the exact tracked translator source or synthetic tests and recorded; never suppress findings to obtain a pass. Any key, disc or private-path finding is a stop. The Android build must reach a race on an emulator or device, both as an update over the previous release and as a fresh install with a first-launch game-data import. A failure is a stop, not a note.
