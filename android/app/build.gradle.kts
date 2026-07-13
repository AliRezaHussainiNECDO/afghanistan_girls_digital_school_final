plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.afghanistan_girls_digital_school"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.afghanistan_girls_digital_school"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // پکیج‌های پخش زنده (apivideo_live_stream) و chewie حداقل به API 21 نیاز
        // دارند. از maxOf استفاده می‌کنیم تا اگر پیش‌فرض فلاتر بالاتر بود پایین نیاید.
        minSdk = maxOf(21, flutter.minSdkVersion)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// === کد اصلاحی برای تزریق نسخه ۳۶ به تمام پکیج‌های وابسته ===
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library")) {
            configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(36)
                defaultConfig {
                    targetSdkVersion(36)
                }
            }
        }
    }
}