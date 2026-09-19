# SunPad mobile overlay snapshot

This directory began as a verbatim source snapshot of the touch interface component
and its direct settings/input dependencies from the user-supplied SunPad
reference at commit `e43f0ea6b797e5110787171957c9dc3c6213269c`.

Upstream paths:

- `apple/ios/SunPadGameOverlay.h`
- `apple/ios/SunPadGameOverlay.mm`
- `apple/shared/SunPadInputState.h`
- `apple/shared/SunPadInputMixer.h`
- `apple/shared/SunPadInputMixer.mm`
- `apple/shared/SunPadSettings.h`
- `apple/shared/SunPadSettings.mm`
- `apple/shared/SunPadDiagnostics.h`
- `apple/shared/SunPadDiagnostics.mm`

The snapshot retains SunPad's names and behavior deliberately. KartPad-specific
adaptation belongs outside this directory so the direct-copy baseline remains
byte-verifiable. SunPad is licensed under GNU GPL version 3; the license text is
at `LICENSES/GPL-3.0.txt`. KartPad modifications derived from this component
must remain clearly identified and GPLv3-compatible.

Snapshot SHA-256 values:

```text
161200ac2815d18366fff3b726e7aec1e8c9b0839c4266e211c5bebbce1fbe54  SunPadGameOverlay.h
4d7cd4192e846430c2bed0737956b859cf03f52424617fa5b7bd470d5a6bfa4b  SunPadGameOverlay.mm
63e46d5eade0516fd16f1a852dfd4cf67a65c6ab10e08bf9f5794957e4700bd7  SunPadSettings.h
647bdec3a60e1ff8b5a95ba6f7034ff80dae84bcaea9c8514d23f80ade19cd4c  SunPadInputMixer.h
67ecd1014f32e4e81573baeb5819b438eb5ebaf4fd1dc3d79169da9a6f71e4d9  SunPadInputState.h
6ee9d671db17961676f71d0da3a80c4b9ea2d9de2aecf11c2041bc593faaa33b  SunPadInputMixer.mm
d2cbfc15605ccf9b44303a02cef0f36a877deedd2ddba8bad84a03a4625f9c40  SunPadSettings.mm
d7b899d43cafd5ee4a77b3c113339676bacdd3e712719575f802459e285800b1  SunPadDiagnostics.h
89560621c658387de44711c2d69eb89aca3eceeb8fec94ff8e26ea7424cb6be3  SunPadDiagnostics.mm
```

## Maintained KartPad adaptations

`SunPadDiagnostics.mm` adds lifecycle/thermal breadcrumbs (commit `221caaf`).
`SunPadControllerMapping.h` and `.mm` contain KartPad controller mapping changes.
These three files are no longer verbatim upstream copies. The snapshot verifier
checks their pinned SHA-256 values and still compares the remaining files with
the original SunPad commit. The diagnostic candidate does not change their bytes.
New diagnostics live in `apple/ios/KartPadSystemDiagnostics.mm`.
