package dev.kartpad.android;

/**
 * Controller keys that SDL would drop, routed to the Classic Controller instead.
 *
 * SDL reads devices it classifies as joysticks itself (see
 * SDLControllerManager.isDeviceSDLJoystick). Some generic controllers arrive as
 * plain key devices instead: SDL logs their buttons as unknown keys, and a Back
 * key from them leaves the game. KartPad maps those keys like a recognized
 * gamepad (MapGamepadToClassic) and turns a controller's Back into B, the
 * button Android itself falls back to Back for.
 */
final class KartPadControllerKeys {
    static final int KEYCODE_BACK = 4;
    static final int KEYCODE_BUTTON_A = 96;
    static final int KEYCODE_BUTTON_B = 97;
    static final int KEYCODE_BUTTON_X = 99;
    static final int KEYCODE_BUTTON_Y = 100;
    static final int KEYCODE_BUTTON_L1 = 102;
    static final int KEYCODE_BUTTON_R1 = 103;
    static final int KEYCODE_BUTTON_L2 = 104;
    static final int KEYCODE_BUTTON_R2 = 105;
    static final int KEYCODE_BUTTON_START = 108;
    static final int KEYCODE_BUTTON_SELECT = 109;
    static final int KEYCODE_ESCAPE = 111;
    static final int KEYBOARD_TYPE_ALPHABETIC = 2;

    static final int SOURCE_CLASS_JOYSTICK = 0x00000010;
    static final int SOURCE_DPAD = 0x00000201;
    static final int SOURCE_GAMEPAD = 0x00000401;
    static final int SOURCE_JOYSTICK = 0x01000010;

    // Classic Controller bits, as in gamepad_contract.h.
    static final int CLASSIC_ZR = 0x00000004;
    static final int CLASSIC_X = 0x00000008;
    static final int CLASSIC_A = 0x00000010;
    static final int CLASSIC_Y = 0x00000020;
    static final int CLASSIC_B = 0x00000040;
    static final int CLASSIC_R = 0x00000200;
    static final int CLASSIC_PLUS = 0x00000400;
    static final int CLASSIC_MINUS = 0x00001000;
    static final int CLASSIC_L = 0x00002000;

    private KartPadControllerKeys() {}

    /** The Classic Controller button for a routed key, or 0. */
    static int classicMask(int keyCode) {
        switch (keyCode) {
            case KEYCODE_BUTTON_A: return CLASSIC_A;
            case KEYCODE_BUTTON_B:
            case KEYCODE_BACK: return CLASSIC_B;
            case KEYCODE_BUTTON_X: return CLASSIC_X;
            case KEYCODE_BUTTON_Y: return CLASSIC_Y;
            case KEYCODE_BUTTON_L1: return CLASSIC_ZR;
            case KEYCODE_BUTTON_R1:
            case KEYCODE_BUTTON_R2: return CLASSIC_R;
            case KEYCODE_BUTTON_L2: return CLASSIC_L;
            case KEYCODE_BUTTON_START: return CLASSIC_PLUS;
            case KEYCODE_BUTTON_SELECT: return CLASSIC_MINUS;
            default: return 0;
        }
    }

    /** Mirrors SDLControllerManager.isDeviceSDLJoystick: SDL reads these devices itself. */
    static boolean sdlReadsDevice(int deviceId, boolean deviceExists, int deviceSources) {
        if (!deviceExists || deviceId < 0) {
            return false;
        }
        return (deviceSources & SOURCE_CLASS_JOYSTICK) != 0 ||
                (deviceSources & SOURCE_DPAD) == SOURCE_DPAD ||
                (deviceSources & SOURCE_GAMEPAD) == SOURCE_GAMEPAD;
    }

    /**
     * Whether KartPad routes this key itself. The phone's own Back (navigation
     * bar or gesture) is never routed, so it keeps working as usual.
     */
    static boolean routes(int keyCode, int eventSource, int deviceId, boolean deviceExists,
            int deviceSources, boolean externalDevice) {
        if (classicMask(keyCode) == 0 || sdlReadsDevice(deviceId, deviceExists, deviceSources)) {
            return false;
        }
        if (keyCode == KEYCODE_BACK) {
            return (eventSource & SOURCE_GAMEPAD) == SOURCE_GAMEPAD ||
                    (eventSource & SOURCE_JOYSTICK) == SOURCE_JOYSTICK ||
                    externalDevice;
        }
        return true;
    }

    /**
     * Escape from a controller opens the runtime's quit prompt; some controllers
     * send it alongside a face button. Drop it unless the device is a real keyboard.
     */
    static boolean dropsKey(int keyCode, int deviceSources, int keyboardType) {
        boolean controller = (deviceSources & SOURCE_GAMEPAD) == SOURCE_GAMEPAD ||
                (deviceSources & SOURCE_JOYSTICK) == SOURCE_JOYSTICK;
        return keyCode == KEYCODE_ESCAPE && controller && keyboardType != KEYBOARD_TYPE_ALPHABETIC;
    }
}
