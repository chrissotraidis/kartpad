#include "kartpad/macos_settings_shortcut.hpp"
#include <cassert>
int main() {
 SDL_Event e{};e.type=SDL_EVENT_KEY_DOWN;e.key.scancode=SDL_SCANCODE_F10;
 assert(kartpad::IsMacSettingsShortcut(e));
 e.key.repeat=true;assert(!kartpad::IsMacSettingsShortcut(e));e.key.repeat=false;
 e.type=SDL_EVENT_KEY_UP;assert(!kartpad::IsMacSettingsShortcut(e));e.type=SDL_EVENT_KEY_DOWN;
 e.key.scancode=SDL_SCANCODE_COMMA;assert(!kartpad::IsMacSettingsShortcut(e));
 e.key.mod=SDL_KMOD_LGUI;assert(kartpad::IsMacSettingsShortcut(e));
 e.key.mod=SDL_KMOD_RGUI|SDL_KMOD_CAPS;assert(kartpad::IsMacSettingsShortcut(e));
 e.key.mod=SDL_KMOD_GUI|SDL_KMOD_ALT;assert(!kartpad::IsMacSettingsShortcut(e));
 e.key.mod=SDL_KMOD_CTRL;assert(!kartpad::IsMacSettingsShortcut(e));
 e.key.scancode=SDL_SCANCODE_RETURN;e.key.mod=SDL_KMOD_ALT;assert(!kartpad::IsMacSettingsShortcut(e));
}
