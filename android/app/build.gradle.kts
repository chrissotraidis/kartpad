import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val dawnAndroidRoot = providers.environmentVariable("DAWN_ANDROID_ROOT")

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

        ndk {
            abiFilters += "arm64-v8a"
        }
        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                    "-DDAWN_ANDROID_ROOT=${dawnAndroidRoot.get()}",
                )
                cppFlags += listOf("-std=c++20", "-fvisibility=hidden")
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
}
