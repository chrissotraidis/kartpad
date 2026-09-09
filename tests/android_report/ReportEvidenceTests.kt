package dev.kartpad.android

fun main() {
    fun blocked(e: KartPadReportEvidence) {
        check(e.validationError() != null)
        check(runCatching { e.summary(false) }.isFailure)
        check(runCatching { e.summary(true) }.isFailure)
    }
    blocked(KartPadReportEvidence())
    blocked(KartPadReportEvidence("", true, true))
    blocked(KartPadReportEvidence("logs", false, true))
    blocked(KartPadReportEvidence("logs", true, false))
    blocked(KartPadReportEvidence("unavailable", true, true, " \n\t"))
    blocked(KartPadReportEvidence("unexpected", true, true, "reason"))
    val reviewed = KartPadReportEvidence("logs", true, true)
    check(reviewed.validationError() == null)
    check(reviewed.summary(true).contains("attach it manually"))
    check(reviewed.summary(false).contains("selected"))
    check(!reviewed.summary(false).contains("received"))
    val unavailable = KartPadReportEvidence("unavailable", true, true, "  App stops before logging.  ")
    check(unavailable.validationError() == null)
    check(unavailable.summary(false) == "Logs unavailable: App stops before logging.")
    check(unavailable.summary(false) == unavailable.summary(true))
    check(!unavailable.summary(false).contains("selected"))
    check(KartPadReportEvidence("unavailable", reason="x".repeat(500)).summary(false).count { it == 'x' } == 300)
    println("PASS: explicit evidence choice, reviewed file, unavailable reason, honest handoff status")
}
