allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// ─────────────────────────────────────────────────────────────────────────────
// اجبار همهٔ پلاگین‌های اندرویدی (زیرپروژه‌ها) به کامپایل با compileSdk ≥ 36.
// برخی پلاگین‌ها (مثل native_device_orientation که وابستهٔ apivideo_live_stream
// است) هنوز با compileSdk = 31 کامپایل می‌شوند، اما کتابخانه‌های AndroidX جدیدشان
// حداقل به سطح ۳۴ نیاز دارند؛ این بلوک از خطای checkDebugAarMetadata جلوگیری می‌کند.
fun enforceCompileSdkFloor(p: Project) {
    val androidExtension = p.extensions.findByName("android")
    if (androidExtension is com.android.build.gradle.BaseExtension) {
        val currentSdk =
            androidExtension.compileSdkVersion?.substringAfter("android-")?.toIntOrNull() ?: 0
        if (currentSdk < 36) {
            androidExtension.compileSdkVersion(36)
        }
    }
}

subprojects {
    // اگر پروژه قبلاً ارزیابی شده (مثل :app به‌خاطر evaluationDependsOn بالا)،
    // afterEvaluate مجاز نیست؛ مستقیم اعمال می‌کنیم. در غیر آن، بعد از ارزیابی.
    if (state.executed) {
        enforceCompileSdkFloor(project)
    } else {
        afterEvaluate { enforceCompileSdkFloor(this) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
