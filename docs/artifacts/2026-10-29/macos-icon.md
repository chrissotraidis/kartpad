# macOS icon correction, 29 October 2026

The Mac package contained the old circuit artwork. Its ICNS was last refreshed on September 7 in `e6ea111129a47379aec7945e2098f451b27c3571`; the shared iOS default changed to the red K on September 15 in `4e3c1e1a2d6ac532e9c93162e61fcc92ac05be64`, without regenerating the Mac exports. Android copies that current iOS default during its build.

The retained validated Mac app names `KartPad` in `CFBundleIconFile`. Its bundled ICNS exactly matched the stale repository export (SHA-256 `65ae43cd6bb51eba15f624e60900834bbff9197a4f6d178f94405ac59cdc7fcb`), so the obsolete artwork was demonstrably packaged; this finding does not depend on a macOS icon-cache explanation.

Commit `b176e94e` regenerates the ICNS and seven PNG sizes with the existing `scripts/generate-macos-icon-assets.sh`, using the current artwork. The new ICNS SHA-256 is `86ec8c030723369065c3a206f22b8417e4784dcea08fd787bc0ad00326f08268`. Its decoded 1024px RGBA pixels exactly match the shared red-K master.

The package audit now compares the shared master with the Mac 1024px source export before its existing bundle/ICNS comparison. That new check rejected the stale exports with exit 65 and the regeneration command, then passed after regeneration. Shell syntax, the existing Mac package contract test, and whitespace checks passed.

A separate **icon-only repack**, not a runtime rebuild, copied the retained validated app, replaced its ICNS, and renewed its ad hoc signature. Strict code-signature verification and the full Mac package audit passed. Only the icon and signing files changed; the executable's `__TEXT.__text` bytes remained identical. The original validated app was verified untouched. No installed user application was replaced, and this does not add gameplay or device acceptance beyond the existing validation record.
