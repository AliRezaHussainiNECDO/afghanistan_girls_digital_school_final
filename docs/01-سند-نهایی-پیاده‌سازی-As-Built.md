# سند نهایی پیاده‌سازی (As-Built) — مکتب دیجیتال دختران افغانستان
**تاریخ:** 2026-07-18 | **منبع حقیقت:** کد واقعی مخزن (نه سند SPEC) | **وضعیت:** منطبق با آخرین کامیت‌ها تا 2026-07-17

این سند وضعیت **واقعاً ساخته‌شده** پلتفرم را توصیف می‌کند و برای هر جا که با SPEC v2.3 فرق دارد، همین سند معتبر است.

---

## ۱. معماری واقعی سیستم

```
Flutter App (Android / iOS / Web / Windows)
        │ HTTPS  —  BASE_URL: https://api.afghanistangirlsdigitalschool.org/api/v1
        ▼
Cloudflare Worker «afghan-girls-school-api» (Hono, TypeScript, ~6,500 خط)
        ├── D1 (SQLite) — دیتابیس اصلی «afghan_girls_school_db»
        ├── R2 — فایل‌ها (PDF کتاب‌ها، پیام صوتی، آواتار) «afghan-girls-school-storage»
        ├── Cloudflare Stream — پخش زنده سمینار (+ فال‌بک Jitsi موبایل + لینک جلسه دستی)
        └── AI Provider (سازگار OpenAI) — مدل: gpt-4o-mini
              ├── Embeddings: text-embedding-3-small → جدول lesson_embeddings (شباهت کسینوسی در Worker)
              └── صدا: Azure TTS/STT (فال‌بک: Whisper/TTS همان Provider)
```

- **کلاینت:** Flutter ≥3.24 (فعلی 3.44.2 / Dart 3.12.2)، Riverpod 2، GoRouter 14، Dio 5، Clean Architecture per-feature (domain/data/presentation) با سوییچ `kUseLiveBackend` (پیش‌فرض **true**).
- **احراز هویت:** JWT Access + Refresh Token (جدول `refresh_tokens`)، هش رمز **PBKDF2-SHA256 (۱۰۰هزار تکرار)**.
- **ثبت‌نام دانش‌آموز:** با Invite Code (طبق SPEC ۳ب) + **تأیید ایمیل** (`email_tokens`، Endpoint های `verify-email`/`resend-verification`) — الحاق جدید نسبت به SPEC.
- **قرارداد خطا:** JSON استاندارد `{success:false, error:{code, message_fa, message_en}}` + نگهبان سراسری خطا و 404 در Worker.

## ۲. نقش‌ها و مسیرهای اپ (از `app_routes.dart`)

| نقش | مسیرها |
|---|---|
| دانش‌آموز | داشبورد، نقشه صنف، نصاب (مضمون→فصل→درس)، معلم AI، **مشاور**، **پلان مطالعه**، امتحانات، حاضری، کتابخانه، سمینار، چت، اعلان، پروفایل، گواهی‌نامه |
| والد | داشبورد، نمرات فرزند، سمینارها، تماس با مدیر، اعلان، پروفایل |
| Instructor | خانه، تماس با مدیر، اعلان، پروفایل (+ **ثبت‌نام مستقیم `/register/instructor` با کد دعوت مخصوص**) |
| Admin | داشبورد، کاربران/شاگردان/معلمان/والدین، CMS، مدیریت امتحانات (تألیف)، معلم AI (+Bulk Import)، صف ایمنی، نظارت چت (کلاس‌به‌کلاس)، گزارش‌ها، سمینارها، Submissions، اعلان‌ها |
| مشترک | جامعه (حافظه جمعی) `/community`، اتاق سمینار `/seminar-room/:id`، پخش زنده `/seminar-live/:id` |

## ۳. ماژول‌های بک‌اند (routes زیر `/api/v1`)

| Route | شرح | خطوط |
|---|---|---|
| `auth` | register (invite+email verify)، login، refresh، logout، me، change-password، forgot/reset-password، verify-email | 614 |
| `curriculum` | صنف/مضمون/فصل/درس + بازدید درس + پیشرفت (lib/progress.ts) | 611 |
| `exams` | امتحانات منتشرشده per صنف، تلاش‌ها (`exam_attempts`)، نمره سرور-ساید، گواهی‌نامه | 425 |
| `engagement` | حاضری و اعلان‌ها | 100 |
| `admin` | مدیریت کاربران/کدهای دعوت/شاگردان (لیست فیلتردار، جزئیات، گزارش AI، تعلیق، ریست رمز)، والدین، معلمان | 1809 |
| `seminars` | CRUD سمینار + ثبت‌نام + مالکیت + go-live (Stream) | 515 |
| `parents` | کد سرپرست (`guardian_codes`)، پیوند والد-فرزند، خلاصه فرزند | 307 |
| `ai` | پروکسی LLM معلم هوشمند: Persona ها، چت لاگ، بازیابی معنایی (RAG)، حلقه تسلط تطبیقی، TTS/STT | 555 |
| `media` | چت متنی/صوتی، کتابخانه PDF، فایل‌های R2، رضایت‌نامه | 453 |
| `cms` (`/admin/cms`) | تألیف کتاب/درس/سؤال + فصل‌های برگرفته از کتاب | 167 |
| `memory` | حافظه جمعی: پست/کامنت/ری‌اکشن، هویت از JWT | 242 |
| `academy` | بانک سؤال/کتاب/پاسخ‌های آکادمی (نیمه‌متصل) | 309 |
| `advisor` | مشاور هوشمند (پیام‌ها) | 195 |

## ۴. دیتابیس واقعی (D1 — schema.sql + ۲۵ Migration)

`users`، `invite_codes`، `refresh_tokens`، `email_tokens`، `grades`، `subjects`، `chapters`، `lessons`، `student_lesson_views`، `student_chapter_completions`، `exams`، `questions`، `exam_attempts`، `certificates`، `notifications`، `seminars`، `seminar_registrations`، `guardian_codes`، `parent_student_links`، `safety_events`، `conversations`، `messages`، `chat_reports`، `consents`، `curriculum_books` (متن استخراج‌شده = پایه RAG)، `curriculum_library_books`، `cms_books/lessons/questions`، `memory_posts/comments`، `academy_books/questions/submissions`، `student_points_ledger`، `points_levels`، `ai_teacher_personas`، `ai_teacher_chat_logs`، `ai_teacher_answer_logs`، `lesson_embeddings`، `advisor_messages`.

نکات: پیام flag شده تا تأیید Admin به گیرنده نمی‌رسد (`review_status`)؛ هر گفتگو `class_id` دارد برای نظارت صنف‌به‌صنف؛ گیمیفیکیشن با دفتر امتیاز و سطح‌ها.

## ۵. قابلیت‌های فراتر از SPEC (ساخته‌شده و فعال)

1. **مشاور هوشمند (Advisor)** — گفتگوی مشاوره‌ای جدا از معلم مضمون، با DB واقعی.
2. **پلان مطالعه (Study Plan)** دانش‌آموز.
3. **حافظه جمعی (Collective Memory)** — فید اجتماعی سرورمحور با کامنت/ری‌اکشن، ضد جعل هویت.
4. **گیمیفیکیشن** — امتیاز مبتنی بر تکمیل، سطح‌ها، جشن (confetti).
5. **صدای معلم AI** — TTS/STT (صدای زن دری Azure) + پیام صوتی در چت (ضبط/پخش، R2).
6. **سمینار زنده واقعی** — Cloudflare Stream + اتاق Jitsi (موبایل) + لینک جلسه خارجی؛ مالکیت و ثبت حاضری.
7. **آکادمی** — سیستم موازی بانک سؤال/تصحیح با AI assessment (در مسیر ادغام با امتحانات).
8. **CMS پیشرفته** — آپلود PDF نصاب، استخراج متن (با اصلاح ترتیب RTL)، ساخت فصل از کتاب، ویرایش/حذف کامل فصل، تألیف امتحان توسط Admin، Bulk Import.
9. **RAG + حلقه تسلط تطبیقی** — بازیابی معنایی درس‌محور در همه صنوف/مضامین، لاگ پاسخ‌ها برای سنجش تسلط.
10. **مدیریت تفصیلی شاگرد** — فیلتر (صنف/ولایت/وضعیت/در معرض خطر)، گزارش AI از داده واقعی، تعلیق/فعال‌سازی با دلیل.
11. **تأیید ایمیل + بازیابی رمز با ایمیل + عکس پروفایل/آواتار روی R2 + رضایت‌نامه (consents).**
12. **Onboarding/Welcome + سه زبان (fa/ps/en) + دارک‌مود + RTL.**

## ۶. وضعیت استقرار (تأییدشده از داخل داشبورد Cloudflare — 2026-07-18)

**حساب:** Alireza.necdo@gmail.com | Account ID: `3276f5f2f9915da134fc398e98b6539d` | پلن: Free (Workers: سقف ۱۰۰هزار درخواست/روز — مصرف فعلی ~۸۴۰/روز)

| جزء | مشخصات تأییدشده |
|---|---|
| **Worker (بک‌اند)** | `afghan-girls-school-api` — دامنه سفارشی `api.afghanistangirlsdigitalschool.org` (رکورد DNS از نوع Worker، Proxied) + `afghan-girls-school-api.alireza-necdo.workers.dev` (عمومی). ۸۳۷ فراخوانی/۲۴ساعت، صفر خطا، CPU P90 ≈ ۳.۹ms |
| **متغیرها/Secret های Worker** | Plaintext: `AI_MODEL=gpt-4o-mini`، `AI_PROVIDER_URL` (OpenAI)، `ALLOWED_ORIGIN=*`، `CF_ACCOUNT_ID`، `CF_STREAM_CUSTOMER` — Secret: `AI_PROVIDER_KEY`، `AZURE_TTS_KEY`، `AZURE_TTS_REGION`، `CF_STREAM_TOKEN`، `GROQ_API_KEY`، `JWT_SECRET`، `RESEND_API_KEY` |
| **D1** | `afghan_girls_school_db` (76b6e211-…) — **۴۲ جدول، 2.02MB**، ~۱هزار کوئری/۲۴ساعت، منطقه EEUR، تأخیر P50 ≈ 0.27ms |
| **R2** | `afghan-girls-school-storage` — ۲ آبجکت، 336KB |
| **Pages (وب‌اپ فلاتر)** | پروژه `afghanistan-girls-digital-school-final` متصل به GitHub `AliRezaHussainiNECDO/afghanistan_girls_digital_school_final` با Deploy خودکار؛ دامنه اصلی `afghanistangirlsdigitalschool.org` با CNAME به `…pages.dev` (Proxied) |
| **Tunnel** | `afghanistan-digital-girls-school-server` (6a997c82-…) — Healthy، ۱ Replica روی `DESKTOP-VEB072O` (IP خروجی 46.253.188.141، cloudflared 2026.6.1، windows_amd64)؛ دو مسیر تعریف‌شده: `api.…` → `http://localhost:8080` و دامنه اصلی → `http://localhost:3000` — **توجه: هر دو مسیر توسط رکوردهای DNS (Worker و Pages) سایه‌زده شده‌اند و عملاً ترافیک نمی‌گیرند** |
| **ایمیل** | دریافت: Cloudflare Email Routing (MX route1-3 + SPF + DKIM cf2024-1) — ارسال: **Resend** (DKIM `resend._domainkey` + زیردامنه `send.` روی Amazon SES) |
| **Stream** | کد مشتری `3xsnqty4gq6f5bah` در تنظیمات موجود؛ صفحه Live Inputs خالی — وضعیت اشتراک Stream نامشخص/غیرفعال |
| **CI** | GitHub Actions: Build امضانشده iOS (Manual signing + pod install صریح)؛ Pages هم از همان مخزن Deploy می‌شود |

- BASE_URL اپ: `https://api.afghanistangirlsdigitalschool.org/api/v1` (قابل تزریق با `--dart-define=API_BASE_URL`)
- Observability/Logs در Worker **خاموش** است؛ هیچ Cron Trigger تعریف نشده.
- سرور محلی (i9-14900KF/64GB/RTX5070) از طریق Tunnel آنلاین است ولی فعلاً هیچ ترافیک عمومی به آن نمی‌رسد.

## ۷. آنچه هنوز ساخته نشده (خلاصه — تفصیل در سند مشکلات)

آفلاین/Sync (بخش ۲۲ SPEC)، `audit_logs`، Rate Limiting، رمزگذاری ستونی، WebSocket/Push واقعی، پارامتری‌سازی وزن‌های نمره، ادغام آکادمی، پوشش تست.
