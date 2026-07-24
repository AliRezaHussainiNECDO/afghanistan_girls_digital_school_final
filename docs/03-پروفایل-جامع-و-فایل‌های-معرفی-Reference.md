# پروفایل جامع برنامه + فهرست فایل‌های معرفی — مرجع برای نشست‌های بعدی
**تاریخ ایجاد:** ۲۳ جولای ۲۰۲۶ | **هدف این فایل:** جلوگیری از اسکن دوبارهٔ کل کدبیس در نشست‌های آینده. برای شناخت کامل برنامه، ابتدا همین فایل + docs/01 و docs/02 را بخوان؛ فقط در صورت نیاز به جزئیات پیاده‌سازی، سراغ کد بروید.

## این فایل چیست و کجا استفاده شود
در تاریخ ۲۳ جولای ۲۰۲۶، کل برنامه (کدبیس فلاتر + بک‌اند + اسناد داخلی) بررسی شد و ۴ فایل Word تولید شد که در ریشهٔ پروژه ذخیره‌اند:

| فایل | زبان | محتوا |
|---|---|---|
| `AGDS_Review_Report_DA.docx` | دری | گزارش فنی داخلی: معماری، داشبوردها، نقاط قوت، ریسک‌ها، اولویت‌ها |
| `AGDS_Introduction_Dari.docx` | دری | فایل معرفی/نمایشی برنامه — همهٔ داشبوردها و بخش‌ها + نقاط قوت و مدرن‌بودن |
| `AGDS_Introduction_English.docx` | انگلیسی | همان محتوای معرفی، به انگلیسی |
| `AGDS_Introduction_Francais.docx` | فرانسوی | همان محتوای معرفی، به فرانسوی (احتمالاً برای مخاطب ژنو/NECDO) |

اگر کاربر خواست این فایل‌ها **به‌روزرسانی یا اضافه** شوند: اسکریپت‌های تولیدکننده در outputs همان نشست از بین رفته‌اند (پوشهٔ موقت)، پس باید از نو یک اسکریپت Node با کتابخانهٔ `docx` نوشت (helper الگو در پایین همین فایل توضیح داده شده) — نیازی به مرور کامل کد نیست، فقط بخش تغییریافته را از docs/01 یا docs/02 یا مستقیم از کد به‌روز کن.

**به‌روزرسانی ۲۴ جولای ۲۰۲۶:** هر سه فایل معرفی (`AGDS_Introduction_Dari/English/Francais.docx`) با یک اسکریپت تازهٔ Node (همان الگوی زیر) بازتولید شدند تا اصلاحات همان روز را منعکس کنند: امضای رمزنگاری‌شدهٔ ECDSA + برچسب استاندارد ISCED روی گواهی‌نامه، نمره‌دهی سرورمحور برای تمرین (نه فقط امتحان رسمی)، و پایداری دسترسی از طریق دامنهٔ اختصاصی + رفع مجوز دوربین/میکروفن سمینار. `AGDS_Review_Report_DA.docx` (گزارش داخلی، فقط دری) دست‌نخورده ماند — درخواست فقط سه فایل معرفی را شامل می‌شد. اعتبارسنجی با `python3-docx` (باز شدن بدون خطا) + رندر PDF با LibreOffice + بررسی بصری RTL/جدول انجام شد؛ `scripts/office/validate.py` قبلی در این نشست وجود نداشت (احتمالاً هم مثل اسکریپت تولید، Session-Scoped بوده).

## نقشهٔ کامل داشبوردها و صفحات (از lib/features، تأییدشده با فایل‌های screens/)

### دانش‌آموز (Student)
داشبورد اصلی، نقشهٔ صنف (grade_map)، نصاب (curriculum: مضمون→فصل→درس)، معلم هوشمند AI (ai_teacher)، مشاور هوشمند (advisor)، پلان مطالعه (study_plan/weekly_plan_screen)، امتحانات (exams)، حاضری (attendance)، کتابخانه (library + curriculum_library)، سمینار (seminars: seminars_screen، seminar_room_screen، seminar_live_player_screen)، چت (chat)، اعلان‌ها (notifications)، پروفایل (profile)، گواهی‌نامه (certificates: my_certificates_screen، certificate_viewer_screen)، حافظهٔ جمعی (collective_memory)، پیشرفت (progression)، آکادمی (academy).

### والدین (parent_dashboard)
parent_dashboard_screen، parent_homework_screen، parent_seminars_screen + تماس با مدیر، اعلان، پروفایل.

### معلم (instructor)
instructor_home_screen، instructor_broadcast_screen + ثبت‌نام مستقیم `/register/instructor`.

### مدیریت (admin) — ۱۱ زیرماژول کامل
dashboard، user_management (student/instructor/parent list+detail)، cms، exams_management، ai_teacher_management، parent_management، reports، safety_queue، seminars، chat_monitoring (class-by-class + thread)، audit_logs، system_health.

### زبان‌ها (تأییدشده از lib/core/localization/translations/)
چهار فایل کامل: `fa.dart` (۱۶۱۹ خط)، `en.dart` (۱۶۲۱ خط)، `fr.dart` (۱۶۲۸ خط)، `ps.dart` (۱۶۱۸ خط) — یعنی برنامه واقعاً **چهار زبانه** است (دری، انگلیسی، فرانسوی، پشتو)، نه فقط سه زبان که در docs/01 آمده بود. این نکته در فایل‌های معرفی لحاظ شده.

## خلاصهٔ فوق‌فشرده معماری (تفصیل کامل در docs/01)
Flutter (Riverpod+GoRouter+Dio، Clean Architecture per-feature) ← HTTPS ← Cloudflare Worker (Hono/TS) ← D1 (۴۲ جدول) + R2 + Stream + AI (gpt-4o-mini + RAG + Azure TTS/STT). دامنه: afghanistangirlsdigitalschool.org.

## خلاصهٔ فوق‌فشرده ریسک‌های باز (تفصیل کامل در docs/02 و اصلاحیهٔ v2.4)
باز/بحرانی: آفلاین (اولویت ۱)، Rate Limiting، CORS باز، شناسه‌های حساس در Git، بدون رمزگذاری ستونی، رکورد www/DMARC نبود.
انجام‌شده: audit_logs ✅ (۱۸ جولای ۲۰۲۶).
کیفیت کد: ۲۰ Mock DataSource باقی، پوشش تست ~صفر، آکادمی=منبع حقیقت موازی، اسناد README/pubspec کهنه.

## الگوی فنی برای بازتولید/ویرایش فایل‌های Word (در صورت نیاز آینده)
- کتابخانهٔ `docx` (npm) در `/usr/local/lib/node_modules_global/lib/node_modules` نصب است؛ باید `NODE_PATH` را به همان مسیر ست کرد.
- برای متن دری: `bidirectional: true` روی هر Paragraph + `rightToLeft: true` روی هر TextRun + فونت "Tahoma"، و برای جدول‌ها `visuallyRightToLeft: true` در Table (وگرنه ترتیب ستون‌ها در RTL برعکس می‌شود).
- تابع کمکی `bullets()` یک **آرایه** از Paragraph برمی‌گرداند؛ در `children` سند حتماً با `...bullets(...)` اسپرد شود، وگرنه docx.js تگ نامعتبر `<0/>` تولید می‌کند و فایل توسط LibreOffice/Word باز نمی‌شود (این باگ یک‌بار در تولید همین فایل‌ها رخ داد و برطرف شد).
- اعتبارسنجی همیشه قبل از تحویل: `python scripts/office/validate.py file.docx` (باید «All validations PASSED» بدهد) + رندر PDF و بررسی بصری صفحه.
