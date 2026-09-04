import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val dawnAndroidRoot = providers.environmentVariable("DAWN_ANDROID_ROOT")
val minizipAndroidRoot = providers.environmentVariable("MINIZIP_ANDROID_ROOT")
val gameRuntimeSource = providers.gradleProperty("kartpadGameRuntimeSource").orNull
val translatedShardManifest = providers.gradleProperty("kartpadTranslatedShardManifest").orNull
val androidNativeTarget = providers.gradleProperty("kartpadAndroidNativeTarget").orNull

android {
    namespace = "dev.kartpad.android"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    ndkVersion = "29.0.14206865"

    defaultConfig {
        applicationId = "dev.kartpad.android"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "0.0.1-a0"
        buildConfigField("boolean", "GAME_RUNTIME", (gameRuntimeSource != null).toString())

        ndk {
            abiFilters += "arm64-v8a"
        }
        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DDAWN_ANDROID_ROOT=${dawnAndroidRoot.get()}",
                    "-DMINIZIP_ANDROID_ROOT=${minizipAndroidRoot.get()}",
                )
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
    if (gameRuntimeSource != null) {
        sourceSets.named("main") {
            assets.srcDir(file("$gameRuntimeSource/assets"))
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

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(files("libs/SDL3-3.4.4.aar"))
    implementation("androidx.work:work-runtime-ktx:2.11.1")
}
