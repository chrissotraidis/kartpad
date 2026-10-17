# Issues 234 and 235 intake

## Issue 234 — Galaxy S25 Ultra save/rating/identity transfer

The reporter supplied KartPad `0.4.16 android 2 build 65` on Samsung S25 Ultra
`SM-S938B/DS`. After transferring saves, the Mii/name/rating are absent, online
shows a different console serial, and vanilla Mario Kart reports changed country
settings and requests new save data. The symptom occurs when transferring only
the rating or only the save.

This is classified as `save-rating-transfer`, separate from launch, renderer and
performance reports. The reporter clarified that the data came from a Wheel
Witch save backup on the same phone, narrowing this to same-device backup
restoration. No save file or serial number is requested.

Public response: https://github.com/chrissotraidis/kartpad/issues/234#issuecomment-5647550600

Follow-up clarification: https://github.com/chrissotraidis/kartpad/issues/234#issuecomment-5647599209

## Issue 235 — Honor X7c startup exit

The reporter supplied KartPad `0.4.16` on an Honor X7c and reports a black startup
screen followed by a complete app exit and return to the main screen on relaunch.
The Android build suffix, selected profile, import completion, exact destination
(KartPad chooser versus Android home), and Original/Retro scope are not supplied.

This is classified as a distinct `android-launch-exit` subcase. Similar wording
does not merge it with the HONOR LGN-NX3 report-ID cluster.

Public response: https://github.com/chrissotraidis/kartpad/issues/235#issuecomment-5647550710

Follow-up evidence: the reporter confirms Original 1.0 WBFS reaches a black
screen with interactive controls, then returns to Android home after about 3–5
seconds. This is now a classified native launch/render exit boundary; no WBFS,
reinstall or data clear is needed.

Follow-up response: https://github.com/chrissotraidis/kartpad/issues/235#issuecomment-5649459291
