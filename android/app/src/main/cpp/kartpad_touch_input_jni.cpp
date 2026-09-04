#include "kartpad/android/touch_input.h"

#include <jni.h>

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadOverlayView_nativePublishTouchState(
    JNIEnv*, jobject, jint buttons, jfloat left_x, jfloat left_y,
    jfloat right_x, jfloat right_y, jboolean connected) {
    kartpad::android::PublishTouchInput({
        left_x,
        left_y,
        right_x,
        right_y,
        static_cast<std::uint32_t>(buttons),
        connected == JNI_TRUE,
    });
}

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadOverlayView_nativeClearTouchState(
    JNIEnv*, jobject) {
    kartpad::android::ClearTouchInput();
}
