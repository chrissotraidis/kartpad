package dev.kartpad.android

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.system.Os
import java.util.Locale

/**
 * The Wii console country (kartpad/system/wii_country.h, #511): the flag and
 * globe position Mario Kart Wii shows online. Defaults to the phone's region.
 */
internal object KartPadCountrySetting {
    private const val ENVIRONMENT = "KARTPAD_COUNTRY"
    private val SUPPORTED = setOf(
        "JP", "AI", "AG", "AR", "AW", "BS", "BB", "BZ", "BO", "BR", "VG", "CA", "KY", "CL", "CO", "CR",
        "DM", "DO", "EC", "SV", "GF", "GD", "GP", "GT", "GY", "HT", "HN", "JM", "MQ", "MX", "MS", "CW",
        "NI", "PA", "PY", "PE", "KN", "LC", "VC", "SR", "TT", "TC", "US", "UY", "VI", "VE", "AL", "AU",
        "AT", "BE", "BA", "BW", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IS",
        "IE", "IT", "LV", "LS", "LI", "LT", "LU", "MK", "MT", "ME", "MZ", "NA", "NL", "NZ", "NO", "PL",
        "PT", "RO", "RU", "RS", "SK", "SI", "ZA", "ES", "SZ", "SE", "CH", "TR", "GB", "ZM", "ZW", "AZ",
        "MR", "ML", "NE", "TD", "SD", "ER", "DJ", "SO", "TW", "KR", "HK", "MO", "ID", "SG", "TH", "PH",
        "MY", "CN", "AE", "IN", "EG", "OM", "QA", "KW", "SA", "SY", "BH", "JO", "SX", "BQ"
    )
    private fun preferences(context: Context) = context.getSharedPreferences("kartpad_country", Context.MODE_PRIVATE)

    fun supported(code: String?): Boolean = code != null && code.uppercase(Locale.ROOT) in SUPPORTED

    /** The saved choice, else the phone's region when the Wii has that country. */
    fun current(context: Context): String? {
        val saved = preferences(context).getString("country", null)
        if (supported(saved)) return saved!!.uppercase(Locale.ROOT)
        val region = Locale.getDefault().country
        return if (supported(region)) region.uppercase(Locale.ROOT) else null
    }

    fun configureLaunch(context: Context) {
        Os.unsetenv(ENVIRONMENT)
        current(context)?.let { Os.setenv(ENVIRONMENT, it, true) }
    }

    private fun name(code: String): String = Locale("", code).displayCountry.ifEmpty { code }

    fun show(activity: Activity, onChanged: () -> Unit) {
        val codes = SUPPORTED.sortedBy { name(it) }
        val labels = (listOf("Use Phone's Region") + codes.map { name(it) }).toTypedArray()
        val saved = preferences(activity).getString("country", null)
        val selected = if (supported(saved)) codes.indexOf(saved!!.uppercase(Locale.ROOT)) + 1 else 0
        val now = current(activity)?.let { name(it) } ?: "none"
        AlertDialog.Builder(activity)
            .setTitle("Country (now: $now)")
            .setSingleChoiceItems(labels, selected) { dialog, which ->
                val edit = preferences(activity).edit()
                if (which == 0) edit.remove("country") else edit.putString("country", codes[which - 1])
                edit.commit()
                dialog.dismiss()
                onChanged()
            }
            .setNegativeButton("Back", null)
            .show()
    }
}

