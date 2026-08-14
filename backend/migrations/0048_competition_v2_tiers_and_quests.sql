-- ═══════════════════════════════════════════════════════════════════════════
-- 0048_competition_v2_tiers_and_quests.sql — بازطراحی «رقابت مکتب» طبق سند
-- طراحی تازهٔ صاحب پروژه: ۵ لیگ نام‌گذاری‌شده با ۵۰ عنوان منحصربه‌فرد + پاداش
-- هر لیگ، میشن‌های روزانه (با قفل زنجیره‌ای)، و زیرساخت «پاداش سرعت» امتحان.
--
-- روی migration 0047 ساخته می‌شود (جدول‌های rank_tiers/missions/student_streaks
-- را حذف نمی‌کند، فقط rank_tiers را بازسازی و جدول‌های تازه اضافه می‌کند).
--
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0048_competition_v2_tiers_and_quests.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- ───────────────── بازسازی ۵۰ مقام: ۵ لیگ + عنوان یکتا + پاداش لیگ ───────────
-- لیگ‌ها: ستاره‌های نوظهور(۱-۱۰) → طلایه‌داران دانش(۱۱-۲۰) → فرزانگان(۲۱-۳۰) →
-- فرمانروایان خرد(۳۱-۴۰) → اسطوره‌های جاویدان(۴۱-۵۰، با مقام ویژهٔ ۵۰: «سیمرغ دانش»).
ALTER TABLE rank_tiers ADD COLUMN reward_label_fa TEXT NOT NULL DEFAULT '';
ALTER TABLE rank_tiers ADD COLUMN league_title_fa TEXT NOT NULL DEFAULT '';

DELETE FROM rank_tiers;

INSERT INTO rank_tiers (rank_no, league_key, title_fa, icon, color_from, color_to, min_points, reward_label_fa, league_title_fa) VALUES
(1, 'emerging_stars', 'جستجوگر', 'eco_rounded', '#8A7D6B', '#564A3C', 0, 'آنلاک شدن آواتارهای پایه', 'ستاره‌های نوظهور'),
(2, 'emerging_stars', 'کاوشگر کنجکاو', 'eco_rounded', '#8A7D6B', '#564A3C', 70, 'آنلاک شدن آواتارهای پایه', 'ستاره‌های نوظهور'),
(3, 'emerging_stars', 'دانش‌پوی نوپا', 'eco_rounded', '#8A7D6B', '#564A3C', 162, 'آنلاک شدن آواتارهای پایه', 'ستاره‌های نوظهور'),
(4, 'emerging_stars', 'پرسشگر کوچک', 'eco_rounded', '#8A7D6B', '#564A3C', 292, 'آنلاک شدن آواتارهای پایه', 'ستاره‌های نوظهور'),
(5, 'emerging_stars', 'آموزندهٔ پرتلاش', 'eco_rounded', '#8A7D6B', '#564A3C', 461, 'آنلاک شدن آواتارهای پایه', 'ستاره‌های نوظهور'),
(6, 'emerging_stars', 'پویای علم', 'eco_rounded', '#8A7D6B', '#564A3C', 669, 'آنلاک شدن آواتارهای پایه', 'ستاره‌های نوظهور'),
(7, 'emerging_stars', 'روشن‌ضمیر', 'eco_rounded', '#8A7D6B', '#564A3C', 918, 'آنلاک شدن آواتارهای پایه', 'ستاره‌های نوظهور'),
(8, 'emerging_stars', 'ستارهٔ درخشان', 'eco_rounded', '#8A7D6B', '#564A3C', 1207, 'آنلاک شدن آواتارهای پایه', 'ستاره‌های نوظهور'),
(9, 'emerging_stars', 'پیشتاز راه', 'eco_rounded', '#8A7D6B', '#564A3C', 1537, 'آنلاک شدن آواتارهای پایه', 'ستاره‌های نوظهور'),
(10, 'emerging_stars', 'فاتح افق', 'eco_rounded', '#8A7D6B', '#564A3C', 1907, 'آنلاک شدن آواتارهای پایه', 'ستاره‌های نوظهور'),
(11, 'pioneers', 'روشنگر', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 2319, 'فریم‌های رنگی دور پروفایل', 'طلایه‌داران دانش'),
(12, 'pioneers', 'طلایه‌دار کوچک', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 2772, 'فریم‌های رنگی دور پروفایل', 'طلایه‌داران دانش'),
(13, 'pioneers', 'نوآور', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 3266, 'فریم‌های رنگی دور پروفایل', 'طلایه‌داران دانش'),
(14, 'pioneers', 'راه‌گشای دانش', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 3802, 'فریم‌های رنگی دور پروفایل', 'طلایه‌داران دانش'),
(15, 'pioneers', 'اندیشمند جوان', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 4380, 'فریم‌های رنگی دور پروفایل', 'طلایه‌داران دانش'),
(16, 'pioneers', 'پژوهندهٔ تازه‌کار', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 4999, 'فریم‌های رنگی دور پروفایل', 'طلایه‌داران دانش'),
(17, 'pioneers', 'خردورز', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 5661, 'فریم‌های رنگی دور پروفایل', 'طلایه‌داران دانش'),
(18, 'pioneers', 'نظریه‌پرداز', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 6364, 'فریم‌های رنگی دور پروفایل', 'طلایه‌داران دانش'),
(19, 'pioneers', 'مبتکر', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 7110, 'فریم‌های رنگی دور پروفایل', 'طلایه‌داران دانش'),
(20, 'pioneers', 'معمار آینده', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 7899, 'فریم‌های رنگی دور پروفایل', 'طلایه‌داران دانش'),
(21, 'scholars', 'پژوهشگر', 'star_rounded', '#FFE49A', '#E8A800', 8730, 'نشان‌های درخشان و افکت صوتی اختصاصی', 'فرزانگان'),
(22, 'scholars', 'دانش‌پژوه', 'star_rounded', '#FFE49A', '#E8A800', 9603, 'نشان‌های درخشان و افکت صوتی اختصاصی', 'فرزانگان'),
(23, 'scholars', 'ژرف‌اندیش', 'star_rounded', '#FFE49A', '#E8A800', 10519, 'نشان‌های درخشان و افکت صوتی اختصاصی', 'فرزانگان'),
(24, 'scholars', 'حکیم جوان', 'star_rounded', '#FFE49A', '#E8A800', 11478, 'نشان‌های درخشان و افکت صوتی اختصاصی', 'فرزانگان'),
(25, 'scholars', 'فرزانهٔ نوخاسته', 'star_rounded', '#FFE49A', '#E8A800', 12480, 'نشان‌های درخشان و افکت صوتی اختصاصی', 'فرزانگان'),
(26, 'scholars', 'استاد مباحثه', 'star_rounded', '#FFE49A', '#E8A800', 13525, 'نشان‌های درخشان و افکت صوتی اختصاصی', 'فرزانگان'),
(27, 'scholars', 'صاحب‌نظر', 'star_rounded', '#FFE49A', '#E8A800', 14613, 'نشان‌های درخشان و افکت صوتی اختصاصی', 'فرزانگان'),
(28, 'scholars', 'دانای راز', 'star_rounded', '#FFE49A', '#E8A800', 15744, 'نشان‌های درخشان و افکت صوتی اختصاصی', 'فرزانگان'),
(29, 'scholars', 'پویندهٔ حقیقت', 'star_rounded', '#FFE49A', '#E8A800', 16919, 'نشان‌های درخشان و افکت صوتی اختصاصی', 'فرزانگان'),
(30, 'scholars', 'کمیاب‌دان', 'star_rounded', '#FFE49A', '#E8A800', 18136, 'نشان‌های درخشان و افکت صوتی اختصاصی', 'فرزانگان'),
(31, 'masters', 'استاد منطق', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 19397, 'قابلیت ارسال چالش مستقیم به دیگران', 'فرمانروایان خرد'),
(32, 'masters', 'چیره‌دست', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 20702, 'قابلیت ارسال چالش مستقیم به دیگران', 'فرمانروایان خرد'),
(33, 'masters', 'راهبر اندیشه', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 22050, 'قابلیت ارسال چالش مستقیم به دیگران', 'فرمانروایان خرد'),
(34, 'masters', 'صاحب‌بصیرت', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 23441, 'قابلیت ارسال چالش مستقیم به دیگران', 'فرمانروایان خرد'),
(35, 'masters', 'فرمانده دانش', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 24876, 'قابلیت ارسال چالش مستقیم به دیگران', 'فرمانروایان خرد'),
(36, 'masters', 'معمار خرد', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 26355, 'قابلیت ارسال چالش مستقیم به دیگران', 'فرمانروایان خرد'),
(37, 'masters', 'پیشوای علم', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 27878, 'قابلیت ارسال چالش مستقیم به دیگران', 'فرمانروایان خرد'),
(38, 'masters', 'دانای بزرگ', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 29445, 'قابلیت ارسال چالش مستقیم به دیگران', 'فرمانروایان خرد'),
(39, 'masters', 'حکمران دانایی', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 31055, 'قابلیت ارسال چالش مستقیم به دیگران', 'فرمانروایان خرد'),
(40, 'masters', 'فرمانروای اندیشه', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 32709, 'قابلیت ارسال چالش مستقیم به دیگران', 'فرمانروایان خرد'),
(41, 'legends', 'اسطوره', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 34408, 'ورود به تالار افتخارات مکتب', 'اسطوره‌های جاویدان'),
(42, 'legends', 'نماد دانایی', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 36150, 'ورود به تالار افتخارات مکتب', 'اسطوره‌های جاویدان'),
(43, 'legends', 'ستون خرد', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 37937, 'ورود به تالار افتخارات مکتب', 'اسطوره‌های جاویدان'),
(44, 'legends', 'چراغ راه', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 39767, 'ورود به تالار افتخارات مکتب', 'اسطوره‌های جاویدان'),
(45, 'legends', 'پیشگام جاویدان', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 41642, 'ورود به تالار افتخارات مکتب', 'اسطوره‌های جاویدان'),
(46, 'legends', 'قهرمان بی‌بدیل', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 43561, 'ورود به تالار افتخارات مکتب', 'اسطوره‌های جاویدان'),
(47, 'legends', 'نگین مکتب', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 45525, 'ورود به تالار افتخارات مکتب', 'اسطوره‌های جاویدان'),
(48, 'legends', 'افسانهٔ زمان', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 47533, 'ورود به تالار افتخارات مکتب', 'اسطوره‌های جاویدان'),
(49, 'legends', 'جهان‌دان', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 49585, 'ورود به تالار افتخارات مکتب', 'اسطوره‌های جاویدان'),
(50, 'legends', 'سیمرغ دانش', 'auto_awesome_rounded', '#FFD86B', '#8A3DFF', 51682, 'مقام سیمرغ دانش — واجد‌شرایط نبرد زنده برای مقام اول (به‌زودی)', 'اسطوره‌های جاویدان');

-- ─────────────────────────── میشن‌های روزانه (Daily Quests) ──────────────────
-- جدا از جدول `missions` (که دستاوردهای دائمی/یک‌بارهٔ فاز اول هستند)، این
-- لایهٔ تازه هر روز صفر می‌شود — طبق طراحی «ماموریت‌های روزانه» صاحب پروژه.
-- قفل زنجیره‌ای با `requires_template_id`: میشن دوم فقط بعد از دریافت پاداش
-- میشن اول (در همان روز) در دسترس قرار می‌گیرد.
CREATE TABLE IF NOT EXISTS daily_quest_templates (
  id                   TEXT PRIMARY KEY,
  title_fa             TEXT NOT NULL,
  description_fa       TEXT NOT NULL,
  icon                 TEXT NOT NULL,
  reason_key           TEXT NOT NULL,   -- student_points_ledger.reason مرتبط
  target_count         INTEGER NOT NULL,
  points_reward        INTEGER NOT NULL,
  requires_template_id TEXT,            -- قفل زنجیره‌ای (NULL = بدون پیش‌نیاز)
  sort_order           INTEGER NOT NULL DEFAULT 0,
  active               INTEGER NOT NULL DEFAULT 1
);

INSERT OR IGNORE INTO daily_quest_templates (id, title_fa, description_fa, icon, reason_key, target_count, points_reward, requires_template_id, sort_order) VALUES
('dq_watch_2_lessons', 'تماشای ۲ درس', 'امروز ۲ درس ببینید.', 'play_circle_rounded', 'lesson_view', 2, 40, NULL, 1),
('dq_read_1_article', 'مطالعهٔ ۱ مقاله', 'یک مقاله یا خلاصهٔ کتاب در کتابخانه بخوانید.', 'auto_stories_rounded', 'library_read', 1, 30, NULL, 2),
('dq_take_related_quiz', 'آزمون فصل مرتبط', 'بعد از مطالعه، در یک آزمون فصل شرکت کنید.', 'quiz_rounded', 'chapter_quiz_pass', 1, 60, 'dq_read_1_article', 3),
('dq_homework_1', 'ارسال کارخانگی', 'یک کارخانگی امروز ارسال کنید.', 'assignment_turned_in_rounded', 'homework_graded', 1, 35, NULL, 4),
('dq_memory_1', 'روایت روزانه', 'یک روایت در حافظهٔ جمعی به‌اشتراک بگذارید.', 'groups_rounded', 'memory_post', 1, 20, NULL, 5);

-- پیشرفت هر شاگرد در هر میشنِ هر روز — با UNIQUE(student,template,date) هر روز
-- ردیف تازه ساخته می‌شود (idempotent با INSERT OR IGNORE سمت Backend).
CREATE TABLE IF NOT EXISTS student_daily_quests (
  id           TEXT PRIMARY KEY,
  student_id   TEXT NOT NULL,
  template_id  TEXT NOT NULL,
  quest_date   TEXT NOT NULL,   -- 'YYYY-MM-DD'
  claimed      INTEGER NOT NULL DEFAULT 0,
  claimed_at   TEXT,
  UNIQUE(student_id, template_id, quest_date)
);
CREATE INDEX IF NOT EXISTS idx_daily_quests_student_date ON student_daily_quests(student_id, quest_date);

-- ─────────────────── زیرساخت «پاداش سرعت» امتحان (Speed Bonus) ───────────────
-- زمان شروع واقعیِ هر امتحان (اولین باری که شاگرد سؤالات را می‌خواند) اینجا
-- ثبت می‌شود؛ در لحظهٔ ارسال، اختلاف زمان محاسبه و در صورت سرعت بالا (و نمرهٔ
-- کامل) پاداش اضافه اهدا می‌شود. جدولی جدا (نه ستون در exam_attempts) چون قبل
-- از وجود یک تلاش، باید زمان شروع را جایی نگه داشت.
CREATE TABLE IF NOT EXISTS exam_start_times (
  exam_id     TEXT NOT NULL,
  user_id     TEXT NOT NULL,
  started_at  TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (exam_id, user_id)
);
