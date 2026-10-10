package dev.kartpad.android

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/**
 * The launcher icon choice (#437). Each icon is a launcher alias of the game
 * chooser; exactly one is enabled. The default alias keeps the component name
 * existing home-screen icons point to. Only original KartPad artwork is offered.
 */
internal object KartPadAppIcon {
    val titles = arrayOf("Red K", "Circuit", "Mono")
    private val aliases = arrayOf(".KartPadLaunchActivity", ".KartPadIconCircuit", ".KartPadIconMono")

    private fun component(context: Context, alias: String) =
        ComponentName(context.packageName, "dev.kartpad.android$alias")

    private fun enabled(context: Context, index: Int): Boolean =
        when (context.packageManager.getComponentEnabledSetting(component(context, aliases[index]))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> index == 0
            else -> false
        }

    fun current(context: Context): Int = aliases.indices.firstOrNull { enabled(context, it) } ?: 0

    /** Enables the chosen launcher entry before disabling the others, so one always remains. */
    fun select(context: Context, index: Int) {
        require(index in aliases.indices)
        val packageManager = context.packageManager
        fun set(alias: Int, on: Boolean) = packageManager.setComponentEnabledSetting(
            component(context, aliases[alias]),
            when {
                on && alias == 0 -> PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
                on -> PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else -> PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            },
            PackageManager.DONT_KILL_APP,
        )
        set(index, true)
        aliases.indices.filter { it != index }.forEach { set(it, false) }
    }
}
