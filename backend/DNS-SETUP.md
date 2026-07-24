# تنظیمات DNS باقی‌مانده (`www` + DMARC)

این دو مورد را **باید مستقیماً در داشبورد Cloudflare خودتان** اعمال کنید —
هیچ‌کدام کد نیستند و از بیرون (بدون ورود به حساب Cloudflare شما) قابل اعمال
نیستند. اگر بخواهید، می‌توانم با دسترسی کامپیوتر و بعد از تأیید شما این
مراحل را مستقیماً روی صفحهٔ داشبورد شما هم انجام دهم؛ در غیر این صورت مراحل
دقیق زیر را خودتان دنبال کنید (۵ دقیقه، بدون نیاز به دانش فنی خاص).

## ۱) رکورد `www` — رفع خطای «www کار نمی‌کند»

**Cloudflare Dashboard → دامنهٔ `afghanistangirlsdigitalschool.org` → DNS → Records → Add record**

| فیلد | مقدار |
|---|---|
| Type | `CNAME` |
| Name | `www` |
| Target | `afghanistangirlsdigitalschool.org` |
| Proxy status | **Proxied** (ابر نارنجی — نه DNS only) |

سپس یک قانون تغییرمسیر ۳۰۱ بسازید تا `www` همیشه به آدرس اصلی (بدون www)
هدایت شود (یکتاسازی SEO/SSL):

**Rules → Redirect Rules → Create rule**

- **When incoming requests match:** `Hostname equals www.afghanistangirlsdigitalschool.org`
- **Then:** Dynamic redirect →
  `concat("https://afghanistangirlsdigitalschool.org", http.request.uri.path)`
- **Status code:** `301` (Permanent Redirect)

## ۲) رکورد DMARC — جلوگیری از جعل ایمیل به نام مکتب

طبق docs/02 (بند ۳۳)، SPF/DKIM از قبل از طریق Resend تنظیم شده‌اند؛ فقط DMARC
باقی مانده است.

**DNS → Records → Add record**

| فیلد | مقدار |
|---|---|
| Type | `TXT` |
| Name | `_dmarc` |
| Content | `v=DMARC1; p=none; rua=mailto:admin@afghanistangirlsdigitalschool.org; pct=100; adkim=r; aspf=r` |

نکات مهم:
- **از `p=none` شروع کنید، نه `p=reject`.** این حالت فقط گزارش می‌دهد و هیچ
  ایمیلی را مسدود نمی‌کند — چند هفته گزارش‌ها را در `rua` بررسی کنید تا مطمئن
  شوید همهٔ ایمیل‌های واقعی مکتب (از طریق Resend) به‌درستی SPF/DKIM را پاس
  می‌کنند. بعد از اطمینان، به `p=quarantine` و در نهایت `p=reject` سخت‌گیرتر
  کنید — رفتن مستقیم به `p=reject` بدون دورهٔ پایش، در صورت هر ناهماهنگی
  پیکربندی، می‌تواند ایمیل‌های واقعیِ خودِ مکتب (تأیید ثبت‌نام، بازیابی رمز) را
  هم مسدود کند.
- آدرس `rua` باید یک صندوق ایمیل واقعی و در دسترس شما باشد (گزارش‌های DMARC
  آنجا می‌رسند) — اگر `admin@afghanistangirlsdigitalschool.org` صندوق واقعی
  ندارد، آن را با ایمیلی که واقعاً چک می‌کنید جایگزین کنید.

## بعد از اعمال

هر دو رکورد فوراً فعال نمی‌شوند (انتشار DNS تا ۲۴ ساعت، معمولاً چند دقیقه).
برای تأیید:
```
dig www.afghanistangirlsdigitalschool.org
dig TXT _dmarc.afghanistangirlsdigitalschool.org
```
