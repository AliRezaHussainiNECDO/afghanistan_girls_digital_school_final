pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

// === فیکس file_picker 11 با AGP 9 ===
// file_picker با AGP 9 پلاگین کاتلین را اعمال نمی‌کند و انتظار built-in Kotlin دارد،
// اما پروژه در حالت legacy است (android.builtInKotlin=false)؛ پس خودمان KGP را اعمال می‌کنیم.
gradle.lifecycle.beforeProject {
    if (name == "file_picker") {
        plugins.withId("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

// === حل ریشه‌ای مشکل اندروید 36 برای تمام پکیج‌ها ===
gradle.lifecycle.beforeProject {
    plugins.withType(com.android.build.gradle.BasePlugin::class.java) {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            // با استفاده از متدهای عمومی گریدل، کامپایل را روی 36 ست می‌کنیم
            val compileSdkMethod = androidExtension.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
            compileSdkMethod.invoke(androidExtension, 36)
        }
    }
}