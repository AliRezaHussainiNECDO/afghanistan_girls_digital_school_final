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

## ۷ب. تغییرات بعد از ۱۸ جولای — تا ۲۳ جولای ۲۰۲۶ (این سند تا این تاریخ به‌روز نشده بود)

- **رفع نشتِ اعلان بین کاربران** روی دستگاه مشترک — `NotificationCenter.setOwner(userId)` با ورود/خروج هماهنگ می‌شود و در خروج پاک می‌شود.
- **کرش سامسونگ در ساخت/پخش سمینار** — ریشه‌ای رفع شد: بستهٔ `apivideo_live_stream` کاملاً حذف شد (صفحات پخش زنده جایگزین با اتاق Jitsi/لینک خارجی).
- **کرش هنگام ورود به سمینار (اتاق Jitsi)** — ریشهٔ واقعی: SDK بومی Jitsi/WebRTC بدون درخواست واقعیِ زمان‌اجرای مجوز دوربین/میکروفن صدا زده می‌شد (کرش بومی، خارج از دسترس try/catch دارت). `seminar_room_screen.dart` اکنون پیش از `_jitsiMeet.join()` صراحتاً `PermissionService.request` می‌کند؛ در نبود مجوز، گفتگوی راهنما به تنظیمات نشان می‌دهد نه کرش.
- **سمینار محدود به یک مورد در داشبورد شاگرد** — `LIMIT 1` در `curriculum.ts` به لیست (`upcomingSeminars`) تبدیل شد؛ آرشیو + گزارش خودکار AI برای سمینارهای پایان‌یافته اضافه شد (`seminarReport.ts`, migration 0038).
- **آکادمی (تمرین مضامین) هماهنگ‌تر با امتحانات رسمی شد** (گام اول ادغام، نه ادغام کامل — بند ۳ سند مشکلات هنوز باز است):
  - نمرهٔ تمرین دیگر به کلاینت اعتماد نمی‌کند — سرور از روی `academy_questions` واقعی دوباره نمره می‌دهد (چهارگزینه‌ای/صحیح‌غلط قطعی، تشریحی با AI مشترک با امتحانات رسمی در `lib/essayGrading.ts`).
  - داشبورد والد برای «تمرین فرزند» دیگر کش کهنه فیلتر نمی‌کند؛ واکشی تازهٔ per-student دارد (`fetchSubmissionsFor`).
  - مجوز والد در `academy.ts` با `exams.ts` یکی شد (۴۰۳ صریح به‌جای سقوط بی‌صدا).
- **گواهی‌نامه/اعتبار بین‌المللی**:
  - برچسب استاندارد نصاب («AFG MoE Alignment / ISCED 2011 Level 2») روی گواهی‌نامه و صفحهٔ عمومی تأیید اصالت.
  - آدرس QR روی دامنهٔ برند مکتب منتقل شد: `afghanistangirlsdigitalschool.org/verify/:serial` (نه آدرس فنی Workers.dev) — Route جدید در `wrangler.toml` + Handler مشترک در `index.ts`/`exams.ts`.
  - سریال گواهی‌نامه با یک بخش تصادفی واقعی سخت‌تر شد (قبلاً فقط صنف+زمان، قابل‌حدس بود).
  - **امضای رمزنگاری‌شدهٔ ECDSA P-256** روی دادهٔ گواهی (نه فایل PDF/تصویر — Workers نمی‌تواند PAdES واقعی تولید کند): سرور در لحظهٔ صدور امضا می‌کند (`lib/certSigning.ts`، کلید خصوصی `wrangler secret CERT_SIGNING_PRIVATE_KEY`)، صفحهٔ تأیید دوباره بررسی می‌کند و 🔏 تأیید‌شده / ⚠️ ناهم‌خوان نشان می‌دهد (migration 0039، ستون `signature`).
- ۹ مورد `flutter analyze` (`unnecessary_const`/`prefer_const_constructors`) رفع شد.
- **رفع بحرانی «کاربران وارد نمی‌شوند»** — ریشه: دامنهٔ اشتراکی `*.workers.dev` روی شبکهٔ برخی کاربران (مثلاً افغانستان) فیلتر می‌شد. آدرس پیش‌فرض API در `api_client.dart` به دامنهٔ اختصاصی `api.afghanistangirlsdigitalschool.org` تغییر کرد و Route متناظر در `wrangler.toml` فعال شد. **نیاز به تأیید کاربر پس از Deploy/Build مجدد.**
- **رفع «فقط سه سؤال در مدیریت امتحانات رسمی ساخته می‌شود»** — ریشهٔ واقعی: تولید سؤال با هوش مصنوعی (`POST /admin/exams/:examId/generate-questions`) همیشه `max_tokens=4000` ثابت داشت، در حالی که رابط کاربری تا ۳۰ سؤال از هر نوع (تا ۹۰ سؤال) اجازه می‌داد؛ برای درخواست‌های بزرگ‌تر پاسخ AI وسط راه بریده و `JSON.parse` با شکست کامل (۰ سؤال) مواجه می‌شد. رفع شد با: (۱) سقف توکن متناسب با تعداد درخواستی (`lib/essayGrading.ts`)، (۲) پارس «نرم» که سؤالات کاملِ تولیدشده تا نقطهٔ قطع را نجات می‌دهد به‌جای رد کل دسته (`callAiJsonArrayLenient`)، (۳) پیام روشن در اپ وقتی نتیجه کمتر از درخواستی است. افزودن سؤال به‌صورت دستی (بدون AI) از قبل هم محدودیتی نداشت. **نیاز به Deploy بک‌اند.**
- **رفع «کارخانگی/مشق درس بعدی را قفل می‌کند و برنامه می‌شکند»** — بررسی نشان داد نمرهٔ AI مشق اصلاً در قفل درس بعدی نقشی ندارد (`lib/progress.ts` فقط وضعیت *ارسال‌شدن* مشق را می‌بیند، نه نمره)؛ «شکستن برنامه» واقعاً دو باگ جدا بود: (۱) بعد از ارسال عکس مشق فقط `homeworksProvider` باطل می‌شد، نه Providerهای فهرست درس‌ها/فصل‌ها/خانه/نقشهٔ صنوف — پس اگر آن صفحات هنوز در پشتهٔ ناوبری زنده بودند، وضعیت قفل/باز کهنه نشان می‌دادند؛ رفع شد در `homework_dashboard_screen.dart`. (۲) پنج متد `curriculum_repository_impl.dart` خطای خام `ApiException.toString()` را مستقیم به کاربر نشان می‌دادند (شبیه یک کرش به‌نظر می‌رسید) — با همان الگوی تمیز `homework_repository_impl.dart` هماهنگ شد. علاوه بر این، طبق درخواست، Prompt نمره‌دهی هوش مصنوعی مشق (`backend/src/routes/homework.ts`) به‌صراحت اصلاح شد تا نمرهٔ نسبی/تشویقی بدهد و برای تلاش جدی نمرهٔ خیلی پایین ندهد. **نیاز به Deploy بک‌اند + Build مجدد اپ.**
- **آدیت سریع الگویی (بعد از رفع مشکل کارخانگی)**: چون ریشهٔ «برنامه شکست می‌خورد» یک الگوی خطای خام (`ApiException.toString()`) بود، همان الگو در کل `lib/features/` جست‌وجو شد — **۱۷ فایل دیگر** (`*_repository_impl.dart` در grade_map، profile، attendance، student_dashboard، notifications، collective_memory، curriculum_library، ai_teacher، و هفت ماژول مدیر) همین اشکال را داشتند: خطای هر API (مثلاً ۴۰۳/۴۰۰) به‌جای پیام تمیز، متن فنی خام `ApiException(...)` نشان می‌دادند. همهٔ ۱۷ فایل با همان الگوی `_mapApi`ی که در `homework_repository_impl.dart` درست بود، اصلاح شدند (۳۵ نقطهٔ catch در مجموع) و با یک Grep نهایی روی کل `lib/features` تأیید شد که دیگر هیچ catch بدون شاخهٔ `on ApiException` باقی نمانده. همچنین سقف توکن هوش مصنوعی در بک‌اند (`aiCurriculum.ts`, `curriculumStructuring.ts`, `essayGrading.ts`, `homework.ts`, `lessonHomework.ts`, `seminarReport.ts`, `ai.ts`) بازبینی شد — به‌جز مورد امتحانات رسمی که همین جلسه اصلاح شد، بقیه یا از قبل پارامتری‌اند یا خروجی‌شان ذاتاً کوچک/ثابت است (نیازی به تغییر نبود). **نیاز به Build مجدد اپ (این تغییرات فقط فلاتر است، بک‌اند دست نخورد).**
- **فاز ۱ سخت‌سازی امنیتی (۲۴ جولای، بر اساس گزارش بررسی جامع سیستم)**: قبل از نوشتن کد جدید، وضعیت واقعی هر بند بررسی شد — معلوم شد Rate Limiting (Migration 0035) و محدودسازی CORS از قبل در کد وجود داشتند و کار می‌کردند (گزارش ورودی نسبت به این دو بند قدیمی/نادرست بود). موارد واقعاً باقی‌مانده: (۱) رمزگذاری ستونی AES-256-GCM برای تلفن/تاریخ تولد اضافه شد (`lib/columnCrypto.ts`، Migration 0040، Endpoint یک‌بارهٔ Backfill برای کاربران قدیمی) — کدهای دعوت عمداً رمزنگاری نشدند چون هم برای جست‌وجوی دقیق و هم نمایش به مدیر لازم‌اند. (۲) `backend/SECRETS.md` + `.dev.vars.example` اضافه شد — روشن کرد که هیچ رازِ واقعی در Git نیست؛ مقادیری مثل `CF_ACCOUNT_ID` شناسه‌اند نه اعتبارنامه. (۳) `backend/DNS-SETUP.md` با مقادیر دقیق رکورد `www` (CNAME+Redirect) و DMARC (TXT) — این دو مورد عملیاتی‌اند و باید دستی در Cloudflare اعمال شوند. **نیاز به Deploy بک‌اند + `wrangler secret put COLUMN_ENCRYPTION_KEY` + یک‌بار فراخوانی Backfill.**
- **فاز ۳ پاک‌سازی معماری + شروع پوشش تست (۲۴ جولای)**: طبق انتخاب کاربر («ابتدا کارهای کم‌خطر، سپس تست»):
  - بررسی با Explore Agent نشان داد ادعای سند مشکلات دربارهٔ «۲۰ فایل Mock بدون اتصال واقعی» **نادرست/کهنه** بود — هر ۹ ماژول مدیر (کاربران، صف ایمنی، سمینارها، سلامت سیستم، CMS، گزارش‌ها، مدیریت امتحانات، داشبورد) و ۱۵ ماژول غیرمدیر دیگر همگی به‌درستی از `kUseLiveBackend` پیروی می‌کنند. تنها باگ واقعی پیداشده: `instructor_detail_screen.dart` بدون توجه به `kUseLiveBackend` مستقیماً از `InstructorInviteStore` محلی می‌خواند، پس در حالت Live «کد دعوت استفاده‌شده» همیشه خالی نشان داده می‌شد. رفع شد با اضافه‌کردن `inviteCode`/`inviteBatchLabel` به پاسخ `GET /admin/users` (`JOIN` با `invite_codes`) و اولویت‌دادن به دادهٔ سرور در `InstructorProfile`.
  - فروشگاه‌های پراکندهٔ کد دعوت (`StudentInviteStore`, `InstructorInviteStore`, `GuardianLinkStore` در `lib/core/`) بررسی و مستند شد: در حالت Live عملاً کد مرده‌اند (فقط برای دموی حالت Mock لازم‌اند).
    > **به‌روزرسانی ۲۴ جولای (ادامه):** هر سه فایل کامل حذف شدند (نه فقط مستند). `StudentInviteStore`/`InstructorInviteStore` بی‌جایگزین حذف شدند (Mock دیگر کد دعوت را «اعتبارسنجی» شبیه‌سازی نمی‌کند — فقط خالی‌نبودن را چک می‌کند؛ منبع واحد حقیقتِ واقعی همیشه `/api/auth/register` بوده). `GuardianLinkStore` به `lib/core/mock/guardian_link_mock_store.dart` منتقل و به `GuardianLinkMockStore` تغییر نام یافت (چون منطقش برای دموی Mock هنوز لازم بود)؛ مدل دامنه‌اش (`GuardianInviteCode`) به `profile_repository.dart` منتقل شد تا مسیر واقعی (`ProfileRemoteDataSource`) دیگر به فایل Mock وابسته نباشد. در همین بررسی یک باگ واقعی پیدا شد: `parent_dashboard_screen.dart` بدون توجه به `kUseLiveBackend` مستقیماً از این Store می‌خواند، پس بنر «درخواست پیوند در انتظار تأیید» در حالت Live همیشه خالی بود — رفع شد با Endpoint جدید `GET /parents/me/pending-links` + Provider گیت‌شدهٔ `pendingChildLinksProvider`.
  - **مجموعه تست واحد بک‌اند اضافه شد** (`backend/test/*.test.ts`، اجرا با Node's native `node:test` از طریق `tsx`، بدون وابستگی سنگین به vitest): ۴۴ تست در ۵ فایل — `auth.test.ts` (هش/تأیید رمز PBKDF2، صدور/تأیید JWT، ردِ توکن دست‌کاری‌شده/منقضی)، `inviteCode.test.ts` (نرمال‌سازی کد دعوت شامل ارقام فارسی/عربی)، `progress.test.ts` (میانگین پیشرفت صنف)، `columnCrypto.test.ts` (رمزگذاری/رمزگشایی AES-256-GCM، رفتار Fail-safe بدون کلید یا با داده دست‌کاری‌شده)، `essayGrading.test.ts` (نجات اشیاء کامل JSON از پاسخ بریدهٔ AI — دقیقاً همان منطقی که باگ «فقط سه سؤال» را رفع کرد). همهٔ ۴۴ تست سبز اجرا شدند (`npm test` → `tsx --test test/*.test.ts`، اضافه‌شده به `package.json`). `@cloudflare/workers-types` هم به‌عنوان devDependency واقعی اضافه شد (قبلاً فقط دستی و بیرون از `package.json` نصب شده بود) — `npx tsc --noEmit` اکنون تمیز اجرا می‌شود (فقط همان ۲ خطای قدیمی و نامرتبط در `exams.ts`/`media.ts` باقی‌مانده). **تست‌های فلاتر (Auth Flow/نمره‌دهی امتحان) و تست‌های Integration مسیرهای Worker هنوز نوشته نشده‌اند — خارج از دامنهٔ این گام (کم‌خطر) بودند.**
- **بررسی ماژول‌های «سلامت سیستم» و «گزارش‌ها» (۲۴ جولای)**: طبق گزارشی که این دو ماژول را «فقط Mock» توصیف می‌کرد، بررسی مستقیم کد انجام شد — ادعا **نادرست/کهنه** بود (مشابه دو مورد Rate Limiting/CORS در فاز ۱). هر دو از قبل کامل به بک‌اند واقعی وصل‌اند: `GET /admin/system-health` (`admin.ts:532`) واقعاً D1 را با کوئری زنده و R2 را با `BUCKET.list()` تست می‌کند؛ `GET /admin/reports/summary` (`admin.ts:638`) با ۸ کوئری SQL واقعی (شاگردان فعال، میانگین نمرات، شاگردان در معرض خطر و...) پاسخ می‌سازد. هر دو Provider هم به‌درستی با `kUseLiveBackend` سوییچ می‌کنند. هیچ کدی تغییر نکرد.
- **آدیت کامل سمینارها در همهٔ داشبوردها (۲۴ جولای)**: با Explore Agent، تمام فایل‌های سمینار (شاگرد/والد/استاد/مدیر + بک‌اند `seminars.ts`) نقشه‌برداری و تک‌تک Endpointها با فراخوان‌های Flutter تطبیق داده شد. الگوی «Widget که بدون توجه به `kUseLiveBackend` مستقیم از Mock می‌خواند» تکرار نشده بود؛ مجوز دوربین/میکروفن اتاق سمینار هم هنوز درست برای هر ۴ نقش کار می‌کند. دو مشکل واقعی پیدا و رفع شد:
  - **هیچ راهی برای لغو ثبت‌نام سمینار وجود نداشت.** کاربر (شاگرد/والد) که اشتباهی یا از سر تغییر برنامه ثبت‌نام می‌کرد، تا ابد در فهرست ثبت‌نامی‌ها می‌ماند. Endpoint جدید `DELETE /seminars/:id/register` (قبل از شروع/پایان سمینار مجاز) اضافه شد + معادلش در `SeminarStore` (Mock)، به‌علاوهٔ زنجیرهٔ کامل Repository/UseCase/Provider و یک دکمهٔ «لغو ثبت‌نام» (با دیالوگ تأیید) در `SeminarCard` — که چون بین داشبورد شاگرد و والد مشترک است، این رفع اشکال خودکار در هر دو دیده می‌شود.
  - **پاک‌سازی `stream_playback_url` هنگام پایان سمینار عملاً هرگز اجرا نمی‌شد.** یک رفع اشکال قبلی (`/seminars/:id/end-live`) عمداً این فیلد را در پایان پاک می‌کرد تا کارت سمینار کاربر را به یک پخش مرده هدایت نکند — اما هیچ دکمهٔ «پایان» واقعی در اپ (نه در داشبورد استاد/مدیر، نه در اتاق سمینار) آن Endpoint را صدا نمی‌زد؛ همه از مسیر عمومی‌تر `PATCH /status` استفاده می‌کردند که این پاک‌سازی را نداشت. اکنون همان رفتار مستقیماً داخل `PATCH /status` هم اعمال می‌شود (و معادلش در `SeminarStore.setStatus` برای حالت Mock) تا مستقل از مسیر، نتیجه یکسان باشد.
  - موارد کوچک‌تر که عمداً دست نخورد: `POST /seminars/:id/end-live` و `GET /seminars/live` هنوز در بک‌اند هستند ولی هیچ فراخوان فعلی ندارند (کد مرده روی سرور، بی‌خطر)؛ نشان‌دادن «حاضری» (`attended`) روی فهرست ثبت‌نامی‌ها هیچ‌جا واقعاً نوشته نمی‌شود (Badge مرده، هیچ‌وقت نشان داده نمی‌شود) — قابلیت کامل «حاضری‌گیری واقعی» نیاز به کار جداگانه دارد و در این آدیت پیاده نشد.
- **آدیت حافظهٔ جمعی + صف بازبینی ایمنی در همهٔ داشبوردها (۲۴ جولای)**: با Explore Agent، هر دو ویژگی نقشه‌برداری کامل شدند.
  - **حافظهٔ جمعی**: تمیز — همهٔ نقش‌ها (شاگرد/والد/استاد/مدیر) دقیقاً همان یک صفحه/Provider مشترک را می‌بینند، هیچ الگوی بای‌پس Mock پیدا نشد، الگوی خطای تمیز `on ApiException` هم از قبل رعایت شده بود. تغییری لازم نبود.
  - **صف بازبینی ایمنی**: سیم‌کشی Mock/Live و جریان حل‌کردن (Resolve/Escalate/Dismiss) درست و کامل بودند، اما دو مشکل واقعی پیدا شد:
    - **دو نوع از چهار نوع اعلام‌شدهٔ صف (`chatFlag`, `chatReport`) در حالت Live هرگز واقعاً پر نمی‌شدند.** پیام چتِ فیلترشده با کلمهٔ ممنوعه (`media.ts`) فقط در «نظارت بر چت» دیده می‌شد، نه در `safety_events`؛ گزارش دستی پیام (`POST /messages/:id/report`) هم فقط در جدول جدای `chat_reports` می‌ماند که هیچ صفحهٔ مدیریتی آن را نشان نمی‌دهد — با اینکه دادهٔ Mock دقیقاً همین سناریوها را به‌عنوان نمونهٔ واقعی نشان می‌داد. رفع شد: هر دو مسیر اکنون هنگام فیلترشدن/گزارش پیامِ یک **شاگرد**، یک ردیف در `safety_events` هم ثبت می‌کنند (نام/صنف از رکورد واقعی کاربر، نه از بدنهٔ درخواست).
    - **عدد «پرچم‌های ایمنیِ باز» در داشبورد مدیر با خودِ صفحهٔ صف هم‌خوان نبود.** موارد at-risk (بخش ۹.۴) تا وقتی مدیر برای اولین‌بار روی آن‌ها اقدام نکند، در `safety_events` ذخیره نمی‌شوند؛ پس آمار `pending.safetyFlags` (که فقط ردیف‌های ذخیره‌شده را می‌شمرد) می‌توانست «صفر» نشان دهد در حالی که صف واقعی چند شاگرد at-risk باز داشت. رفع شد با اضافه‌کردن همان منطق سنتزِ at-risk به کوئری شمارش.
  - جزئیات کوچک‌تر که عمداً دست نخورد: حافظهٔ جمعی هیچ دکمهٔ «گزارش پُست» ندارد (فقط ویرایش/حذف توسط نویسنده یا مدیر ارشد) — قابلیتی جدا و بزرگ‌تر، نه یک باگ.
- **آدیت چت + Push Notification در همهٔ داشبوردها (۲۴ جولای)**: با دو Explore Agent، هر دو ویژگی نقشه‌برداری کامل شدند و چند مشکل واقعی رفع شد:
  - **شمار شاگردانِ هر صنف در «نظارت بر چت» مدیر همیشه صفر بود.** `GET /admin/chat/overview` هیچ‌گاه این عدد را محاسبه نمی‌کرد؛ کلاینت (`chat_remote_datasource.dart`) هم آن را دستی `0` می‌گذاشت. رفع شد: کوئری با یک Subquery روی `users` (بر اساس قرارداد `class_id = 'grade-<شماره صنف>'`، دقیقاً همان‌طور که در `GET /classmates` ساخته می‌شود) عدد واقعی را برمی‌گرداند؛ کلاینت هم مقدار واقعی `student_count` را می‌خواند.
  - **Push Notification سیستم‌عامل هیچ Payload قابل‌ناوبری نداشت و لمس آن هیچ‌جا را باز نمی‌کرد.** هر ۹ نقطهٔ فراخوانی `sendPushToUser`/`sendPushToUsers` در بک‌اند (`auth.ts`, `exams.ts`, `seminars.ts`, `advisor.ts`, `parents.ts`, `media.ts` ×۲, `homework.ts`, `lib/lessonHomework.ts`) اکنون همان `kind`/`related_id` را که در ردیف واقعیِ جدول `notifications` ذخیره می‌کنند، به‌عنوان `data: {kind, relatedId}` هم در Payload واقعی FCM می‌فرستند. سمت فلاتر: منطق مسیریابیِ اعلان (قبلاً فقط داخل `NotificationsScreen._routeFor` بود) به تابع مستقل `resolveNotificationRoute` در `core/notifications/notification_route_resolver.dart` منتقل شد؛ `GoRouter` یک `rootNavigatorKey` سراسری گرفت (`app/router/root_navigator_key.dart`)؛ و `PushNotificationsService` اکنون هر سه حالت را می‌شنود — `onMessage` (اپ باز، بنر SnackBar)، `onMessageOpenedApp` (اپ در پس‌زمینه، لمس = ناوبری فوری) و `getInitialMessage` (اپ کاملاً بسته بود و با لمس اعلان باز شد) — و با همان تابع مشترک به مقصد درست هدایت می‌کند.
  - **نسخهٔ وب بدون‌فایده درخواست اجازهٔ Push نشان می‌داد.** فایربیس وب پیکربندی VAPID جدا نیاز دارد که این پروژه ندارد؛ `registerCurrentDevice()` حالا با یک Guard اولیهٔ `kIsWeb` روی وب کاملاً بی‌اثر برمی‌گردد (سایر پلتفرم‌ها بدون تغییر).
  - موارد شناسایی‌شده ولی عمداً خارج از این گام: عدم اطلاع والد از نمرهٔ امتحان فرزند (`NotificationKind.grade` فقط سمت کلاینت تعریف شده، سرور هیچ‌جا برای والد نمی‌سازد)، عدم اطلاع شاگرد از انتشار کتاب تازه (`NotificationKind.book` مشابه)، صدور سرتیفیکیت بدون اعلان، و پارامتر بلااستفادهٔ `viewerId` در `chat_remote_datasource.dart` — هرکدام قابلیت/رفع‌اشکال جدا هستند، نه بخشی از این آدیت.
- جزئیات کامل‌تر و آنچه هنوز پوشش داده نشده: `docs/AUDIT-2026-07-23-quick-pass.md`.

## ۷. آنچه هنوز ساخته نشده (خلاصه — تفصیل در سند مشکلات)

آفلاین/Sync (بخش ۲۲ SPEC)، WebSocket/Push واقعی، پارامتری‌سازی وزن‌های نمره، ادغام کامل آکادمی/امتحانات رسمی، پوشش تست فلاتر و Integration تست‌های Worker، حذف کامل حالت Mock، حاضری‌گیری واقعی سمینار (Badge «attended» فعلاً مرده است).
