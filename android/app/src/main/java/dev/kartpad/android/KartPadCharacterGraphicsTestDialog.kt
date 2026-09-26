package dev.kartpad.android

import android.app.AlertDialog
import android.content.Context

internal object KartPadCharacterGraphicsTestDialog {
    fun show(context: Context) {
        val modes = KartPadCharacterGraphicsTest.Mode.entries
        var selected = KartPadCharacterGraphicsTest.mode(context)
        AlertDialog.Builder(context)
            .setTitle("Character Graphics Test")
            .setSingleChoiceItems(modes.map { it.label }.toTypedArray(), modes.indexOf(selected)) { _, which ->
                selected = modes[which]
            }
            .setNegativeButton("Cancel", null)
            .setPositiveButton("Save") { _, _ ->
                val saved = KartPadCharacterGraphicsTest.setMode(context, selected)
                AlertDialog.Builder(context)
                    .setTitle(if (saved) "Restart Required" else "Setting Not Saved")
                    .setMessage(if (saved)
                        "Saved: ${selected.label}. Fully close KartPad and reopen it before checking the same character screen. These options are for characters that appear broken or stretched, mostly on Snapdragon phones. They are experimental and may run slower. If characters look wrong or the game misbehaves, choose Normal."
                    else "The previous setting is unchanged. Please try again.")
                    .setPositiveButton("OK", null).show()
            }.show()
    }
}
