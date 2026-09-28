# Agent instructions

## Releases paused

No public releases until this repo is marked Clear in the maintainer's private release audit. Do not publish, re-publish, or restore any release, IPA, APK, or macOS build, and do not add download links, until then.

Before any future public release, every artifact must pass `python3 ~/.codex/release-gate/release_gate.py <artifact>` on the maintainer's machine. A failure is a stop, not a note.
