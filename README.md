# Afghanistan Girls Digital School — Flutter Client

این پروژه اپ فلاتر «مکتب دیجیتال دختران افغانستان» است — به یک بک‌اند واقعی (Cloudflare Workers + D1، پوشهٔ `backend/`) وصل است. نسخهٔ ۲.۰ سیستم رقابت/گیمیفیکیشن (۵۰ مقام، جدول رتبه‌بندی، میشن‌های روزانه، نقشهٔ‌راه شبه‌سه‌بعدی، و «آرنای زنده» — نبرد هفتگی زندهٔ WebSocket برای مقام اول) را اضافه می‌کند.

## اجرا

```bash
flutter pub get
flutter run -d chrome     # یا هر دستگاه دیگر
flutter analyze           # بررسی سلامت کد
```

## نکات مهم

- **بک‌اند واقعی متصل است** (`kUseLiveBackend = true` پیش‌فرض — `lib/features/auth/presentation/providers/auth_providers.dart`). نسخه‌های `*_mock_datasource.dart` هنوز برای توسعهٔ محلی/دموی UI بدون سرور نگه داشته شده‌اند (`flutter run --dart-define=USE_LIVE_BACKEND=false`) — همان الگوی Repository Pattern (بخش ۲۴.۳ سند) که هر دو پیاده‌سازی را بدون تغییر در `presentation/`/`domain/` قابل تعویض نگه می‌دارد.
- معماری: Clean Architecture سه‌لایه به‌ازای هر Feature (`domain` مستقل از Flutter، `data` پیاده‌سازی دسترسی داده، `presentation` وابسته به Flutter) — طبق بخش ۲۴.۱ سند.
- مدیریت وضعیت: Riverpod.
- مسیریابی: go_router، تمام مسیرها در `lib/app/router/app_router.dart`.
- زبان‌ها: فارسی (dari)، پشتو، انگلیسی — سوئیچ زبان از پروفایل/تنظیمات.
- تم: روشن/تاریک، سوئیچ در پروفایل/تنظیمات.
- حساب‌های نمایشی (Mock) برای ورود: `student@demo.com` / `Student123`، `admin@demo.com` / `Admin123`، `parent@demo.com` / `Parent123`، `instructor@demo.com` / `Instructor123`.

## ساختار پوشه (طبق بخش ۲۴.۴ سند)

```
lib/
├── main.dart
├── app/            (router, theme)
├── core/           (constants, errors, usecase base, localization, widgets)
├── features/       (هر ویژگی: domain/data/presentation)
├── shared_models/
└── l10n/
```
