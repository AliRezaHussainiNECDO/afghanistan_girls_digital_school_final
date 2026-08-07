# متن آماده برای فرم‌های استور — Afghanistan Girls Digital School

این سند برای کپی‌پیست مستقیم در Google Play Console و App Store Connect آماده شده،
بر اساس بررسی واقعی کد و Privacy Policy زندهٔ پروژه (`afghanistangirlsdigitalschool.org/privacy`).

---

## بخش ۱: Google Play Console

### Data safety (امنیت داده‌ها)

**آیا اپ داده جمع‌آوری می‌کند؟** بله.
**آیا داده به شخص ثالث فروخته/اشتراک‌گذاری می‌شود؟** خیر.
**آیا داده در انتقال رمزنگاری می‌شود؟** بله (HTTPS/TLS برای همهٔ درخواست‌ها).
**آیا کاربر می‌تواند درخواست حذف داده بدهد؟** بله (از طریق پروفایل یا تماس با پشتیبانی).

| دسته | نوع داده | جمع‌آوری می‌شود؟ | هدف | اختیاری؟ |
|---|---|---|---|---|
| Personal info | نام، تاریخ تولد | بله | عملکرد اپ (شناسایی حساب، محتوای متناسب با سن) | اجباری (تاریخ تولد رمزنگاری‌شده AES-256 ذخیره می‌شود) |
| Personal info | ایمیل | بله | ورود، تأیید حساب، بازیابی رمز | اختیاری (شماره تماس هم جایگزین است) |
| Personal info | شماره تماس | بله | ورود/بازیابی حساب | اختیاری (رمزنگاری‌شده AES-256) |
| Messages | پیام‌های چت (متنی/صوتی) | بله | ارتباط شاگرد/استاد/والد + معلم هوشمند | اجباری برای استفاده از این قابلیت‌ها |
| Photos/Videos | عکس پروفایل، عکس مشق برای نمره‌دهی AI | بله | شخصی‌سازی حساب + نمره‌دهی خودکار مشق | اختیاری |
| App activity | پیشرفت درسی، نتایج امتحان، تعامل درون‌اپی | بله | عملکرد اصلی اپ آموزشی | اجباری |
| App info & performance | لاگ کرش (Firebase Crashlytics) | بله | رفع باگ و پایداری اپ | اجباری (غیرقابل غیرفعال‌سازی) |
| Device or other IDs | شناسهٔ دستگاه (برای Push Notification) | بله | ارسال اعلان (نمره، پیام جدید) | اختیاری (اگر اعلان را رد کنید جمع نمی‌شود) |
| Location | — | خیر | — | — |
| Financial info | — | خیر | — | — |
| Web browsing | — | خیر | — | — |

**نکتهٔ مهم برای فرم:** گزینهٔ «Data is encrypted in transit» را بله بزنید. گزینهٔ
«Users can request data deletion» را بله بزنید. **تبلیغات (Ads):** خیر — این اپ
هیچ SDK تبلیغاتی ندارد.

### Content rating (پرسشنامهٔ IARC)

- خشونت: خیر
- محتوای جنسی: خیر
- زبان توهین‌آمیز: خیر (چت توسط تیم/سیستم بازبینی می‌شود)
- مواد مخدر/الکل: خیر
- قمار: خیر
- ارتباط کاربر با کاربر (User-generated content / chat): **بله** — چون چت
  بین شاگرد/استاد/والد/معلم هوشمند وجود دارد، حتماً «Users can interact
  and exchange content» را علامت بزنید و توضیح دهید که پیام‌ها بازبینی
  می‌شوند.
- خرید درون‌برنامه‌ای: خیر

با این پاسخ‌ها معمولاً رتبهٔ «Everyone» یا «Everyone 10+» می‌گیرد (بسته به
سؤالات دقیق IARC).

### Target audience and content

- **گروه سنی هدف را صادقانه انتخاب کنید:** شامل زیر ۱۸ سال (طبق راهنمای قبلی
  خودتان). این باعث فعال شدن الزامات Google Play Families Policy می‌شود.
- تبلیغات رفتاری/شخصی‌سازی‌شده برای کودکان: **غیرفعال** (چون اصلاً تبلیغاتی
  در اپ نیست، این بخش به‌سادگی رد می‌شود).
- «Appeal to children»: چون اپ آموزشی برای دانش‌آموزان (نه صرفاً کودکان
  خردسال) است، معمولاً به‌عنوان «not primarily child-directed» ولی «has
  users under 18» علامت می‌خورد — دقیقاً طبق راهنمای درون Play Console
  جواب بدهید؛ اگر مطمئن نیستید، محافظه‌کارانه‌تر (سخت‌گیرانه‌تر) را انتخاب
  کنید.

### توضیح کوتاه و بلند اپ (Store listing) — پیش‌نویس

**کوتاه (۸۰ کاراکتر):**
> پلتفرم آموزشی رایگان برای ادامهٔ تحصیل دختران افغان

**بلند (پیش‌نویس، قابل ویرایش):**
> مکتب دیجیتال دختران افغانستان یک پلتفرم آموزشی رایگان است که به دختران
> افغان کمک می‌کند تحصیل خود را ادامه دهند — با نصاب درسی رسمی افغانستان،
> امتحانات و آزمون فصل، معلم هوشمند مبتنی بر کتاب‌های درسی، و امکان اتصال
> حساب والدین برای پیگیری پیشرفت فرزند. ثبت‌نام با کد دعوت (Invite Code)
> انجام می‌شود.

---

## بخش ۲: App Store Connect (iOS)

### App Privacy (نوع داده‌های جمع‌آوری‌شده)

همان جدول بالا؛ اپل این دسته‌ها را می‌خواهد:
- **Contact Info**: نام، ایمیل، شماره تلفن → «Linked to you»
- **User Content**: پیام‌های چت، عکس‌ها → «Linked to you»
- **Identifiers**: شناسهٔ دستگاه (push) → «Linked to you»
- **Usage Data**: پیشرفت درسی/تعامل اپ → «Linked to you»
- **Diagnostics**: کرش لاگ (Crashlytics) → «Linked to you» یا «Not Linked»
  (بسته به تنظیم Crashlytics؛ پیش‌فرض معمولاً Linked است)

برای «Data Used to Track You»: **خیر** (هیچ داده‌ای برای تبلیغات/ردیابی
بین‌اپی استفاده نمی‌شود).

### Age rating

به سؤالات مشابه Content rating گوگل جواب دهید؛ چون user-generated content
(چت) دارید، Apple معمولاً حداقل **۱۲+** یا مشابه آن را پیشنهاد می‌دهد —
دقیقاً طبق فرم جواب بدهید و توضیح دهید که چت بازبینی می‌شود.

### App Review Information — یادداشت برای بازبین اپل (پیش‌نویس)

> This app ("Afghanistan Girls Digital School") is a free educational
> platform built to help Afghan girls continue their education remotely.
> Registration requires an invite code (distributed by the organization,
> not public sign-up). All chat messages are reviewed by our moderation
> system to protect underage users. Sensitive personal data (phone number,
> birth date) is encrypted at rest (AES-256). For review purposes, you can
> use the following test account: [یک حساب تست بسازید و اینجا وارد کنید —
> ایمیل/رمز، قبل از ارسال].

**نکته:** حتماً قبل از ارسال یک حساب تست واقعی (super_admin یا معلم) بسازید
و اطلاعاتش را در همین بخش به اپل بدهید، وگرنه بازبین نمی‌تواند وارد اپ شود
و رد می‌کند.

---

## کاری که من نمی‌توانم انجام دهم (نیاز به حساب شخصی شما)

- ثبت‌نام Apple Developer Program (نیاز به Apple ID و کارت پرداخت شما).
- ورود به Google Play Console / App Store Connect و پر کردن این فرم‌ها
  (نیاز به حساب گوگل/اپل خودتان؛ من نمی‌توانم به آن‌ها لاگین کنم).
- ساخت حساب Codemagic و اتصال به GitHub (نیاز به تأیید هویت شما).
- اجرای `flutter build appbundle --release` — سندباکس من Flutter/Android
  SDK ندارد؛ این را باید در کامپیوتر خودتان (همان‌جایی که قبلاً iOS
  sideload کردید) اجرا کنید.
