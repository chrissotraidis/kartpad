import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val dawnAndroidRoot = providers.environmentVariable("DAWN_ANDROID_ROOT")
val minizipAndroidRoot = providers.environmentVariable("MINIZIP_ANDROID_ROOT")
val mbedtlsAndroidRoot = providers.environmentVariable("MBEDTLS_ANDROID_ROOT")
val gameRuntimeSource = providers.gradleProperty("kartpadGameRuntimeSource").orNull
val translatedShardManifest = providers.gradleProperty("kartpadTranslatedShardManifest").orNull
val androidNativeTarget = providers.gradleProperty("kartpadAndroidNativeTarget").orNull
val discIoJniRoot = providers.gradleProperty("kartpadDiscIoJniRoot").orNull
if (discIoJniRoot != null) {
    require(file("$discIoJniRoot/arm64-v8a/libkartpad_discio.so").isFile) {
        "kartpadDiscIoJniRoot must contain arm64-v8a/libkartpad_discio.so"
    }
}
val kartpadProfileable = providers.gradleProperty("kartpadProfileable")
    .map { it.toBooleanStrict() }
    .getOrElse(false)
// Private matched experiment only. Public builds retain API 28 and NDK defaults.
val kartpadPrivateTlsMode = providers.gradleProperty("kartpadPrivateTlsMode").orNull
require(kartpadPrivateTlsMode == null || kartpadPrivateTlsMode in setOf("emulated", "native")) {
    "kartpadPrivateTlsMode must be emulated or native"
}
val kartpadBuildAssets = layout.buildDirectory.dir("generated/assets/kartpadBuild")
val prepareKartpadBuildProvenance by tasks.registering(Exec::class) {
    val output = kartpadBuildAssets.get().file("kartpad-build.json").asFile
    commandLine("python3", rootProject.file("../scripts/write-build-provenance.py"),
        "--repo", rootProject.file(".."), "--output", output)
    if (gameRuntimeSource != null) args("--runtime", gameRuntimeSource)
    if (translatedShardManifest != null) {
        args("--translation", file(translatedShardManifest).parentFile.parentFile)
    }
    outputs.file(output)
    // Git state and external prepared/translated trees can change between builds.
    outputs.upToDateWhen { false }
}
// Reuse the shipped Apple artwork byte-for-byte; do not maintain a second logo.
val kartpadIconResources = layout.buildDirectory.dir("generated/res/kartpadIcon")
val prepareKartpadIcon by tasks.registering(Copy::class) {
    from(rootProject.file("../apple/ios/Assets.xcassets/AppIcon.appiconset/KartPadIcon-1024.png"))
    into(kartpadIconResources.map { it.dir("drawable-nodpi") })
    rename { "kartpad_app_icon.png" }
}
val kartpadVersionCode = providers.gradleProperty("kartpadVersionCode")
    .map { value ->
        value.toIntOrNull()?.takeIf { it > 0 }
            ?: error("kartpadVersionCode must be a positive integer")
    }
    .getOrElse(85)
val kartpadVersionName = providers.gradleProperty("kartpadVersionName")
    .map { value ->
        require(Regex("[0-9A-Za-z][0-9A-Za-z._-]{0,63}").matches(value)) {
            "kartpadVersionName must be 1-64 portable version characters"
        }
        value
    }
    .getOrElse("0.4.19-android.1")

android {
    namespace = "dev.kartpad.android"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    ndkVersion = "29.0.14206865"

    defaultConfig {
        applicationId = "dev.kartpad.android"
        minSdk = if (kartpadPrivateTlsMode == null) 28 else 29
        targetSdk = 36
        versionCode = kartpadVersionCode
        versionName = kartpadVersionName
        manifestPlaceholders["kartpadProfileable"] = kartpadProfileable.toString()
        buildConfigField("boolean", "GAME_RUNTIME", (gameRuntimeSource != null).toString())
        buildConfigField("boolean", "GRAPHICS_MEMORY_EXPERIMENT",
            (gameRuntimeSource != null && providers.gradleProperty("kartpadGraphicsMemoryExperiment").orNull == "true").toString())
        buildConfigField("boolean", "DISC_IMAGE_IMPORT", (discIoJniRoot != null).toString())

        ndk {
            abiFilters += "arm64-v8a"
        }
        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DDAWN_ANDROID_ROOT=${dawnAndroidRoot.get()}",
                    "-DMINIZIP_ANDROID_ROOT=${minizipAndroidRoot.get()}",
                    "-DMBEDTLS_ANDROID_ROOT=${mbedtlsAndroidRoot.get()}",
                )
                if (kartpadPrivateTlsMode != null) {
                    arguments += "-DKARTPAD_PRIVATE_TLS_MODE=$kartpadPrivateTlsMode"
                }
                if (gameRuntimeSource != null || translatedShardManifest != null) {
                    require(gameRuntimeSource != null && translatedShardManifest != null) {
                        "kartpadGameRuntimeSource and kartpadTranslatedShardManifest must be set together"
                    }
                    arguments += listOf(
                        "-DKARTPAD_GAME_RUNTIME_SOURCE=$gameRuntimeSource",
                        "-DKARTPAD_TRANSLATED_SHARD_MANIFEST=$translatedShardManifest",
                    )
                }
                cppFlags += listOf("-std=c++20", "-fvisibility=hidden")
                if (androidNativeTarget != null) {
                    targets += listOf(androidNativeTarget)
                }
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.31.6"
        }
    }

    buildFeatures {
        prefab = true
        buildConfig = true
    }
    sourceSets.named("main") {
        res.srcDir(kartpadIconResources)
        assets.srcDir(kartpadBuildAssets)
    }
    if (gameRuntimeSource != null) {
        sourceSets.named("main") {
            assets.srcDir(file("$gameRuntimeSource/assets"))
        }
    }
    if (discIoJniRoot != null) {
        sourceSets.named("main") {
            jniLibs.srcDir(file(discIoJniRoot))
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
    lint {
        // A0 deliberately pins this verified wrapper and supports ARM64 Android only.
        disable += setOf("AndroidGradlePluginVersion", "ChromeOsAbiSupport", "DiscouragedApi")
    }
}

tasks.named("preBuild") {
    dependsOn(prepareKartpadIcon)
    dependsOn(prepareKartpadBuildProvenance)
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(files("libs/SDL3-3.4.4.aar"))
    implementation("androidx.work:work-runtime-ktx:2.11.1")
}
