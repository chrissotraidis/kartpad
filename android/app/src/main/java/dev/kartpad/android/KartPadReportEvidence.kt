package dev.kartpad.android

/** A local evidence choice is not proof that a recipient received an attachment. */
internal data class KartPadReportEvidence(
    val choice: String = "",
    val hasFile: Boolean = false,
    val reviewed: Boolean = false,
    val reason: String = "",
) {
    fun validationError(): String? = when {
        choice == "logs" && !hasFile -> "Choose a reviewed log text file first."
        choice == "logs" && !reviewed -> "Confirm that you reviewed the selected log file."
        choice == "unavailable" && reason.isBlank() -> "Briefly explain why logs are unavailable."
        choice !in setOf("logs", "unavailable") -> "Choose whether you can include reviewed logs."
        else -> null
    }

    fun summary(github: Boolean): String {
        check(validationError() == null)
        return if (choice == "logs") {
            if (github) "Reviewed log file selected; I will attach it manually to this GitHub report."
            else "Reviewed log file selected for the Android share sheet."
        } else "Logs unavailable: ${reason.trim().take(300)}"
    }
}
