package dev.kartpad.android

import android.content.Context

/** Persisted one-to-one A/B/X/Y/Z mapping matching KartPad's iOS v1 scope. */
internal object KartPadControllerMapping {
    val gameButtonNames = arrayOf("A", "B", "X", "Y", "Z")
    val physicalButtonNames = arrayOf("A", "B", "X", "Y", "Left Shoulder")
    private val defaults = intArrayOf(0, 1, 2, 3, 4)
    private const val PREFERENCES = "kartpad_controller_mapping_v1"

    fun load(context: Context): IntArray {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val mapping = IntArray(defaults.size) { index ->
            preferences.getInt("game_$index", defaults[index])
        }
        return if (isValid(mapping)) mapping else defaults.copyOf()
    }

    fun assign(context: Context, game: Int, physical: Int): IntArray {
        val mapping = load(context)
        if (game !in mapping.indices || physical !in mapping.indices) return mapping
        val other = mapping.indexOf(physical)
        val previous = mapping[game]
        mapping[game] = physical
        if (other >= 0 && other != game) mapping[other] = previous
        save(context, mapping)
        return mapping
    }

    fun reset(context: Context): IntArray {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit().clear().apply()
        return defaults.copyOf()
    }

    private fun save(context: Context, mapping: IntArray) {
        if (!isValid(mapping)) return
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().apply {
            mapping.forEachIndexed { index, physical -> putInt("game_$index", physical) }
        }.apply()
    }

    private fun isValid(mapping: IntArray): Boolean =
        mapping.size == defaults.size && mapping.toSet() == defaults.toSet()
}
