package dev.kartpad.android

import android.content.Context

/** Persisted game-action mapping; physical stick clicks are optional inputs. */
internal object KartPadControllerMapping {
    val gameButtonNames = arrayOf("A — Accelerate / Confirm", "B — Drift / Back", "X — Rear View", "Y", "ZR — Rear View", "R — Drift", "D-pad Up — Trick / Wheelie", "D-pad Down", "D-pad Left", "D-pad Right", "L — Use Item", "R — Right Trigger")
    val physicalButtonNames = arrayOf(
        "A", "B", "X", "Y", "Left Shoulder", "Right Shoulder", "D-pad Up", "D-pad Down", "D-pad Left", "D-pad Right", "Left Trigger", "Right Trigger",
        "L3 — Left Stick Click", "R3 — Right Stick Click",
    )
    private val defaults = intArrayOf(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11)
    private const val PREFERENCES = "kartpad_controller_mapping_v3"
    private const val PREVIOUS_PREFERENCES = "kartpad_controller_mapping_v2"
    private const val LEGACY_PREFERENCES = "kartpad_controller_mapping_v1"

    fun load(context: Context): IntArray {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        if (defaults.indices.none { preferences.contains("game_$it") }) {
            val previous = context.getSharedPreferences(PREVIOUS_PREFERENCES, Context.MODE_PRIVATE)
            val hasPrevious = defaults.indices.any { previous.contains("game_$it") }
            val legacy = if (hasPrevious) previous else
                context.getSharedPreferences(LEGACY_PREFERENCES, Context.MODE_PRIVATE)
            val mapping = defaults.copyOf()
            for (index in 0 until (if (hasPrevious) 7 else 5)) mapping[index] = legacy.getInt("game_$index", defaults[index])
            if (mapping.toSet() != defaults.toSet()) {
                defaults.copyInto(mapping)
            }
            save(context, mapping)
            return mapping
        }
        val mapping = IntArray(defaults.size) { index ->
            preferences.getInt("game_$index", defaults[index])
        }
        return if (isValid(mapping)) mapping else defaults.copyOf()
    }

    fun assign(context: Context, game: Int, physical: Int, keepOtherAssignments: Boolean = false): IntArray {
        val mapping = load(context)
        if (game !in mapping.indices || physical !in physicalButtonNames.indices) return mapping
        val other = mapping.indexOf(physical)
        val previous = mapping[game]
        mapping[game] = physical
        if (!keepOtherAssignments && other >= 0 && other != game) mapping[other] = previous
        save(context, mapping)
        return mapping
    }

    fun reset(context: Context): IntArray {
        // Persist the reset so a later load cannot re-import legacy assignments.
        save(context, defaults)
        return defaults.copyOf()
    }

    private fun save(context: Context, mapping: IntArray) {
        if (!isValid(mapping)) return
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().apply {
            mapping.forEachIndexed { index, physical -> putInt("game_$index", physical) }
        }.apply()
    }

    private fun isValid(mapping: IntArray): Boolean =
        mapping.size == defaults.size && mapping.all { it in physicalButtonNames.indices }
}
