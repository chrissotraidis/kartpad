package dev.kartpad.android

import dev.kartpad.android.KartPadPhoneAdvice.Action
import dev.kartpad.android.KartPadPhoneAdvice.Gpu

fun main() {
    val advice = KartPadPhoneAdvice
    check(advice.adrenoModel("Adreno (TM) 750") == 750)
    check(advice.adrenoModel("Mali-G57 MC2") == null)
    check(advice.qualcommBuild("OpenGL ES 3.2 V@0762.36 (GIT@7d0c4c3, I6c1a7ab6c3) (Date:01/03/24)") == 762)
    check(advice.qualcommBuild("OpenGL ES 3.2 V@0502.0 (GIT@2d0d5cbd, I5e18a3b8fd)") == 502)
    check(advice.qualcommBuild("OpenGL ES 3.2 v1.r54p1-01eac0.f5e47e6c1b7e4b2a") == null)

    // 512.762 on Adreno 6xx/7xx (S24 Ultra, Moto G85): Turnip, with a way to get it.
    val s24 = advice.advise(Gpu("Adreno (TM) 750", "OpenGL ES 3.2 V@0762.36 (GIT@x)"), null)
    check(s24.action == Action.GET_DRIVER && "Turnip" in s24.summary)
    check(s24.gpuLabel == "Adreno 750 · Qualcomm driver 512.762")
    check(advice.advise(Gpu("Adreno (TM) 619", "OpenGL ES 3.2 V@0762.31"), null).action == Action.GET_DRIVER)

    // Older 512.502 drivers have no reported faults: phone's driver.
    val poco = advice.advise(Gpu("Adreno (TM) 650", "OpenGL ES 3.2 V@0502.0"), null)
    check(poco.action == Action.NONE && "should work" in poco.summary)

    // Adreno 8xx: Automatic handles it; custom drivers aren't recommended.
    val elite = advice.advise(Gpu("Adreno (TM) 840", "OpenGL ES 3.2 V@0842.19"), null)
    check(elite.action == Action.NONE && "Keep the phone's driver" in elite.summary)

    // Other GPUs can't swap drivers, and always get the speed tips.
    val mali = advice.advise(Gpu("Mali-G57 MC2", "OpenGL ES 3.2 v1.r54p1"), null)
    check(mali.action == Action.NONE && "Snapdragon" in mali.summary && mali.points.any { "30 FPS Races" in it })
    check(mali.gpuLabel == "Mali-G57 MC2")
    val powervr = advice.advise(Gpu("PowerVR Rogue GE8320", "OpenGL ES 3.2 build 1.13"), null)
    check(powervr.points.any { "#304" in it })
    check(advice.advise(Gpu("Android Emulator OpenGL ES Translator (Apple M3 Max)", "OpenGL ES 3.0"), null).action == Action.NONE)

    // A chosen custom driver is named, so a player can undo it.
    check(advice.advise(Gpu("Adreno (TM) 750", "V@0762.36"), "Turnip v30").points.first().contains("Turnip v30"))
    // No probe result still gives useful advice.
    check(advice.advise(null, null).points.isNotEmpty())
    println("PASS: phone advice for 512.762 Adreno, older Adreno, Adreno 8xx, Mali, PowerVR and unknown GPUs")
}
