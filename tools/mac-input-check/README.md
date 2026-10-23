# Mac input check

Checks that a controller assigned to player 1 reaches the game while player 1's
keyboard bindings are active, which KartPad turns on at every game start. It
uses an SDL virtual gamepad, so no physical controller is needed.

```sh
tools/mac-input-check/run.sh /path/to/abseil-cpp-src /path/to/fmt-src
```

Both sources are in any runtime build's `_deps` folder. The check prints
`PASS` and exits 0, or names what was ignored and exits 1. Before the macOS
runtime fix it fails with A and the stick reading 0.

