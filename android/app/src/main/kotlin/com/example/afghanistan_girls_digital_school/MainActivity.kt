package com.example.afghanistan_girls_digital_school

import android.content.ComponentName
import android.content.pm.PackageManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * «حالت پنهان» (Hidden Mode) — طبق درخواست صریح کاربر:
 *
 * ۱) سوییچِ آیکونِ launcher بین برند واقعیِ برنامه و یک نمایهٔ «ماشین‌حساب»
 *    بی‌ضرر، از طریق PackageManager.setComponentEnabledSetting روی دو
 *    <activity-alias> تعریف‌شده در AndroidManifest.xml (RealLauncherAlias /
 *    CalculatorDisguiseAlias). این یک تنظیمِ سطح سیستم‌عامل است و پس از
 *    بستن/باز کردن مجدد یا حتی ری‌استارت گوشی هم باقی می‌ماند.
 *
 * ۲) تشخیص نگه‌داشتنِ ۳-ثانیه‌ایِ دکمهٔ «صدا-کم» (Volume Down) — تنها وقتی
 *    خودِ اپ در پیش‌زمینه است (اندروید هرگز دکمه‌های سخت‌افزاری را برای
 *    اپ‌های معمولی در پس‌زمینه در اختیار نمی‌گذارد؛ Accessibility Service
 *    لازم بود که آگاهانه کنار گذاشته شد چون خودش هدف‌توجه/ریسک امنیتی
 *    ایجاد می‌کند). فشارهای کوتاه (کمتر از ۳ ثانیه) دست‌نخورده به سیستم
 *    برمی‌گردند تا کم‌کردن صدای معمولی برنامه هیچ‌وقت خراب نشود؛ فقط از
 *    لحظه‌ای که ۳ ثانیه کامل شد، رویداد «hide» به Flutter فرستاده می‌شود.
 */
class MainActivity : FlutterActivity() {

    private val methodChannelName = "agds/hidden_mode"
    private val volumeEventChannelName = "agds/hidden_mode/volume"

    private var volumeEventSink: EventChannel.EventSink? = null
    private var volumeDownStartAt: Long = 0L
    private var volumeDownTriggered: Boolean = false
    private val holdThresholdMs = 3000L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setDisguised" -> {
                        val disguised = call.argument<Boolean>("disguised") ?: false
                        applyDisguiseState(disguised)
                        result.success(true)
                    }
                    "isDisguised" -> result.success(isCalculatorAliasEnabled())
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, volumeEventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    volumeEventSink = null
                }
            })
    }

    /** نام کامل کلاسِ merge-شده در Manifest (بر اساس namespace واقعی پروژه). */
    private fun aliasComponent(simpleAliasName: String): ComponentName {
        val pkg = javaClass.`package`?.name ?: "com.example.afghanistan_girls_digital_school"
        return ComponentName(this, "$pkg.$simpleAliasName")
    }

    private fun applyDisguiseState(disguised: Boolean) {
        val pm = packageManager
        val realAlias = aliasComponent("RealLauncherAlias")
        val calcAlias = aliasComponent("CalculatorDisguiseAlias")
        if (disguised) {
            pm.setComponentEnabledSetting(
                calcAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP
            )
            pm.setComponentEnabledSetting(
                realAlias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP
            )
        } else {
            pm.setComponentEnabledSetting(
                realAlias, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP
            )
            pm.setComponentEnabledSetting(
                calcAlias, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP
            )
        }
    }

    private fun isCalculatorAliasEnabled(): Boolean {
        val pm = packageManager
        val calcAlias = aliasComponent("CalculatorDisguiseAlias")
        return pm.getComponentEnabledSetting(calcAlias) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            when (event.action) {
                KeyEvent.ACTION_DOWN -> {
                    if (event.repeatCount == 0) {
                        volumeDownStartAt = System.currentTimeMillis()
                        volumeDownTriggered = false
                    } else if (!volumeDownTriggered &&
                        System.currentTimeMillis() - volumeDownStartAt >= holdThresholdMs
                    ) {
                        volumeDownTriggered = true
                        volumeEventSink?.success("hide")
                    }
                    // فشارهای کوتاه دست‌نخورده به سیستم می‌روند (کم‌کردن صدای
                    // واقعی هرگز خراب نمی‌شود)؛ فقط بعد از رسیدن به آستانهٔ ۳
                    // ثانیه، رویداد‌های بعدی را می‌بلعیم تا صدا بیشتر کم نشود.
                    if (volumeDownTriggered) return true
                }
                KeyEvent.ACTION_UP -> {
                    val wasTriggered = volumeDownTriggered
                    volumeDownStartAt = 0L
                    volumeDownTriggered = false
                    if (wasTriggered) return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
