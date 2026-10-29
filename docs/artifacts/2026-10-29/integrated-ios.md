# Integrated iPhone build and clean PadMint check, 29 October 2026

The normal iPhone application build and a clean player build both passed with the new runtime pins. This is build and packaging validation; no physical iPhone/iPad launch or gameplay is established by it. Nothing was published.

## Source and normal app build

The clean KartPad source was `c3829dfcf478fec8d57dcb1e63f01f21964d247b`; the iOS runtime was `88f6e999ce79f47a3ad17fbe82fae072becdb9e8`. All five source dependencies were clean. The [iOS runtime PR #12](https://github.com/chrissotraidis/wiicompiled/pull/12) and the other three platform runtime PRs are now merged; their exact pins remain unchanged in KartPad.

`scripts/build-ios-app.sh` completed the normal CMake/provenance and Xcode route. Its first attempt stopped at the missing local SunPad reference prerequisite, before compilation. Restoring the pinned reference (`e43f0ea`) and verified Dawn iOS archive allowed the normal build to complete. The repository app audit passed.

| Receipt | Value |
|---|---|
| Source-input hash | `63e52f1737d1cba6a2890a81a8c64188d8a935cd928237901b02344551d50800` |
| Prepared-runtime hash | `f1a4593448f571972bb643ed418037b8afcadbedcf51bee4221b240ae15819d8` |
| Base IPA SHA-256 | `2ba846515b6bc4b62fd3c2d36676214bb2c1accce797234887466c6cbd07d4e2` |

Current-main PadMint audited this base IPA successfully, with **zero address-named functions**. This is the application without translated game code, suitable for the existing PadMint input route after the remaining release gates.

## Clean player route

Ran the unmodified `scripts/player-check.sh` from clean PadMint main `d6f0f59`, using Apple's Python **3.9.6**, an empty PadMint folder, the clean KartPad checkout and the freshly built base IPA. The private original disc image remained local. The run completed in approximately **704 seconds**, with exit 0 and `checkout_check: before-record-passed`.

The backend translated and compiled the player's game pack and passed the pack-state check, with one explicitly allowed lookup cache. Pack fingerprint: `9b2a33ed804c7c3efa9c334d9d77a91ee9a6ce8917446b3365df7cb75ca5275c`.

The resulting personal IPA has SHA-256 `3fc3528623c0e21b709c7c82f4a98780eb8e0eb7b60cc92937d65bfd2072fb53`. All **22 original base-payload files remained byte-for-byte unchanged**; the only added payload file was `Frameworks/libkartpad_game.dylib`. Its minimum iOS version is 16 and its startup scene is declared. Runtime launch is explicitly untested.

As expected for a private player build, the personal IPA **fails the publication gate**: 29,064 address-named functions and the translated-program section marker in the added game library. This is not an audit pass for a distributable Apple IPA. Only the no-game-code base IPA above passed that audit.

## Retention and remaining gates

The private base app/IPA, personal IPA, fresh extracted game data and receipts are retained in the task's ignored `private/triage-20261029/integrated-ios/` directory. Retention verified 2,043 game-data files by hash. Receipts include the build provenance, PadMint record and backend log, CMake/Ninja inputs, pack-symbol check and retention manifest. After checking that no process used it, the completed disposable player-check source clone was removed; retained artifacts and the original disc were preserved.

The later Android relative-output-path wrapper correction does not change this iOS binary. Any final release still needs its own clean-source player check, package audits and the owner's publication instruction. Apple live bloom/gameplay, physical controller behavior and the outstanding device-specific graphics reports remain open.
