# Android A5 guest TLS backend

Date: 2026-09-05

## Outcome

Android's translated `/dev/net/ssl` path now owns a native Mbed TLS 4 backend
instead of returning the platform's unsupported `SSL_ERR_FAILED` result. The
backend consumes the guest-provided DER root CA, requires peer verification,
sets the requested hostname for certificate-name verification, attaches to the
runtime's existing socket, and preserves the guest service's nonblocking
read/write result values.

The change is applied to every freshly prepared WiiCompiled Android source tree
by `patches/wiicompiled-android-network-tls.patch`. The shared implementation is
in `runtime/src/hle/net/android_mbedtls.cpp`, and both the source fixture and
translated product link it against the pinned Mbed TLS 4.1.1 dependency.

## Deterministic TLS evidence

The host-local fixture creates a one-run CA and server certificate under a
temporary directory, serves an encrypted HTTP response on loopback, and removes
the private key without putting it in an APK or the repository. It passed both
the trusted and wrong-hostname cases:

```text
PASS trusted handshake and encrypted HTTP bytes=4096
PASS hostname rejection result=-9
Android Mbed TLS local fixture passed.
```

The ARM64 source APK then ran the same backend against a temporary OpenSSL
server through the Android Emulator's `10.0.2.2` host bridge. The visible API 36
Pixel Tablet emitted:

```text
A5 TLS loopback trusted handshake passed response_bytes=4096
A5 TLS loopback hostname rejection passed result=-9
```

The source-fixture APK SHA-256 is
`2deb2e52d1c980680285c910f43187c117a9bb05a880f5ef97f14efb7e56564b`.
Its strict package/privacy audit passes. The temporary test key was never copied
to the device or package; only its public CA certificate entered app-private
fixture storage, which was subsequently replaced with the production app.

## Product evidence

A fresh preparation reproduced the patched `network_ssl.cpp` byte-for-byte, and
the complete dual translated runtime compiled and linked with the guest TLS
backend. Its strict package/privacy audit passes at APK SHA-256
`c978ef4619cb59756854460f992c19a2c4da99ebcb6e080eba96b4905eedc9f2`.
That exact product was installed over the fixture, and the visible Pixel Tablet
returned to the production Original/Retro Rewind selector.

## Classification

**Pass for Android ARM64 TCP/TLS exchange, required CA and hostname
verification, wrong-hostname guest-result classification, reproducible runtime
patching, and product compilation.** The emulator fixture exercises the exact
backend but does not route a retail guest IOCTLV request through a live WFC
server. Built-in Wii CA/client-certificate handling, local WFC, public WFC,
network interruption recovery, and physical-device acceptance remain open. No
APK, AAB, key, or private artifact was published.
