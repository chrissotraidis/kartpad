package dev.kartpad.android

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.system.Os
import android.widget.EditText

/** Same hostname contract as kartpad/network/private_wfc.h; never logs the host. */
internal object KartPadPrivateServerSettings {
    private const val ENVIRONMENT = "KARTPAD_PRIVATE_WFC_HOST"
    private fun preferences(context: Context) = context.getSharedPreferences("kartpad_private_wfc", Context.MODE_PRIVATE)
    /** Mirrors IsPublicWfcDomain: Retro Rewind already reaches Retro WFC (#520). */
    fun publicServiceHost(host: String): Boolean {
        val lowered = host.lowercase().removeSuffix(".")
        return listOf("nintendowifi.net", "rwfc.net").any { lowered == it || lowered.endsWith(".$it") }
    }
    fun validHost(host: String): Boolean = host.length in 1..253 && !publicServiceHost(host) && host.split('.').all {
        it.length in 1..63 && it.first() != '-' && it.last() != '-' &&
            it.all { c -> c in 'a'..'z' || c in 'A'..'Z' || c in '0'..'9' || c == '-' }
    }
    fun configureLaunch(context: Context) {
        val host = preferences(context).getString("host", "").orEmpty()
        Os.unsetenv(ENVIRONMENT)
        if (validHost(host)) Os.setenv(ENVIRONMENT, host, true)
    }
    fun show(activity: Activity) {
        val field = EditText(activity).apply {
            isSingleLine = true
            hint = "Hostname or IPv4 address"
            inputType = android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_URI
            setText(preferences(activity).getString("host", ""))
        }
        val dialog = AlertDialog.Builder(activity)
            .setTitle("Experimental Server Settings")
            .setMessage("Requires an already-running compatible Wii service—not another player's app or a generic web server. Only Wii game-service hosts are redirected. The trusted private service uses legacy plaintext; unrelated TLS stays validated. Fully close KartPad from Recents and reopen to apply. This does not restore Original Nintendo WFC or provide native rooms.")
            .setView(field)
            .setNegativeButton("Cancel", null)
            .setNeutralButton("Use Default") { _, _ -> preferences(activity).edit().remove("host").commit() }
            .setPositiveButton("Save for Next Launch", null).create()
        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                val host = field.text.toString().trim()
                if (publicServiceHost(host)) { field.error = "Retro Rewind already connects to Retro WFC. This is only for your own Wii server; tap Use Default." }
                else if (!validHost(host)) { field.error = "Enter a hostname or IPv4 address, without a scheme, port or path." }
                else if (!preferences(activity).edit().putString("host", host).commit()) { field.error = "Could not save the setting." }
                else dialog.dismiss()
            }
        }
        dialog.show()
    }
}
