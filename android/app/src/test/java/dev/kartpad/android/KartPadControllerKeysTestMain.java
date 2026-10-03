package dev.kartpad.android;

import static dev.kartpad.android.KartPadControllerKeys.*;

public final class KartPadControllerKeysTestMain {
    private static final int KEYBOARD = 0x00000101;

    private KartPadControllerKeysTestMain() {}

    public static void main(String[] args) {
        // Same layout as a recognized gamepad.
        expect(classicMask(KEYCODE_BUTTON_A) == CLASSIC_A, "south is A");
        expect(classicMask(KEYCODE_BUTTON_B) == CLASSIC_B, "east is B");
        expect(classicMask(KEYCODE_BUTTON_X) == CLASSIC_X, "west is X");
        expect(classicMask(KEYCODE_BUTTON_Y) == CLASSIC_Y, "north is Y");
        expect(classicMask(KEYCODE_BUTTON_L1) == CLASSIC_ZR, "L1 is ZR");
        expect(classicMask(KEYCODE_BUTTON_R1) == CLASSIC_R, "R1 is R");
        expect(classicMask(KEYCODE_BUTTON_L2) == CLASSIC_L, "L2 is L");
        expect(classicMask(KEYCODE_BUTTON_START) == CLASSIC_PLUS, "start is plus");
        expect(classicMask(KEYCODE_BUTTON_SELECT) == CLASSIC_MINUS, "select is minus");
        expect(classicMask(KEYCODE_BACK) == CLASSIC_B, "controller back is B");
        expect(classicMask(29) == 0, "letter keys stay with SDL");

        // Devices SDL reads itself are left alone.
        expect(!routes(KEYCODE_BUTTON_A, SOURCE_GAMEPAD, 7, true, SOURCE_GAMEPAD | KEYBOARD, true), "SDL gamepad");
        expect(!routes(KEYCODE_BUTTON_A, KEYBOARD, 7, true, SOURCE_JOYSTICK | KEYBOARD, true), "SDL joystick");
        expect(!routes(KEYCODE_BACK, SOURCE_GAMEPAD, 7, true, SOURCE_DPAD | KEYBOARD, true), "SDL dpad device");

        // Key-only controllers SDL would drop.
        expect(routes(KEYCODE_BUTTON_A, KEYBOARD, 9, true, KEYBOARD, true), "key-only controller A");
        expect(routes(KEYCODE_BUTTON_START, KEYBOARD, 9, true, KEYBOARD, false), "key-only start");
        expect(routes(KEYCODE_BUTTON_B, SOURCE_GAMEPAD, -1, false, 0, false), "virtual gamepad B");
        expect(routes(KEYCODE_BACK, SOURCE_GAMEPAD, -1, false, 0, false), "virtual gamepad back");
        expect(routes(KEYCODE_BACK, KEYBOARD, 9, true, KEYBOARD, true), "external key-only back");

        // The phone's own Back keeps working.
        expect(!routes(KEYCODE_BACK, KEYBOARD, -1, true, KEYBOARD, false), "navigation back");
        expect(!routes(KEYCODE_BACK, KEYBOARD, 2, true, KEYBOARD, false), "built-in back key");
        System.out.println("KartPad controller key routing passed.");
    }

    private static void expect(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
