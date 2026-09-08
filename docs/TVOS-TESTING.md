# KartPad Apple TV bring-up test

An externally built cache-root candidate has reached playable Original Mario
Kart Wii and Retro Rewind on physical Apple TV 4K hardware. The exact public
[`v0.4.11-tvos.1`](releases/v0.4.11-tvos.1.md) compiler-hardened build still needs a signed-container retest. Treat it as an
engineering bring-up build, not a supported release, and do not rely on its
purgeable local storage for valuable saves.

## What the tester needs

- Apple TV running tvOS 17 or later, paired with a Mac through Xcode Device Hub.
- An Extended Gamepad paired with the Apple TV. The Siri Remote is setup-only.
- The exact signed KartPad candidate and its executable SHA-256.
- A personally owned PAL `RMCP01`, revision-0 extracted `DATA` directory.
- This repository's staging and diagnostic scripts.

Never upload or attach the game data, Retro Rewind files, saves, signing
identity, provisioning profile, device identifier, or complete app container to
an issue.

## Install and stage data

Install the signed candidate using Xcode Device Hub or Apple Configurator. Do
not uninstall an existing KartPad build unless its `Library/Caches/KartPad`
state has been backed up first. tvOS may purge this directory under storage
pressure even when the app remains installed.

The repository scripts default to the `dev.kartpad.tv` app container. If the
candidate was signed with a different bundle identifier, set it before any
build, staging, backup, or diagnostic command in that shell:

```sh
export KARTPAD_TVOS_BUNDLE_IDENTIFIER=com.example.kartpad.tv
```

Stage the private extracted data from the Mac:

```sh
./scripts/stage-tvos-game-data.sh /absolute/path/to/DATA "Apple TV name"
```

The script rejects incomplete data, the wrong disc ID or revision, an invalid
Wii header, and a mismatched `main.dol` before transferring anything.

## Test in this order

1. Launch once without staged data. Confirm that KartPad shows the missing-data
   screen and Retry button instead of crashing.
2. Stage the data, choose Retry, and confirm that Original and Retro Rewind are
   both offered.
3. With no Extended Gamepad connected, choose Original. Confirm that gameplay
   is blocked and the controller screen remains operable with the Siri Remote.
4. Pair the controller, start Original, complete one race, exit normally, and
   relaunch.
5. Choose Retro Rewind. Allow the official download, hash verification, and
   installation to finish; then complete one race and relaunch.
6. Exercise controller disconnect/reconnect and Apple TV sleep/wake.
7. Create a small save change, relaunch, and confirm that it survives.
8. If the first controller succeeds, add controllers one at a time and record
   the two-, three-, and four-player slot behavior.

Stop after the first failure. Do not repeatedly reinstall or delete the app;
collect the evidence while the failing container is intact.

## Collect a report

Run:

```sh
./scripts/collect-tvos-diagnostics.sh "Apple TV name" /absolute/path/to/new-diagnostics
```

Review the collected text files before sharing them. Report:

- KartPad executable SHA-256;
- Apple TV model and tvOS version;
- controller model and connection type;
- installation/signing method;
- Original or Retro Rewind;
- the last numbered step completed;
- what appeared on screen and whether the app stayed open; and
- the path-redacted diagnostic logs.

For a successful pass, also record approximate race duration, video/audio
problems, controller latency or dropped input, and whether save/relaunch and
sleep/wake succeeded.
