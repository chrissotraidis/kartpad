package dev.kartpad.android

import android.content.Context

fun main() {
    val context = Context()
    val defaults = intArrayOf(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11)
    val legacy = context.getSharedPreferences("kartpad_controller_mapping_v1", 0)
    legacy.edit().putInt("game_0", 1).putInt("game_1", 0).apply()
    val migrated = intArrayOf(1, 0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11)
    check(KartPadControllerMapping.load(context).contentEquals(migrated))
    check(legacy.getInt("game_0", -1) == 1) // Retain the old store.
    val swapped = intArrayOf(1, 0, 2, 3, 4, 6, 5, 7, 8, 9, 10, 11)
    check(KartPadControllerMapping.assign(context, 6, 5).contentEquals(swapped))
    check(KartPadControllerMapping.load(context).contentEquals(swapped)) // v2 wins.
    check(KartPadControllerMapping.assign(context, -1, 5).contentEquals(swapped))
    check(KartPadControllerMapping.assign(context, 6, 14).contentEquals(swapped))
    check(KartPadControllerMapping.reset(context).contentEquals(defaults))
    check(KartPadControllerMapping.load(context).contentEquals(defaults)) // No re-migration.

    val invalid = Context()
    invalid.getSharedPreferences("kartpad_controller_mapping_v1", 0)
        .edit().putInt("game_0", 5).apply()
    check(KartPadControllerMapping.load(invalid).contentEquals(defaults))
    val duplicate = Context()
    duplicate.getSharedPreferences("kartpad_controller_mapping_v1", 0)
        .edit().putInt("game_0", 1).apply()
    check(KartPadControllerMapping.load(duplicate).contentEquals(defaults))
    val corruptV2 = Context()
    corruptV2.getSharedPreferences("kartpad_controller_mapping_v1", 0)
        .edit().putInt("game_0", 1).putInt("game_1", 0).apply()
    corruptV2.getSharedPreferences("kartpad_controller_mapping_v2", 0)
        .edit().putInt("game_0", 6).apply()
    check(KartPadControllerMapping.load(corruptV2).contentEquals(defaults))
    check(KartPadControllerMapping.load(Context()).contentEquals(defaults))
    val validV2 = Context()
    validV2.getSharedPreferences("kartpad_controller_mapping_v2", 0).edit().apply {
        swapped.forEachIndexed { index, value -> putInt("game_$index", value) }
    }.apply()
    check(KartPadControllerMapping.load(validV2).contentEquals(swapped))
    check(validV2.getSharedPreferences("kartpad_controller_mapping_v2", 0)
        .getInt("game_6", -1) == 5) // Migration does not rewrite the previous store.
    val sharedContext = Context()
    val shared = intArrayOf(0, 1, 2, 3, 4, 5, 5, 7, 8, 9, 10, 11)
    check(KartPadControllerMapping.assign(sharedContext, 6, 5, true).contentEquals(shared))
    check(KartPadControllerMapping.load(sharedContext).contentEquals(shared))
    check(KartPadControllerMapping.reset(sharedContext).contentEquals(defaults))
    val corruptV3 = Context()
    corruptV3.getSharedPreferences("kartpad_controller_mapping_v3", 0)
        .edit().putInt("game_0", 99).apply()
    check(KartPadControllerMapping.load(corruptV3).contentEquals(defaults))
    println("Controller mapping migration, precedence, swap, reset and validation passed")
}
