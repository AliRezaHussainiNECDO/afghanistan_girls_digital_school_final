# بک‌اند مکتب دیجیتال دختران افغانستان (Cloudflare Workers)

این پوشه یک بک‌اند واقعی و آماده برای دیپلوی است — کدش کامل نوشته شده،
فقط باید با حساب Cloudflare خودتان وصلش کنید. چون امکان تایپ در ترمینال
واقعی کامپیوتر شما برای دستیار وجود ندارد، این چند دستور را خودتان در
یک ترمینال (PowerShell یا CMD) داخل همین پوشهٔ `backend/` اجرا کنید.

## قدم ۱ — نصب ابزارها (یک‌بار)

```
npm install
```

## قدم ۲ — ورود به Cloudflare (یک‌بار)

```
npx wrangler login
```
یک تب مرورگر باز می‌شود؛ با همان حسابی که در dashboard.cloudflare.com
دیدید وارد شوید و اجازه دهید.

## قدم ۳ — ساخت دیتابیس D1 (یک‌بار)

```
npx wrangler d1 create afghan_girls_school_db
```
خروجی این دستور یک `database_id` می‌دهد — آن را کپی کنید و در فایل
`wrangler.toml` به‌جای `REPLACE_WITH_YOUR_D1_DATABASE_ID` جای‌گذاری کنید.

## قدم ۴ — ساخت فضای ذخیرهٔ فایل R2 (یک‌بار)

```
npx wrangler r2 bucket create afghan-girls-school-files
```

## قدم ۵ — اجرای Schema دیتابیس (یک‌بار، و هر بار که schema.sql تغییر کرد)

```
npm run db:migrate
```

## قدم ۶ — دیپلوی

```
npm run deploy
```
در پایان یک آدرس مثل:
```
https://afghan-girls-school-api.<your-subdomain>.workers.dev
```
به شما داده می‌شود. این همان آدرسی است که باید در اپ فلاتر به‌عنوان
`baseUrl` بک‌اند تنظیم شود (فایل `lib/core/network/api_client.dart` —
در فاز بعدی این ارتباط وصل می‌شود).

## اختیاری — وصل کردن به دامنهٔ خودتان

چون دامنهٔ `afghanistangirlsdigitalschool.org` را در Cloudflare دارید،
می‌توانید به‌جای آدرس workers.dev، از `api.afghanistangirlsdigitalschool.org`
استفاده کنید: خط `routes = [...]` در `wrangler.toml` را از حالت کامنت
خارج کنید و دوباره `npm run deploy` بزنید.

## توسعهٔ محلی (اختیاری، برای تست قبل از دیپلوی)

```
npm run dev
```

## نکات امنیتی قبل از انتشار عمومی

- تابع `isAdmin()` در `src/index.ts` فعلاً همیشه `true` برمی‌گرداند (برای
  سادگی فاز ۱). قبل از انتشار واقعی، باید احراز هویت واقعی (JWT کاربر
  مدیر) اضافه شود.
- `ALLOWED_ORIGIN` در `wrangler.toml` را از `*` به آدرس دقیق اپ وب خودتان
  محدود کنید.
