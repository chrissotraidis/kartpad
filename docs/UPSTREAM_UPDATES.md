# Updating WiiCompiled and Retro Rewind

KartPad keeps its Apple host, WiiCompiled base, and Retro Rewind release inputs
as separate, explicit layers. Updating one layer must not require copying or
forking an upstream tree into KartPad.

## Pins and ownership

- `dependencies.lock.json` pins the WiiCompiled source baseline and the Retro
  Rewind Pulsar, WFC patcher, and WFC server references used for implementation
  and local protocol testing.
- `builder/profiles/mkwii-rmcp01-rev0.json` is the single release-input pin. It
  records the Retro Rewind version, official version-feed URL, archive URL,
  byte counts, hashes, expansion limit, `Code.pul`, Riivolution XML, and signed
  production RWFC payload.
- `vendor/wiicompiled` contains the maintained translator subtree.
  `vendor/runtimes/{macos,ios,android,tvos}` pins the maintained runtime forks
  (including Aurora) with Git submodules. Edit these sources and deliberately
  advance their gitlinks; staging scripts do not replay the old patch stack.
  The detached upstream reference and archived patches retain provenance.
  See [source maintenance](source-maintenance/README.md).
- `builder/kartpad_builder/release_header.py` generates the iPhone/iPad
  installer's release constants from the profile. There is no second manually
  maintained version or download URL in the app UI.

## Update loop

Advance one upstream at a time on a dedicated branch.

1. Run `python3 scripts/check-retro-rewind-version.py`. The daily GitHub Actions
   watcher runs the same check and opens one deduplicated compatibility issue
   when the official feed advances beyond KartPad's pinned profile.
2. Run `python3 scripts/update-retro-rewind-profile.py --latest`. The helper
   resumes or reuses the official full archive in ignored private storage, then
   validates the official archive layout and writes the version, URL, byte
   counts, and SHA-256 values for the archive, `Code.pul`, and Riivolution XML.
   An already-downloaded archive can still be supplied explicitly with
   `python3 scripts/update-retro-rewind-profile.py PATH_TO_ARCHIVE OFFICIAL_URL`.
3. Update the relevant lock entry and replace only its detached reference
   checkout. Record the new commit and tree.
4. Validate the production payload signature and its pinned size and hash.
   Never weaken a hash or signature check to accept a new release.
5. Review upstream changes against the maintained translator and each runtime
   fork. Port only reviewed changes to those sources, commit the runtime forks,
   and advance their gitlinks. Stage fresh source with the maintained-source
   scripts and verify it before building. Source-based maintenance does not
   automatically import later upstream commits.
6. Regenerate both the shared base graph and the Retro Rewind graph. Function
   counts and dispatch closure are profile gates, so an upstream change fails
   closed until the new graph is reviewed and pinned.
7. Run builder/unit tests, maintained-source verification, fresh platform prepares, and the
   dual-mode regression: Original boot, Retro Rewind install/boot, mode switch,
   save isolation, controller reconnect, and relaunch.
8. Run the isolated WFC login/race harness. When the production service is
   reachable, separately prove NAS authentication, GameSpy login, matchmaking,
   a live race, results, and clean reconnect before making an online-support
   claim or deploying the candidate for physical acceptance.

At runtime, KartPad compares its pinned version with Retro Rewind's official
version feed before that mode starts. A newer feed entry intentionally blocks
the old app: maintainers must advance the profile, regenerate the translated
graph, validate the new hashes, and ship a compatible KartPad build. Never
silently accept an unpinned `Code.pul` or asset archive merely because its
version string is newer.

This keeps normal updates mechanical: automatic detection, one local update
command, a source pin, regenerated private outputs, and the same acceptance
gates. It cannot eliminate the native rebuild when `Code.pul` changes: that file
contains changed PowerPC program code, and KartPad's no-JIT Apple targets must
translate it ahead of time into a newly signed ARM64 executable. Automating a
public release from GitHub Actions would require placing the user's private game
input or generated retail graph in hosted CI, so KartPad deliberately automates
detection and preparation while retaining the audited local build boundary.
No Nintendo game data, Retro Rewind asset pack, translated retail graph, save,
credential, or local test key belongs in Git or a public artifact.

## Payload-only changes and current review

The production Retro-WFC payload URL is mutable independently of the Retro
Rewind pack version. A fresh download can therefore fail its pin even while
`Code.pul` and the pack archive remain unchanged. Preserve the accepted cached
file on rejection; validate the new payload's size, hash, header and production
RSA signature before promotion. Then translate old and new payloads with the
same translator, review new overlays/continuations, regenerate shards and update
`expectedRetroFunctions` to the measured graph. Regenerate the Android release
contract from the same profile. Do not bypass identity or signature checks.

The [19 September review](artifacts/2026-09-19/cross-platform-stabilization.md)
records the payload fix, local builds, upstream gaps and remaining device gates.
The source migration retained upstream base `1912292c804f`; the checked upstream
head is `83463764b8ac` (114 commits later). That count describes ancestry, not
114 missing fixes: maintained source already includes selected backports.
