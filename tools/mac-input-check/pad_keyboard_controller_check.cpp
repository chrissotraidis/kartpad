// Host check: a controller assigned to player 1 is read while player 1's keyboard bindings are active.
#include <SDL3/SDL.h>
#include <dolphin/pad.h>
#include <cstdio>
#include <cstdlib>
#include "input.hpp"
#include "logging.hpp"

int main(int argc, char** argv) {
  aurora::g_config.userPath = argc > 1 ? argv[1] : ".";
  SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
  if (!SDL_Init(SDL_INIT_GAMEPAD)) { std::printf("SDL_Init failed: %s\n", SDL_GetError()); return 2; }
  SDL_VirtualJoystickDesc desc;
  SDL_INIT_INTERFACE(&desc);
  desc.type = SDL_JOYSTICK_TYPE_GAMEPAD;
  desc.naxes = SDL_GAMEPAD_AXIS_COUNT;
  desc.nbuttons = SDL_GAMEPAD_BUTTON_COUNT;
  desc.name = "KartPad test pad";
  const SDL_JoystickID id = SDL_AttachVirtualJoystick(&desc);
  if (!id) { std::printf("attach failed: %s\n", SDL_GetError()); return 2; }
  SDL_PumpEvents();
  PADInit();
  const SDL_JoystickID instance = aurora::input::add_controller(id);
  if (instance <= 0) { std::printf("controller not opened\n"); return 2; }
  PADSetKeyboardActive(0, TRUE);  // KartPad's default keyboard port, as in PAD__Init_HLE
  for (unsigned i = 0; i < PADCount(); ++i) PADSetPortForIndex(i, 0);
  SDL_Joystick* joystick = SDL_GetJoystickFromID(id);
  SDL_SetJoystickVirtualButton(joystick, SDL_GAMEPAD_BUTTON_SOUTH, true);
  SDL_SetJoystickVirtualAxis(joystick, SDL_GAMEPAD_AXIS_LEFTX, 32767);
  SDL_UpdateJoysticks();
  PADStatus status[PAD_CHANMAX]{};
  PADRead(status);
  const bool pressed = (status[0].button & PAD_BUTTON_A) != 0;
  std::printf("err=%d button=0x%04x stickX=%d\n", status[0].err, status[0].button, status[0].stickX);
  if (!pressed || status[0].stickX < 100) { std::printf("FAIL: controller input on player 1 was ignored\n"); return 1; }
  SDL_SetJoystickVirtualButton(joystick, SDL_GAMEPAD_BUTTON_SOUTH, false);
  SDL_SetJoystickVirtualAxis(joystick, SDL_GAMEPAD_AXIS_LEFTX, 0);
  SDL_UpdateJoysticks();
  PADRead(status);
  if (status[0].button & PAD_BUTTON_A || status[0].stickX != 0) { std::printf("FAIL: release not seen\n"); return 1; }
  std::printf("PASS: player 1 controller read with keyboard bindings active\n");
  return 0;
}


