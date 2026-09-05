# Android A5 native TLS primitive

Date: 2026-09-05

## Outcome

Android now has a hash-locked, maintained native TLS dependency path. KartPad
uses the official Mbed TLS 4.1.1 release archive at 7,099,934 bytes and
SHA-256
`3359a349e23db3d5536fcee032ae7b2ecbfc08972fab643089b5cbf2a375c98c`.
This replaces the unsuitable option of reusing Dolphin's historical Mbed TLS
2.28.0 snapshot for new Android networking code.

The ARM64 source fixture initializes the Mbed TLS 4 PSA crypto provider on
Android, obtains 32 bytes from its native entropy path, configures a stream
client with `MBEDTLS_SSL_VERIFY_REQUIRED`, creates the SSL context, and assigns
a hostname for future certificate-name verification.

## Emulator evidence

The visible API 36 ARM64 Pixel Tablet emitted:

```text
A5 native TLS primitive passed version=Mbed TLS 4.1.1 entropy_bytes=32 verify=required
```

The exact source-fixture APK SHA-256 is
`37e2ec9876a3e27d1914f2f8a9bdd527683dff057eb862ac2353d500d0a7983d`.
Its package/privacy audit passes after applying reproducible file/macro prefix
maps to all Mbed TLS sources. The audit permits only the exact parser delimiter
cardinality contributed by the linked TLS archives; it still rejects an added
private-key block.

## Product regression build

The complete translated dual-runtime APK rebuilt successfully with the new
dependency graph. Its final audited SHA-256 is `56fd0ea5760f83df6240248ebb4c1a53bdf2d7e0d507fad4486d5627dd7986c0`. Android
lint, 92 tests with one intentional skip, repository safety, shell syntax, and
whitespace checks pass.

## Classification

**Pass for dependency provenance, ARM64 compilation, Android native entropy,
required peer-verification configuration, SSL-context construction, and strict
fixture packaging.** This does not yet prove `/dev/net/ssl` integration, CA
loading, hostname-failure behavior, a TCP/TLS handshake, or WFC connectivity.
Those are the next A5 slices. No APK, AAB, key, or private artifact was
published.
