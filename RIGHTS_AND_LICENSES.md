# KartPad rights and licenses

## Software license: GNU GPL version 3

KartPad is free software licensed under the **GNU General Public License,
version 3 (GPLv3)**. The full, unmodified license is in the root
[`LICENSE`](LICENSE); [`LICENSES/GPL-3.0.txt`](LICENSES/GPL-3.0.txt) is an identical
copy retained for existing links and packaging. KartPad's own grant is
`GPL-3.0-only`; upstream files that offer additional license choices retain them.

This grant covers KartPad-owned source code, runtime and platform integration,
UI code, build tools and scripts, tests, documentation, original artwork, and
patches, except material with an existing separate license or third-party rights.
It explicitly covers **all KartPad modifications to WiiCompiled**, including
changes distributed as patches or copied/adapted source, and the modified runtime.
KartPad is a modified work based on WiiCompiled, not an upstream WiiCompiled
release. The repository history and patch records identify changes and dates.

The **integrated KartPad application, as a combined work, is covered by GPLv3
where required by the GPL**, including section 5(c). The GPL's scope is not
limited to an unmodified upstream checkout, an individual runtime file, or a
license notice shipped alongside the application. Separate file licenses and
the game-content discussion below do not create a linking exception or waive
the obligations for the combined work.

WiiCompiled is created and maintained by [patchzyy](https://github.com/patchzyy).
KartPad uses revision `1912292c804ff9b1b79938de89369ec4496f9fff`; its
[license statement](https://github.com/patchzyy/Wiicompiled/blob/1912292c804ff9b1b79938de89369ec4496f9fff/README.md#license)
and [GPLv3 text](https://github.com/patchzyy/Wiicompiled/blob/1912292c804ff9b1b79938de89369ec4496f9fff/LICENSE)
are the upstream basis for this coverage. Existing copyright notices,
attribution, license choices, and warranty disclaimers remain applicable.
See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for dependencies.

KartPad is provided without warranty, including implied warranties of
merchantability or fitness for a particular purpose, as described in GPLv3
sections 15 and 16.

## Your GPL rights and the maintainer's release policy

You may run, study, copy, modify, and redistribute the GPL-covered software,
including commercially and for a fee, subject to the GPL's terms. You do not
need separate permission from the KartPad maintainer to exercise those rights.

Terms such as “free community preview,” “personal build,” “private output,”
and release approval describe what the maintainer publishes, supports, or
accepts into this repository. They are **not additional license restrictions**:
there is no noncommercial-only condition, ban on redistribution or forks,
requirement to obtain maintainer approval, or extra license fee for exercising
GPL rights. Store or signing choices do not alter those rights; any distributor
must still comply with the GPL and other applicable rights and obligations.

Earlier release notes and build guidance may describe a limited publication
policy. That language must not be read as restricting GPL rights. This
clarification supersedes any conflicting KartPad policy wording; the GPL itself
governs the covered software. See GPLv3 sections 4, 5, 6, and 10 in [`LICENSE`](LICENSE).

## Corresponding Source and distribution obligations

Distributing GPL-covered binaries requires compliance with GPLv3 section 6,
including access to the complete machine-readable Corresponding Source through
an applicable GPL-permitted method. This includes the source and scripts needed
to generate, install, run, and modify the covered work as defined in section 1,
and Installation Information when section 6 requires it. Preserve required
notices, identify modifications and relevant dates, and provide the license.
Shipping a GPL text or naming dependencies alone does not satisfy this duty.

KartPad's source, patches, dependency pins, and build instructions are available
in this repository. For a published binary, start with its exact release tag
and recorded source commit, then use:

- [`dependencies.lock.json`](dependencies.lock.json) for upstream repositories
  and pinned revisions;
- [`patches/`](patches/), [`runtime/`](runtime/), and [`apple/`](apple/) for the
  modifications and application integration;
- [`builder/`](builder/), [`scripts/`](scripts/), and [`docs/BUILDER.md`](docs/BUILDER.md)
  for the build pipeline, plus [`docs/INSTALL_MACOS.md`](docs/INSTALL_MACOS.md)
  for the macOS source-build workflow.

These are source locations, not a declaration that every existing binary's
Corresponding Source or third-party rights has been exhaustively audited.
A release must provide the complete Corresponding Source required for that
specific binary; an upstream URL or pin is not a substitute for missing source.
Game-content uncertainty does not excuse GPL compliance. If applicable
obligations cannot be satisfied together, the combined binary must not be
conveyed (GPLv3 section 12).

## Game content, trademarks, and published artifacts

On 7 September 2026, after physical Pixel and Razer Kishi gameplay testing,
the maintainer authorized merging Android and publishing its first free Android
community release, `v0.4.10-android.1`. The APK contains compiled ahead-of-time
Original / Retro Rewind logic, not a disc image, extracted retail assets, Retro
pack, saves, private translated source or signing keys. Its public certificate
is not private signing material. The release includes companion notices and
integration source/build instructions in `android/README.md`. This publication
decision is not Google Play approval, a waiver of GPL obligations, or clearance
of game-content rights. All license and Corresponding Source terms above apply.

KartPad is an independent, unofficial community project, not affiliated with
or endorsed by Nintendo. Mario Kart Wii's executable code, game data,
characters, names, imagery, and trademarks remain subject to their respective
owners' rights. KartPad cannot grant rights it does not hold in that material.

The software license does not by itself grant Nintendo permissions or clear
rights in game-derived translated code. Running a GPL-covered translator does
not automatically license every output under the GPL; the output's contents
and relationship to the covered work matter (GPLv3 section 2). This is not an
exemption from GPL obligations for runtime code included in generated output
or for a combined application where the GPL applies.

From 29 September to 3 October 2026, KartPad published only apps without game
code, and players built the game part with PadMint. On 4 October 2026 the
maintainer decided to publish ready-to-play builds again, starting with
v0.7.9: the Android APK, the iPhone/iPad IPA and the Mac app contain KartPad's
ahead-of-time translated game logic (the game pack). The decision rests on how
community static recompilations are handled today, not on a rights clearance.
From v0.7.14 on 5 October 2026, Android retains the ready-to-play APK, while
iPhone, iPad and Mac use PadMint builds from the player's own disc. Releases
include the game-code-free iOS app for PadMint, its recipe, source, notices and
checksums; they no longer include ready-to-play Apple downloads. This changes
distribution, not the license or rights boundaries described above.
Neither the source nor the apps include disc images,
extracted courses, textures, audio, saves, console keys, or private signing
material.
Users supply their own legally obtained supported PAL `RMCP01` revision 0
game data (and, for in-app disc import on iPhone/iPad, their own Wii common
key). The Retro Rewind asset pack is also omitted; the optional
installer downloads and verifies the matching official pack when selected.
Third-party mod content retains its own applicable rights and licenses.

The maintainer's free community-release decision is not clearance of Nintendo
or other game-content rights. Questions about redistributing game-derived
material remain separate from the established GPL license for WiiCompiled,
KartPad's modifications, and the combined work where required. **KartPad's
software is GPLv3-licensed; Mario Kart Wii is not thereby relicensed.**

Personal Builder artifacts and extracted/generated game files stay ignored by
the repository's publication workflow. Warnings about those files concern
private data and game-content rights; they do not prohibit reuse or distribution
of the GPL-covered software under the GPL.
