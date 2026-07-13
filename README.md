# Afghanistan Girls Digital School — Flutter Client

این پروژه خروجی **فاز ۱ (UI Prototype)** طبق نقشهٔ راه سند `SPEC v2.3` (بخش ۲۵.۳) است.

## اجرا

```bash
flutter pub get
flutter run -d chrome     # یا هر دستگاه دیگر
flutter analyze           # بررسی سلامت کد
```

## نکات مهم

- **این فاز بک‌اند واقعی ندارد.** تمام `DataSource` ها در `data/datasources/*_mock_datasource.dart` هستند و داده‌های ساختگی (Mock) برمی‌گردانند — دقیقاً طبق الگوی Repository Pattern سند (بخش ۲۴.۳)، تا در فاز ۲ به بعد فقط این لایه با نسخهٔ واقعی (Dio + REST API) جایگزین شود، بدون تغییر در `presentation/` یا `domain/`.
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
