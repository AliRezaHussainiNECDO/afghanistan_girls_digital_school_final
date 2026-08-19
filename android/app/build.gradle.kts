import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Push Notification واقعی (FCM) — مقادیر google-services.json را در زمان
    // build به کد بومی تزریق می‌کند (نیاز firebase_core/firebase_messaging).
    id("com.google.gms.google-services")
    // گزارش خودکار خرابی (شامل خرابی‌های بومی WebRTC/Jitsi روی گوشی‌های واقعی
    // مثل سامسونگ — نگاه کنید به کامنت firebase_crashlytics در pubspec.yaml).
    id("com.google.firebase.crashlytics")
}

// امضای نسخهٔ release: اگر android/key.properties وجود داشته باشد (که در گیت
// نادیده گرفته می‌شود)، از کلید واقعی شما استفاده می‌شود؛ در غیر این صورت
// برای این‌که `flutter run --release` هنوز کار کند، از کلید debug استفاده
// می‌شود. راهنما در android/key.properties.example.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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
        // شناسهٔ رسمی و دائمی برنامه — باید دقیقاً با package_name در
        // android/app/google-services.json (پروژهٔ Firebase جدید) یکی باشد.
        applicationId = "af.digital.girls.school"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // jitsi_meet_flutter_sdk (ویدیوکنفرانس واقعی اتاق فال‌بک سمینار) حداقل
        // به API 24 نیاز دارد؛ apivideo_live_stream/chewie با آن سازگارند.
        // از maxOf استفاده می‌کنیم تا اگر پیش‌فرض فلاتر بالاتر بود پایین نیاید.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // پیش‌فرض امن: intent-filter مستقیمِ MainActivity (در
        // AndroidManifest.xml اصلی، برای رفع اشکال «flutter run» — نگاه کنید
        // به کامنت آن‌جا) به‌صورت پیش‌فرض غیرفعال است تا در build های بدون
        // buildType مشخص هم رفتار production/«حالت پنهان» حفظ شود. debug و
        // profile پایین‌تر آن را صراحتاً به "true" override می‌کنند.
        manifestPlaceholders["mainActivityLauncherEnabled"] = "false"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // اگر android/key.properties موجود باشد از کلید واقعی release استفاده
            // می‌شود؛ در غیر این صورت (مثلاً روی ماشین توسعه‌دهنده‌ای که هنوز
            // کیستور نساخته) با کلید debug ساخته می‌شود تا build نشکند — اما
            // قبل از انتشار در Play Store حتماً باید key.properties را بسازید.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // release: مقدار پیش‌فرض defaultConfig ("false") دست‌نخورده می‌ماند
            // تا در نسخهٔ منتشرشده فقط activity-alias فعال («حالت پنهان») دیده
            // شود، نه خودِ MainActivity.
        }
        getByName("debug") {
            // رفع اشکال «flutter run» → «package identifier or launch activity
            // not found»: نگاه کنید به کامنت کامل در
            // android/app/src/main/AndroidManifest.xml. فقط در debug، خودِ
            // MainActivity هم یک آیکون Launcher می‌گیرد تا ابزار flutter آن را
            // پیدا/اجرا کند.
            manifestPlaceholders["mainActivityLauncherEnabled"] = "true"
        }
        getByName("profile") {
            // همان رفع اشکال بالا، برای «flutter run --profile».
            manifestPlaceholders["mainActivityLauncherEnabled"] = "true"
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


// exclude: از تداخل کلاس تکراری RtspMediaSource بین media3-exoplayer-rtsp
// مستقل و نسخهٔ داخلی react-native-video که jitsi-meet-sdk با خودش می‌آورد
// جلوگیری می‌کند (خطای checkDebugDuplicateClasses).
configurations.all {
exclude(group = "androidx.media3", module = "media3-exoplayer-rtsp")
}
