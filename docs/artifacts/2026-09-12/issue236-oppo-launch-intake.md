# Issue 236 intake

The reporter supplied KartPad `0.4.16-android.2` / build 65 on an OPPO CPH2669
(Oppo A40), Android 14/API 34. Loading the Original/base game produces a black
screen and exits every time. The report includes correlation ID `KP-1A994DB0`
and no private logs are available because the game cannot be entered.

This is a distinct `android-launch-exit` device/subcase. It is not merged with
the HONOR repost cluster or other black-surface reports without matching exit
and import evidence. The reporter confirmed that the app returns to Android home,
classifying this as a native/OS-level exit boundary. Issue #237 independently
corroborates the same device/build/path under a different report ID and is linked
as a duplicate. No reinstall, data clear, ROM or save is needed.

Public response: https://github.com/chrissotraidis/kartpad/issues/236#issuecomment-5648546435

Boundary confirmation: https://github.com/chrissotraidis/kartpad/issues/236#issuecomment-5648615729
