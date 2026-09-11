#pragma once
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_scancode.h>
namespace kartpad {
inline bool IsMacSettingsShortcut(const SDL_Event &event) {
  if (event.type != SDL_EVENT_KEY_DOWN || event.key.repeat) return false;
  const auto modifiers = event.key.mod;
  const auto commandModifiers = SDL_KMOD_CTRL | SDL_KMOD_ALT | SDL_KMOD_SHIFT;
  if (modifiers & commandModifiers) return false;
  return (event.key.scancode == SDL_SCANCODE_F10 && !(modifiers & SDL_KMOD_GUI)) ||
         (event.key.scancode == SDL_SCANCODE_COMMA && (modifiers & SDL_KMOD_GUI));
}
}
