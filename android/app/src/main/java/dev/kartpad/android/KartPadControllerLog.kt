package dev.kartpad.android

import android.os.Build
import android.view.InputDevice
import android.view.KeyEvent

/**
 * Controller details for problem reports: what Android reports for each
 * connected controller and the last few controller keys KartPad received.
 * Kept in memory only; nothing is written or sent until the player shares a report.
 */
internal object KartPadControllerLog {
    private const val RECENT_KEYS = 16
    private const val MAXIMUM_DEVICES = 6
    private val recent = ArrayDeque<String>()

    // Source flags share low class bits, so each flag must match in full.
    private fun has(sources: Int, flag: Int) = sources and flag == flag
    private fun isController(sources: Int) = has(sources, InputDevice.SOURCE_GAMEPAD) ||
        has(sources, InputDevice.SOURCE_JOYSTICK) || has(sources, InputDevice.SOURCE_DPAD)
    private fun isPointer(sources: Int) = has(sources, InputDevice.SOURCE_TOUCHSCREEN) ||
        has(sources, InputDevice.SOURCE_MOUSE) || has(sources, InputDevice.SOURCE_STYLUS)
    /** A controller, or an external key-only device (some controllers present as keyboards). */
    private fun isControllerDevice(device: InputDevice): Boolean {
        if (device.isVirtual) return false
        if (isController(device.sources)) return true
        val external = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && device.isExternal
        return external && has(device.sources, InputDevice.SOURCE_KEYBOARD) && !isPointer(device.sources)
    }

    @Synchronized
    fun record(event: KeyEvent, sdlReads: Boolean, routed: Boolean) {
        if (event.action != KeyEvent.ACTION_DOWN || event.repeatCount > 0) return
        val device = event.device
        val fromController = isController(event.source) || (device != null && isControllerDevice(device))
        if (!fromController) return
        val name = KeyEvent.keyCodeToString(event.keyCode).removePrefix("KEYCODE_")
        val path = when { routed -> "kartpad"; sdlReads -> "sdl"; else -> "sdl-key" }
        recent.addLast("$name@${event.deviceId}/$path")
        while (recent.size > RECENT_KEYS) recent.removeFirst()
    }

    @Synchronized
    fun summary(): String = buildString {
        var count = 0
        for (id in InputDevice.getDeviceIds()) {
            val device = InputDevice.getDevice(id) ?: continue
            if (count >= MAXIMUM_DEVICES || !isControllerDevice(device)) continue
            val sdl = KartPadControllerKeys.sdlReadsDevice(id, true, device.sources)
            appendLine("Controller: " + device.name + " usb=%04x:%04x sources=0x%x axes=%d sdl=%s".format(
                device.vendorId, device.productId, device.sources, device.motionRanges.size, if (sdl) "yes" else "no"))
            count += 1
        }
        if (count == 0) appendLine("Controller: none connected")
        append("Recent controller keys: ${if (recent.isEmpty()) "none" else recent.joinToString(" ")}")
    }
}
