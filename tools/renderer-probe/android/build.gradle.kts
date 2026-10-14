plugins { id("com.android.application") version "8.13.2" }
android {
    namespace = "dev.kartpad.rendererprobe"
    compileSdk = 36
    ndkVersion = "29.0.14206865"
    defaultConfig {
        applicationId = "dev.kartpad.rendererprobe"
        minSdk = 28
        targetSdk = 36
        versionCode = 3
        versionName = "0.3.0"
        ndk { abiFilters += "arm64-v8a" }
        externalNativeBuild { cmake { arguments += listOf(
            "-DANDROID_STL=c++_static",
            "-DCMAKE_PREFIX_PATH=${providers.environmentVariable("KARTPAD_PROBE_DAWN_ROOT").get()}",
            "-DPython3_EXECUTABLE=${providers.environmentVariable("KARTPAD_PROBE_PYTHON").get()}",
        ) } }
    }
    externalNativeBuild { cmake { path = file("../CMakeLists.txt"); version = "3.31.6" } }
    buildTypes { getByName("release") { isMinifyEnabled = false } }
}

val notices = layout.buildDirectory.dir("generated/probeAssets/notices")
val prepareProbeNotices by tasks.registering(Copy::class) {
    from(rootProject.file("../../../LICENSE"))
    from(rootProject.file("../../../vendor/runtimes/android/aurora-main/LICENSE")) { rename { "Aurora-MIT.txt" } }
    from(rootProject.file("../licenses"))
    from("${System.getenv("ANDROID_HOME")}/ndk/29.0.14206865/NOTICE.toolchain") { rename { "NDK-toolchain.txt" } }
    into(notices)
    doFirst {
        check(file("${System.getenv("ANDROID_HOME")}/ndk/29.0.14206865/NOTICE.toolchain").isFile)
    }
}
android.sourceSets.getByName("main").assets.srcDir(layout.buildDirectory.dir("generated/probeAssets"))
tasks.named("preBuild") { dependsOn(prepareProbeNotices) }
