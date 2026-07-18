# استقرار قابلیت جدید: لاگ بازبینی سراسری (audit_logs) — بخش ۲۰.۳ سند

## چه چیزی اضافه شد (فقط افزودنی — هیچ رفتار موجودی تغییر نکرد)

- **Migration جدید:** `migrations/0026_audit_logs.sql` — جدول `audit_logs` + ایندکس‌ها + دو Trigger که هر UPDATE/DELETE را رد می‌کنند (**Append-only/Immutable** در سطح خود دیتابیس).
- **کتابخانه جدید:** `src/lib/audit.ts` — تابع `logAudit` (هرگز خطا پرتاب نمی‌کند؛ شکست لاگ مسیر کاربر را نمی‌شکند) + `clientIp`.
- **نقاط ثبت (همه با `waitUntil` در پس‌زمینه):**

| فایل | رویدادها |
|---|---|
| `routes/ai.ts` | `ai_invocation` — **با Prompt کامل ارسالی (messages)** + خلاصه پاسخ؛ هم موفق هم خطای Upstream (بخش ۵.۶) |
| `routes/auth.ts` | `user_register` (+ شناسه کد دعوت مصرف‌شده)، `login_success`، `login_failed`، `login_blocked`، `logout` |
| `routes/admin.ts` | `user_status_change` (۳ مسیر)، `invite_code_issue`، `invite_code_revoke`، `password_reset_link`، `safety_resolve`، `curriculum_wipe` (priority=high) |
| `routes/cms.ts` | `content_status_change` (شامل publish) و `content_delete` برای کتاب/درس/سؤال |
| `routes/parents.ts` | `parent_link_request` (والد)، `parent_link_decision` (تأیید/رد دانش‌آموز) |

- **Endpoint جدید فقط‌خواندنی:** `GET /api/v1/admin/audit-logs?actionType=&actorId=&priority=&before=&limit=` (فقط Super Admin؛ عمداً هیچ مسیر ویرایش/حذف ندارد).

## دستورات استقرار (در PowerShell داخل پوشه `backend/`)

```powershell
# ۱) بررسی کامپایل (اختیاری ولی توصیه‌شده)
npx tsc --noEmit

# ۲) اعمال Migration روی دیتابیس اصلی
npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0026_audit_logs.sql

# ۳) استقرار Worker
npx wrangler deploy
```

## تست سریع بعد از استقرار

```powershell
# با توکن Admin:
# چند لاگ آخر
curl -H "Authorization: Bearer <ADMIN_TOKEN>" "https://api.afghanistangirlsdigitalschool.org/api/v1/admin/audit-logs?limit=10"

# تست Immutability (باید با خطای append-only رد شود):
npx wrangler d1 execute afghan_girls_school_db --remote --command "DELETE FROM audit_logs"
```

## رابط کاربری مدیر (اضافه‌شده در همین فاز)

صفحهٔ **«مرکز عملیات و لاگ بازبینی»** در اپ فلاتر: مسیر `/admin/audit-logs` (آیتم جدید منوی مدیر).
فایل‌ها: `lib/features/admin/audit_logs/` (entity + datasource + providers + screen).
قابلیت‌ها: تم تاریک سینمایی، چیپ‌های فیلتر (همه/AI/امنیتی/حساس)، جستجوی زندهٔ محلی (نقش/IP/شناسه/ایمیل)، لیست واکنش‌گرا با Infinite Scroll و نقطه‌های نئونی وضعیت، «بازرس Prompt» برای رویدادهای AI (پنجرهٔ RAG Context + گفتگوی حبابی)، «نقشهٔ بردار امنیتی» برای ورودهای ناموفق، و نمایش قبل/بعد/Payload برای سایر رویدادها. پارس JSON کاملاً دفاعی است (رکورد خراب هرگز اپ را کرش نمی‌دهد).

## یادداشت‌ها

- Prompt های AI تا ~۳۰هزار نویسه ذخیره می‌شوند (بزرگ‌تر با علامت `truncated` بریده می‌شود).
- تناقض شناخته‌شده با Data-Minimization (مشکل #19 سند مشکلات): این جدول حذف‌ناپذیر است و Prompt شاگرد را نگه می‌دارد؛ سیاست نگه‌داری (مثلاً آرشیو دوره‌ای) تصمیم بعدی است.
- `login_failed` عمداً IP را ثبت می‌کند — پایه داده برای Rate Limiting آینده (مشکل #4).
