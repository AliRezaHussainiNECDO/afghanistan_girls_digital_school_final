# یادداشت: بخش‌های ناتمام ترجمه + مراحل انتشار

تاریخ: ۲۰۲۶/۰۷/۱۸

## ۱. دو بخش عمداً ترجمه‌نشده (برای حل بعدی)

### الف) `lib/core/errors/failures.dart` (۳ پیام پیش‌فرض)
پیام‌های پیش‌فرض `NetworkFailure`، `CacheFailure`، `PermissionFailure` هنوز فقط
فارسی هستند. این کلاس‌ها عمداً «مستقل از Flutter» طراحی شده‌اند (طبق کامنت
بالای فایل) و در بیش از ۲۵ فایل `*_repository_impl.dart` استفاده می‌شوند.

**راه‌حل درست:** به‌جای تزریق `localeCode` به لایهٔ domain (که اصل معماری را
می‌شکند)، باید در لایهٔ UI — همان‌جایی که `Failure` نمایش داده می‌شود
(مثل `ErrorView`) — نوع Failure را به کلید ترجمه نگاشت کرد:
```dart
String failureMessage(BuildContext context, Failure f) => switch (f) {
  NetworkFailure() => context.tr('errors.network'),
  CacheFailure() => context.tr('errors.cache'),
  PermissionFailure() => context.tr('errors.permission'),
  _ => f.message, // ServerFailure و بقیه پیام خاص خودشان را دارند
};
```
سپس هر جایی که `Text(failure.message)` یا `e.toString()` مستقیم استفاده شده،
باید به این تابع تغییر کند.

### ب) `FriendlyErrorWidget` در `lib/core/errors/app_error_handler.dart` (۲ رشته)
این ویجت جایگزین صفحهٔ کرش پیش‌فرض Flutter است و عمداً خوداتکا (بدون
وابستگی به Localizations/Theme) طراحی شده، چون ممکن است دقیقاً وقتی رندر
شود که درخت ویجت خراب است. اگر `context.tr()` هم به همین دلیل شکست بخورد
(مثلاً چون Localizations در دسترس نیست)، این صفحهٔ نجات هم از کار می‌افتد.

**راه‌حل درست (اگر تصمیم گرفتید ترجمه شود):** یک `try/catch` دور `context.tr()`
بگذارید و در صورت خطا به متن فارسی پیش‌فرض برگردید — تا هم ترجمه شود، هم
هرگز خودش خطای جدید نسازد.

## ۲. [حل شد — ۲۰۲۶/۰۷/۱۸] پیام‌های خطای سرور حالا هر ۴ زبان را دارند

پوشهٔ `backend/` یک بک‌اند واقعی (Cloudflare Workers + پایگاه‌دادهٔ D1) است،
جدا از اپ فلاتر.

**مشکل قبلی:** تابع `fail(code, fa, en)` در ۱۰ فایل `backend/src/routes/*.ts`
(academy, admin, advisor, ai, auth, curriculum, engagement, exams, parents,
seminars) فقط دو زبان پشتیبانی می‌کرد. کلاینت (`ApiClient._extractServerMessage`)
هم همیشه `message_fa` را اول امتحان می‌کرد، صرف‌نظر از زبان انتخابی کاربر —
یعنی حتی کاربر انگلیسی هم پیام فارسی می‌دید.

**راه‌حلی که پیاده شد:**
1. هر ۲۱۳ فراخوانی `fail(...)` در ۱۰ فایل (۸۲ پیام یکتا) با `message_ps` و
   `message_fr` تکمیل شد؛ خودِ تابع `fail()` در هر فایل هم به‌روزرسانی شد تا
   این دو فیلد را در پاسخ JSON برگرداند (پارامترهای اختیاری با fallback به
   انگلیسی، تا هیچ فراخوانی قدیمی خراب نشود).
2. `ApiClient._extractServerMessage` در `lib/core/network/api_client.dart`
   بازنویسی شد: حالا بر اساس `localeCode` جاری اپ، فیلد زبان مناسب را از
   پاسخ سرور انتخاب می‌کند (نه همیشه فارسی) و در نبودش به فارسی → انگلیسی →
   هر پیام موجود دیگر برمی‌گردد.
3. `npx tsc --noEmit` روی بک‌اند بدون خطا اجرا شد.

**برای فعال‌شدن در تولید، هنوز لازم است:**
- `cd backend && npm run deploy` — طبق `backend/README.md`.
- انتشار نسخهٔ جدید اپ فلاتر (چون تغییر `_extractServerMessage` سمت کلاینت
  است) طبق مراحل بخش ۳ پایین.
- این دو دیپلوی به‌ترتیب خاصی نیاز ندارند: بک‌اند قدیمی با کلاینت جدید
  سازگار است (چون کلاینت به فارسی/انگلیسی fallback می‌کند)، و بک‌اند جدید با
  کلاینت قدیمی هم سازگار است (چون فیلدهای اضافه را نادیده می‌گیرد).

## ۳. برای اینکه تغییرات امروز واقعاً در اپ بیاید

تمام کاری که امروز انجام شد فقط در کد فلاتر (`lib/`) بود — **هیچ تغییری
در دیتابیس یا سرور لازم نیست** تا این ترجمه‌ها فعال شوند، چون سیستم
ترجمهٔ اپ (`context.tr()` + ۴ فایل `translations/fa|en|ps|fr.dart`) کاملاً
محلی و درون‌خودِ اپ است.

مراحل لازم:
1. `flutter analyze` — بررسی نبود خطای کامپایل (توصیه‌شده قبل از هرچیز،
   چون امروز چند کلاس مثل `ApiClient`، `StudentManagementMockDataSource`،
   `GuardianLinkStore` امضای سازنده/متدشان تغییر کرد).
2. `flutter pub get` (فقط اگر pubspec تغییر کرده باشد — امروز نکرده).
3. ساخت نسخهٔ جدید و انتشار طبق پلتفرم:
   - وب: `flutter build web` → آپلود پوشهٔ `build/web` به هاست فعلی‌تان.
   - اندروید: `flutter build appbundle` → آپلود در Google Play Console.
   - iOS: `flutter build ipa` → آپلود در App Store Connect.
4. **دیتابیس (D1) دست نمی‌خورد** — داده‌های واقعی کاربران (نام، ایمیل،
   نمرات و...) محتوا هستند، نه متن رابط کاربری؛ ترجمه نمی‌شوند و نباید
   بشوند.
5. **بک‌اند (Cloudflare Worker) دست نمی‌خورد** — مگر تصمیم بگیرید مشکل
   بخش ۲ بالا (پیام‌های خطای سرور) را هم حل کنید؛ در آن صورت باید در
   `backend/src/routes/*.ts` تغییر بدهید و دوباره `npm run deploy` بزنید
   (طبق `backend/README.md`).

## ۴. نکتهٔ مهم دربارهٔ Mock در برابر بک‌اند واقعی

در `lib/features/auth/presentation/providers/auth_providers.dart`:
```dart
const bool kUseLiveBackend = bool.fromEnvironment('USE_LIVE_BACKEND', defaultValue: true);
```
پیش‌فرض الان `true` است — یعنی اپ واقعاً به بک‌اند Cloudflare وصل می‌شود،
نه به داده‌های Mock. بخش زیادی از کاری که امروز روی فایل‌های
`*_mock_datasource.dart` انجام شد (مثلاً `StudentManagementMockDataSource`،
`ReportsMockDataSource`) فقط وقتی فعال می‌شود که اپ با
`--dart-define=USE_LIVE_BACKEND=false` اجرا شود (یعنی حالت تست/دموی محلی).
در حالت عادی (پیش‌فرض)، داده‌های واقعی از بک‌اند D1 می‌آیند و آن رشته‌های
مضمون (نام‌های نمونه، امتیازها) اصلاً دیده نمی‌شوند — اما ترجمهٔ رابط
کاربری اطراف‌شان (دکمه‌ها، برچسب‌ها، پیام‌های خطای پیش‌فرض کلاینت) در هر
دو حالت فعال است.
