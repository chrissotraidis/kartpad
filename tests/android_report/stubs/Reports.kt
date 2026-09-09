package dev.kartpad.android
object BuildConfig { const val VERSION_NAME = "test"; const val VERSION_CODE = 1 }
object RetroRewindRelease { const val VERSION = "test" }
class Json { fun toString(indent: Int) = "{}" }
object KartPadReportContext { fun snapshot(context: android.content.Context, profile: String?) = Json() }
object KartPadExitDiagnostics { fun snapshot(context: android.content.Context) = "[]" }
