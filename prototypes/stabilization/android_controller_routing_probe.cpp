// Actual Android Aurora input/PAD modules with SDL virtual devices. Only guest
// memory writes and the separate USB-adapter service are replaced by fixtures.
#include "input.hpp"
#include <aurora/input.hpp>
#include "internal.hpp"
#include <dolphin/pad.h>
#include <SDL3/SDL.h>
#include "kartpad/android/controller_mapping.hpp"
#include <array>
#include <cstdio>
#include <filesystem>
#include <stdexcept>

namespace aurora { AuroraConfig g_config{}; }
namespace Memory { struct AccessViolation {}; }
namespace PadStatusContract { constexpr uint32_t kGuestStatusSize = 12; }
std::array<PADStatus, PAD_CHANMAX> guestStatuses{};
void WritePadStatus(uint32_t address, const PADStatus& status) {
  guestStatuses.at((address - 0x1000) / PadStatusContract::kGuestStatusSize) = status;
}
namespace Wup028Adapter {
bool connected = false;
bool Read(std::array<PADStatus, PAD_CHANMAX>& status) {
  for (auto& pad : status) pad.err = PAD_ERR_NO_CONTROLLER;
  if (connected) { status[0] = {}; status[0].button = PAD_BUTTON_A; status[0].err = PAD_ERR_NONE; }
  return connected;
}
}
#define __ANDROID__ 1
#include "controller-routing-kernel.hpp"
#undef __ANDROID__

void require(bool value, const char* message) {
  if (!value) throw std::runtime_error(message);
}
void pump() {
  SDL_UpdateGamepads();
  SDL_Event event;
  while (SDL_PollEvent(&event)) {
    if (event.type == SDL_EVENT_GAMEPAD_BUTTON_DOWN || event.type == SDL_EVENT_GAMEPAD_BUTTON_UP)
      aurora::input::update_standard_gamepad_button(event.gbutton.which, event.gbutton.button,
                                                   event.type == SDL_EVENT_GAMEPAD_BUTTON_DOWN);
    if (event.type == SDL_EVENT_GAMEPAD_AXIS_MOTION)
      aurora::input::update_standard_gamepad_axis(event.gaxis.which, event.gaxis.axis, event.gaxis.value);
  }
}
SDL_JoystickID attach(const char* name) {
  SDL_VirtualJoystickDesc desc{}; SDL_INIT_INTERFACE(&desc);
  desc.type = SDL_JOYSTICK_TYPE_GAMEPAD;
  desc.nbuttons = SDL_GAMEPAD_BUTTON_COUNT; desc.naxes = SDL_GAMEPAD_AXIS_COUNT;
  desc.name = name;
  const auto id = SDL_AttachVirtualJoystick(&desc);
  require(id != 0, "Virtual controller attachment failed");
  require(aurora::input::add_controller(id) == id, "Maintained input module rejected virtual controller");
  pump();
  return id;
}
void press(SDL_JoystickID id, SDL_GamepadButton button, bool down) {
  auto& controller = aurora::input::g_GameControllers.at(id);
  auto* joystick = SDL_GetGamepadJoystick(controller.m_controller);
  require(SDL_SetJoystickVirtualButton(joystick, button, down), "Virtual input failed");
  pump();
}
void detach(SDL_JoystickID id) {
  aurora::input::remove_controller(id);
  require(SDL_DetachVirtualJoystick(id), "Virtual detach failed");
  pump();
}
int main(int argc, char** argv) {
  if (argc != 2 && argc != 3) return 2;
  std::filesystem::create_directories(argv[1]);
  aurora::g_config.userPath = argv[1];
  aurora::g_config.logLevel = LOG_WARNING;
  SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
  require(SDL_Init(SDL_INIT_GAMEPAD), "SDL initialization failed");
  require(PADInit(), "Maintained PAD initialization failed");
  aurora::input::set_standard_gamepads_active(true);
  try {
    auto id = attach("KartPad routing virtual one");
    if (argc == 3) {
      require(std::string_view(argv[2]) == "reopen-empty", "Unknown probe mode");
      require(!aurora::input::standard_gamepad_connected(0,true),
              "Process restart ignored persisted empty P1");
      detach(id);
      aurora::input::shutdown();SDL_Quit();
      std::puts("Actual SDL bridge preserves explicit Unassigned across process restart");
      return 0;
    }
    require(aurora::input::standard_gamepad_connected(0, true), "First-use unassigned controller fallback failed");
    require(aurora::input::assign_standard_gamepad(id, 0), "Explicit assignment failed");
    press(id, SDL_GAMEPAD_BUTTON_SOUTH, true);
    PADStatus native[PAD_CHANMAX]{};
    PADRead(native);
    require(native[0].err == PAD_ERR_NONE && (native[0].button & PAD_BUTTON_A), "Actual SDL-to-PAD path did not receive A");
    aurora::input::StandardGamepadState snapshot{};
    require(aurora::input::read_standard_gamepad_state(0, true, &snapshot), "Classic source absent");
    require(snapshot.buttons & aurora::input::kStandardGamepadSouth, "Actual SDL-to-Classic source did not receive A");
    kartpad::android::ControllerButtonMapping swapped{1,0,2,3,4,5,6,7,8,9,10,11};
    kartpad::android::RawGamepadState raw{.connected=true,
      .buttons=kartpad::android::ApplyControllerButtonMapping(snapshot.buttons,swapped)};
    require(kartpad::android::MapGamepadToClassic(raw).buttons == kartpad::android::kClassicB, "A/B remap failed");
    PAD__Read_HLE(0x1000);
    std::printf("assigned SDL: native PAD=%d guest PAD=%d mapped Classic=%x\n", native[0].err,
                guestStatuses[0].err,kartpad::android::MapGamepadToClassic(raw).buttons);
    require(guestStatuses[0].err == PAD_ERR_NO_CONTROLLER,
            "Assigned SDL controller also reaches the guest GameCube port, bypassing Classic remapping");
    aurora::input::set_standard_gamepads_active(false);
    PAD__Read_HLE(0x1000);
    require(guestStatuses[0].err == PAD_ERR_NO_CONTROLLER, "Suspension leaked controller into GameCube route");
    require(!aurora::input::standard_gamepad_connected(0,true), "Suspended Classic source remains connected");
    aurora::input::set_standard_gamepads_active(true);
    Wup028Adapter::connected = true;
    PAD__Read_HLE(0x1000);
    require(guestStatuses[0].err == PAD_ERR_NONE && guestStatuses[0].button == PAD_BUTTON_A,
            "Separate USB adapter route was suppressed");
    Wup028Adapter::connected = false;
    press(id, SDL_GAMEPAD_BUTTON_SOUTH, false);
    require(aurora::input::clear_standard_gamepad_player(0), "Explicit unassignment failed");
    require(!aurora::input::standard_gamepad_connected(0,true), "Explicit empty P1 was overridden by lone-controller fallback");
    const auto second = attach("KartPad routing virtual two");
    require(aurora::input::assign_standard_gamepad(id,0) && aurora::input::assign_standard_gamepad(second,1),
            "Two-player assignment failed");
    require(aurora::input::standard_gamepad_connected(0,true) && aurora::input::standard_gamepad_connected(1,false),
            "Assigned player missing");
    require(aurora::input::assign_standard_gamepad(second,0), "Player reassignment failed");
    require(aurora::input::player_index(id)==-1 && !aurora::input::standard_gamepad_connected(1,false),
            "Previous assignments survived reassignment");
    press(second, SDL_GAMEPAD_BUTTON_EAST, true);
    require(aurora::input::read_standard_gamepad_state(0,true,&snapshot) &&
            snapshot.buttons==aurora::input::kStandardGamepadEast,"Reassigned source mixed controller state");
    PAD__Read_HLE(0x1000);
    require(guestStatuses[0].err==PAD_ERR_NO_CONTROLLER,"Reassigned controller duplicated into GameCube path");
    press(second,SDL_GAMEPAD_BUTTON_EAST,false);
    require(aurora::input::read_standard_gamepad_state(0,true,&snapshot) && snapshot.buttons==0,
            "Button release did not return to neutral");
    require(aurora::input::clear_standard_gamepad_player(0),"Final unassignment failed");
    detach(second);detach(id);
    id=attach("KartPad routing virtual one");
    require(!aurora::input::standard_gamepad_connected(0,true),"Reconnect ignored explicit empty port");
    PADSetPortForIndex(0,2);
    require(aurora::input::standard_gamepad_connected(2,false) && aurora::input::player_index(id)==2,
            "Legacy controller settings changed SDL assignment without updating the Classic bridge");
    PADClearPort(2);
    require(!aurora::input::standard_gamepad_connected(2,false) && aurora::input::player_index(id)==-1,
            "Legacy controller settings failed to clear Classic assignment");
    detach(id);
    PADSetKeyboardActive(0,TRUE);
    PAD__Read_HLE(0x1000);
    require(guestStatuses[0].err==PAD_ERR_NONE && guestStatuses[0].button==0,
            "Keyboard-only GameCube route was suppressed");
    std::puts("Actual SDL assignment, mapping ownership, suspension, reassignment, release, and reconnect passed");
  } catch (const std::exception& error) {
    std::fprintf(stderr,"FAIL: %s\n",error.what());
    aurora::input::shutdown();SDL_Quit();return 4;
  }
  aurora::input::shutdown();SDL_Quit();
}
