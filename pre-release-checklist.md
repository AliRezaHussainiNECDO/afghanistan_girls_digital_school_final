# چک‌لیست پیش از انتشار — Afghanistan Girls Digital School

بررسی کامل کد Android، iOS و بک‌اند (Cloudflare Workers) قبل از انتشار در Google Play، App Store و توزیع مستقیم APK. موارد به ترتیب اولویت دسته‌بندی شده‌اند.

## 🔴 بحرانی — قبل از هر انتشاری باید رفع شود

### ۱. رمز عبور واقعی در سورس‌کد (پلاک‌تکست)
فایل `lib/features/auth/data/datasources/auth_mock_datasource.dart` رمز عبور واقعی حساب مدیر کل شما را به‌صورت متن‌ساده دارد:

```dart
'alireza.necdo@gmail.com': (password: 'loveNJ@$2026', ...)
```

خبر خوب: سوییچ `kUseLiveBackend` پیش‌فرضش `true` است، پس این DataSource در build عادی (`flutter build apk --release` بدون `--dart-define=USE_LIVE_BACKEND=false`) فعال نمی‌شود. اما:
- این رمز همین الان داخل تاریخچهٔ Git شما (حتی اگر ریپو خصوصی باشد) ثبت شده.
- چون این پیام را هم به من نشان دادید، این رمز را **دیگر معتبر ندانید**.

**اقدام لازم:** رمز عبور همین حساب (`alireza.necdo@gmail.com`) را در دیتابیس واقعی سرور همین امروز عوض کنید، و در کد، مقدار رمز مربوط به mock account را با یک placeholder غیرواقعی (مثل `'demo-only-not-real'`) جایگزین کنید.

### ۲. رمزگذاری اطلاعات حساس کاربران (PII) هنوز فعال نیست
طبق `backend/wrangler.toml`، کلید `COLUMN_ENCRYPTION_KEY` (برای رمزنگاری AES-256 شمارهٔ تلفن و تاریخ تولد) تنظیم نشده — یعنی این داده‌ها به‌صورت متن‌ساده در دیتابیس ذخیره می‌شوند. با توجه به اینکه کاربران این اپ دختران دانش‌آموز افغان هستند، افشای این اطلاعات در صورت نفوذ به دیتابیس می‌تواند خطر امنیتی/جانی واقعی برای آن‌ها داشته باشد — این فقط یک الزام قانونی معمول نیست.

**اقدام لازم:**
```
openssl rand -base64 32 | wrangler secret put COLUMN_ENCRYPTION_KEY
```
سپس یک‌بار endpoint بک‌فیل را برای رمزنگاری کاربران قبلی صدا بزنید (جزئیات در کامنت‌های `wrangler.toml`).

## 🟠 قبل از ارسال به استورها لازم است

### ۳. شمارهٔ نسخه هنوز در حالت پیش‌نویس است
`pubspec.yaml`: `version: 0.1.0+1` و توضیح پروژه هنوز می‌نویسد «Phase 1: UI Prototype with mock data». برای انتشار واقعی باید نسخه‌ای مثل `1.0.0+1` بگذارید و توضیح را به‌روزرسانی کنید.

### ۴. صفحهٔ عمومی سیاست حریم خصوصی (Privacy Policy URL)
یک متن حریم خصوصی خوب و ۴زبانه *داخل* اپ دارید (`terms_gate.dart`) — عالیه، ولی Google Play و App Store هر دو یک **URL عمومی و قابل‌دسترس** برای Privacy Policy در تنظیمات Store Listing می‌خواهند (نه فقط متن داخل اپ). باید همین متن (یا نسخهٔ خلاصه‌شده) را روی یک صفحه در دامنهٔ `afghanistangirlsdigitalschool.org/privacy` میزبانی کنید و لینکش را در Play Console / App Store Connect وارد کنید.

### ۵. سیاست‌های ویژهٔ اپ‌های کودکان (Google Play Families / کمتر از ۱۸ سال)
چون کاربران شامل شاگردان خردسال می‌شوند، Google Play فرم «Target Audience and Content» و احتمالاً الزامات Families Policy را می‌خواهد (ممنوعیت تبلیغات رفتاری، محدودیت جمع‌آوری داده). پیش از ارسال، بخش «App content» در Play Console را با دقت پر کنید — این بخش رد شدن اپ در بازبینی اولیه یک دلیل شایع است.

### ۶. آیکون adaptive اندروید ساخته نشده
آیکون فعلی (`mipmap-xxxhdpi/ic_launcher.png`) یک تصویر مربعی خوب و برندشده است، ولی پوشهٔ `mipmap-anydpi-v26` (آیکون adaptive لایه‌ای که لانچرهای مدرن اندروید نیاز دارند) وجود ندارد. روی برخی گوشی‌ها ممکن است آیکون به‌شکل نامناسب بریده/نمایش داده شود. پیشنهاد: از `flutter_launcher_icons` برای تولید خودکار همهٔ اندازه‌ها + نسخهٔ adaptive استفاده کنید.

## 🟢 خوب/تأییدشده (نیازی به تغییر نیست)

- **امضای Release**: `android/key.properties` موجود است و build.gradle.kts به‌درستی بین کلید release/debug سوییچ می‌کند.
- **مجوزهای iOS**: `Info.plist` توضیح فارسی مناسب برای دوربین/میکروفون/گالری دارد — آمادهٔ بازبینی App Store.
- **رمزهای بک‌اند**: هیچ کلید API واقعی داخل `wrangler.toml` یا کد commit نشده؛ همه از طریق `wrangler secret put` تزریق می‌شوند. `.gitignore` هم `key.properties`، `*.jks`، `backend/.dev.vars` را درست پوشش می‌دهد.
- **هش رمز عبور و Rate Limiting**: بک‌اند واقعی (`auth.ts`) از `hashPassword`/`verifyPassword` استفاده می‌کند (نه متن‌ساده) و login/register/forgot-password همه Rate Limit دارند.
- **CORS**: `ALLOWED_ORIGIN` محدود به دامنهٔ خودتان است (نه `*`).
- **کرش سمینار ویدیویی**: در همین گفتگو رفع و روی گوشی واقعی تأیید شد (`dropbox_app_key` + برچسب اپ).
- **بدون کد کثیف باقی‌مانده**: هیچ TODO/FIXME در `lib/` پیدا نشد.

## چک‌لیست نهایی پیشنهادی قبل از دکمهٔ انتشار

1. رمز حساب `alireza.necdo@gmail.com` را در سرور عوض کنید و در `auth_mock_datasource.dart` رمز نمایشی را جایگزین کنید.
2. `COLUMN_ENCRYPTION_KEY` را تنظیم و بک‌فیل کنید.
3. نسخه را در `pubspec.yaml` به `1.0.0+1` (یا مشابه) تغییر دهید.
4. صفحهٔ عمومی Privacy Policy را روی دامنه میزبانی و در Play Console/App Store Connect لینک کنید.
5. فرم «App content» / «Target Audience» را در Play Console تکمیل کنید.
6. آیکون adaptive اندروید را بسازید (اختیاری ولی توصیه‌شده).
7. یک بار دیگر `flutter build apk --release` + تست سمینار روی گوشی واقعی، برای اطمینان نهایی.
