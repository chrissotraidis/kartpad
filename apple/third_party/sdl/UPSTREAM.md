# SDL Darwin keycode table

`scancodes_darwin.h` is unchanged from SDL 3.4.4, `src/events/scancodes_darwin.h`:
https://github.com/libsdl-org/SDL/blob/release-3.4.4/src/events/scancodes_darwin.h

The zlib license and copyright notice are retained in the file. KartPad's native
Mac remapping panel uses this table and the same hardware ISO correction as
SDL's Cocoa backend so captured AppKit keys match the scancodes the game polls.
It does not use generated text, which changes with the active keyboard layout.
Recheck this table and Cocoa's ISO correction when upgrading SDL.
