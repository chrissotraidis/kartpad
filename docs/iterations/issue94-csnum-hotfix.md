# Issue #94: numeric console serial backport

KartPad's pinned WiiCompiled runtime (`1912292c804ff9b1b79938de89369ec4496f9fff`)
contains the reported bug. `SCGetProductSN_HLE` copies a nine-digit string and
its terminator into a guest output that is a four-byte integer. DWC reads the
first four ASCII bytes as a big-endian number. For example, both `788600001`
and `788699999` become `926431286` and consequently the same `LEH926431286`
CSNum. The write can also overwrite six adjacent guest bytes.

`patches/wiicompiled-sc-serial.patch` backports the helper and override from
[patchzyy's upstream fix e0e362b](https://github.com/patchzyy/Wiicompiled/commit/e0e362bd992e07784f8ce7fa795cdb496af7b075).
The upstream dependency pin stays unchanged; no translator regeneration or
unrelated upstream changes are required. The patch parses the complete decimal
serial, validates the four-byte output and writes through `Memory::Write32`.
It preserves the existing stored console identity, MAC, saves and profiles.

The iOS preparation applies the patch after the existing runtime patch stack,
before the prepare-only exit. tvOS and Android inherit that stack. The macOS
preparation applies it at the equivalent point. Existing prepared runtime
sources and already compiled binaries do not acquire this change automatically:
prepare fresh sources and rebuild the native library before packaging.

## Evidence and limits

- `python3 -m unittest discover -s tests -p test_sc_serial.py -v` compiles the
  actual pinned override before and after patching with AddressSanitizer and
  UndefinedBehaviorSanitizer. The old function fails; the fixed function passes.
- The same harness reproduces the two colliding old outputs, verifies distinct
  corrected outputs, leading zeros, guest byte order, adjacent-memory canaries,
  malformed serials, null output and undersized output.
- The full iOS dual runtime preparation accepts the backport on a fresh copy.
- Server reference `Retro-Rewind-Team/wfc-server` at
  `fbd30fa41a35fe8a407e3a49bc83fe4ff91fd35b`, `database/login.go`:
  `SearchUserBan` matches overlapping CSNum arrays. This establishes the risk
  of collateral bans; it does not establish that particular users were banned
  or that the production server currently runs this exact revision.

## Existing online profiles

The server's `handleCsnum` appends a new serial to an existing profile and keeps
historical values. Correcting the client therefore does not erase a previously
stored, shared CSNum or reverse an existing ban. Its `SameIPAddress` policy can
also reject an identity change from a different IP. Affected existing accounts
may require service-admin correction of the erroneous historical CSNum and
review of any collateral ban. Do not wipe saves, regenerate console identities,
or create replacement accounts as a workaround.

Host regression and patch replay are not a production-service login test or
proof of corrected release binaries. Android release coordination is holding
publication for a native rebuild and package verification with this backport.
