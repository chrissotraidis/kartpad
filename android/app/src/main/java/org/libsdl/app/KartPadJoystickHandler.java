package org.libsdl.app;

import android.view.InputDevice;
import android.util.Log;
import dev.kartpad.android.KartPadControllerKeys;
import java.util.HashSet;

/**
 * SDL skips any device whose name contains " Keyboard" (its gamepad blocklist),
 * and some controllers, ipega ones among them, name themselves that way. SDL then
 * turns their buttons into keys: B and Select become Escape, the rest are lost.
 * KartPad adds such a device again under a name SDL accepts, but only when it
 * reports itself as a gamepad with sticks. Lives in SDL's package to reach its
 * joystick handler; SDL's own add, motion and removal paths stay unchanged.
 */
public final class KartPadJoystickHandler extends SDLJoystickHandler {
    private static final String TAG = "KartPad";
    private final HashSet<Integer> renamed = new HashSet<>();

    /** Call before SDLActivity.onCreate, which keeps an already installed handler. */
    public static void install() {
        if (SDLControllerManager.mJoystickHandler == null) {
            SDLControllerManager.mJoystickHandler = new KartPadJoystickHandler();
        }
    }

    @Override
    synchronized void pollInputDevices() {
        super.pollInputDevices();
        renamed.removeIf(id -> getJoystick(id) == null);
        for (int id : InputDevice.getDeviceIds()) {
            SDLJoystick joystick = getJoystick(id);
            InputDevice device = InputDevice.getDevice(id);
            if (joystick == null || device == null || renamed.contains(id)) continue;
            String name = KartPadControllerKeys.sdlGamepadName(joystick.name, device.getSources(), joystick.axes.size());
            if (name == null) continue;
            renamed.add(id);
            Log.i(TAG, "Adding controller SDL skipped by name: \"" + joystick.name + "\" as \"" + name + "\"");
            SDLControllerManager.nativeAddJoystick(id, name, joystick.desc,
                    getVendorId(device), getProductId(device), getButtonMask(device),
                    joystick.axes.size(), getAxisMask(joystick.axes), joystick.hats.size() / 2, false, false);
        }
    }
}
