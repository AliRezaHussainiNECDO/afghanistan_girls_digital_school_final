-- ═══════════════════════════════════════════════════════════════════════════
-- 0047_competition_system.sql — «رقابت مکتب» (نسخهٔ ۲): ۵۰ مقام، میشن‌ها،
-- جدول رتبه‌بندی سراسری و روزشمار فعالیت پیوسته (Streak).
--
-- روی زیرساخت امتیازدهی موجود (migration 0018 — student_points_ledger) ساخته
-- می‌شود؛ هیچ ستون/رفتار قبلی تغییر نمی‌کند، فقط لایهٔ رقابت روی همان دفتر کل
-- امتیازات اضافه می‌شود. طراحی عمداً «داده‌محور» است (نه هاردکد در کد) — دقیقاً
-- هم‌الگو با نظر مهاجرت ۰۰۱۸ («این جدول فقط برای مرجع نگه‌داشته شده تا در
-- آینده قابل تنظیم باشد بدون تغییر کد») — یعنی مدیر/توسعه‌دهنده می‌تواند بعداً
-- نام/آستانهٔ مقام‌ها و پاداش میشن‌ها را فقط با UPDATE این جدول‌ها تغییر دهد.
--
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0047_competition_system.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────── ۵۰ مقام (Rank Tiers) ────────────────────────────────
-- ۵ «لیگ» × ۱۰ زیرمقام = ۵۰ مقام؛ آستانهٔ هر مقام بر پایهٔ مجموع امتیاز کل
-- (student_points_ledger) است. لیگ‌ها عیناً با عناوین سطح‌بندی قدیمی
-- (points_levels — migration 0018) هم‌نام‌اند تا حس ادامه/رشد حفظ شود، فقط
-- حالا هر لیگ به ۱۰ درجهٔ ریزتر تقسیم شده تا رقابت روزانه محسوس‌تر باشد.
CREATE TABLE IF NOT EXISTS rank_tiers (
  rank_no       INTEGER PRIMARY KEY,     -- ۱..۵۰ (۱=پایین‌ترین، ۵۰=بالاترین)
  league_key    TEXT NOT NULL,           -- novice|diligent|star|hero|genius
  title_fa      TEXT NOT NULL,
  icon          TEXT NOT NULL,           -- نام آیکون متریال (سمت کلاینت نگاشت می‌شود)
  color_from    TEXT NOT NULL,           -- گرادیان نشان مقام (Hex)
  color_to      TEXT NOT NULL,
  min_points    INTEGER NOT NULL
);

INSERT OR IGNORE INTO rank_tiers (rank_no, league_key, title_fa, icon, color_from, color_to, min_points) VALUES
(1, 'novice', 'نوآموز 1', 'eco_rounded', '#8A7D6B', '#564A3C', 0),
(2, 'novice', 'نوآموز 2', 'eco_rounded', '#8A7D6B', '#564A3C', 17),
(3, 'novice', 'نوآموز 3', 'eco_rounded', '#8A7D6B', '#564A3C', 40),
(4, 'novice', 'نوآموز 4', 'eco_rounded', '#8A7D6B', '#564A3C', 72),
(5, 'novice', 'نوآموز 5', 'eco_rounded', '#8A7D6B', '#564A3C', 114),
(6, 'novice', 'نوآموز 6', 'eco_rounded', '#8A7D6B', '#564A3C', 165),
(7, 'novice', 'نوآموز 7', 'eco_rounded', '#8A7D6B', '#564A3C', 227),
(8, 'novice', 'نوآموز 8', 'eco_rounded', '#8A7D6B', '#564A3C', 298),
(9, 'novice', 'نوآموز 9', 'eco_rounded', '#8A7D6B', '#564A3C', 380),
(10, 'novice', 'نوآموز 10', 'eco_rounded', '#8A7D6B', '#564A3C', 471),
(11, 'diligent', 'کوشا 1', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 573),
(12, 'diligent', 'کوشا 2', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 685),
(13, 'diligent', 'کوشا 3', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 807),
(14, 'diligent', 'کوشا 4', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 939),
(15, 'diligent', 'کوشا 5', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 1082),
(16, 'diligent', 'کوشا 6', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 1235),
(17, 'diligent', 'کوشا 7', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 1399),
(18, 'diligent', 'کوشا 8', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 1572),
(19, 'diligent', 'کوشا 9', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 1757),
(20, 'diligent', 'کوشا 10', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 1951),
(21, 'star', 'ستارهٔ درس 1', 'star_rounded', '#FFE49A', '#E8A800', 2157),
(22, 'star', 'ستارهٔ درس 2', 'star_rounded', '#FFE49A', '#E8A800', 2373),
(23, 'star', 'ستارهٔ درس 3', 'star_rounded', '#FFE49A', '#E8A800', 2599),
(24, 'star', 'ستارهٔ درس 4', 'star_rounded', '#FFE49A', '#E8A800', 2836),
(25, 'star', 'ستارهٔ درس 5', 'star_rounded', '#FFE49A', '#E8A800', 3083),
(26, 'star', 'ستارهٔ درس 6', 'star_rounded', '#FFE49A', '#E8A800', 3342),
(27, 'star', 'ستارهٔ درس 7', 'star_rounded', '#FFE49A', '#E8A800', 3610),
(28, 'star', 'ستارهٔ درس 8', 'star_rounded', '#FFE49A', '#E8A800', 3890),
(29, 'star', 'ستارهٔ درس 9', 'star_rounded', '#FFE49A', '#E8A800', 4180),
(30, 'star', 'ستارهٔ درس 10', 'star_rounded', '#FFE49A', '#E8A800', 4481),
(31, 'hero', 'قهرمان دانش 1', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 4792),
(32, 'hero', 'قهرمان دانش 2', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 5115),
(33, 'hero', 'قهرمان دانش 3', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 5448),
(34, 'hero', 'قهرمان دانش 4', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 5791),
(35, 'hero', 'قهرمان دانش 5', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 6146),
(36, 'hero', 'قهرمان دانش 6', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 6511),
(37, 'hero', 'قهرمان دانش 7', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 6888),
(38, 'hero', 'قهرمان دانش 8', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 7275),
(39, 'hero', 'قهرمان دانش 9', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 7672),
(40, 'hero', 'قهرمان دانش 10', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 8081),
(41, 'genius', 'نابغهٔ مکتب 1', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 8501),
(42, 'genius', 'نابغهٔ مکتب 2', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 8931),
(43, 'genius', 'نابغهٔ مکتب 3', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 9373),
(44, 'genius', 'نابغهٔ مکتب 4', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 9825),
(45, 'genius', 'نابغهٔ مکتب 5', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 10288),
(46, 'genius', 'نابغهٔ مکتب 6', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 10762),
(47, 'genius', 'نابغهٔ مکتب 7', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 11247),
(48, 'genius', 'نابغهٔ مکتب 8', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 11743),
(49, 'genius', 'نابغهٔ مکتب 9', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 12250),
(50, 'genius', 'افسانهٔ مکتب', 'auto_awesome_rounded', '#FFD86B', '#8A3DFF', 12768);

-- ────────────────────────── میشن‌ها (Missions) ───────────────────────────────
-- هر میشن به یک `reason` موجود/تازه در student_points_ledger وصل است — پیشرفت
-- میشن یعنی COUNT(*) از ردیف‌های آن reason برای شاگرد. با ارسال میشن (وقتی
-- progress >= target_count)، شاگرد آن را «دریافت» می‌کند (student_mission_claims)
-- و یک پاداش امتیازی اضافه (reason='mission_reward') می‌گیرد — یعنی هر بخش
-- برنامه (درس، کارخانگی، امتحان، حافظهٔ جمعی، چت، پروفایل، معلم هوشمند،
-- سمینار، کد دعوت، گواهی‌نامه) مستقیماً روی رقابت اثر می‌گذارد.
CREATE TABLE IF NOT EXISTS missions (
  id            TEXT PRIMARY KEY,
  category      TEXT NOT NULL,     -- برای گروه‌بندی نمایش در فهرست میشن‌ها
  title_fa      TEXT NOT NULL,
  description_fa TEXT NOT NULL,
  icon          TEXT NOT NULL,
  reason_key    TEXT NOT NULL,     -- student_points_ledger.reason مرتبط
  target_count  INTEGER NOT NULL,
  points_reward INTEGER NOT NULL,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  active        INTEGER NOT NULL DEFAULT 1
);

INSERT OR IGNORE INTO missions (id, category, title_fa, description_fa, icon, reason_key, target_count, points_reward, sort_order) VALUES
('m_first_lesson',    'curriculum', 'اولین قدم',            'اولین درس خود را ببینید.',                       'play_circle_rounded',        'lesson_view',              1,  10, 1),
('m_lessons_10',      'curriculum', 'شاگرد کوشا',           '۱۰ درس ببینید.',                                  'menu_book_rounded',          'lesson_view',              10, 40, 2),
('m_lessons_40',      'curriculum', 'کاوشگر دانش',          '۴۰ درس ببینید.',                                  'auto_stories_rounded',       'lesson_view',              40, 120, 3),
('m_chapter_1',       'curriculum', 'اولین فصل',            'یک فصل را کامل تکمیل کنید.',                      'flag_circle_rounded',        'chapter_complete',        1,  25, 4),
('m_chapter_5',       'curriculum', 'فصل‌گشا',              '۵ فصل را کامل تکمیل کنید.',                       'military_tech_rounded',      'chapter_complete',        5,  90, 5),
('m_homework_5',      'homework',   'کارخانگی‌کار',          '۵ کارخانگی خود را ارسال کنید.',                   'assignment_turned_in_rounded','homework_graded',         5,  60, 6),
('m_homework_20',     'homework',   'پرتلاش',               '۲۰ کارخانگی خود را ارسال کنید.',                  'edit_note_rounded',          'homework_graded',         20, 150, 7),
('m_chapter_quiz_3',  'exams',      'آزمون‌گیر',             'در ۳ آزمون فصل کامیاب شوید.',                     'quiz_rounded',               'chapter_quiz_pass',       3,  70, 8),
('m_exam_1',          'exams',      'اولین کامیابی',        'در یک امتحان کامیاب شوید.',                       'fact_check_rounded',         'exam_pass',                1,  40, 9),
('m_final_exam',      'exams',      'قهرمان امتحان نهایی',  'در امتحان نهایی صنف کامیاب شوید.',                'emoji_events_rounded',       'final_exam_pass',         1,  150, 10),
('m_memory_1',        'community',  'اولین روایت',          'اولین روایت خود را در حافظهٔ جمعی بنویسید.',       'auto_stories_rounded',       'memory_post',              1,  15, 11),
('m_memory_10',       'community',  'راوی فعال',            '۱۰ روایت در حافظهٔ جمعی به‌اشتراک بگذارید.',      'groups_rounded',             'memory_post',              10, 60, 12),
('m_avatar',          'profile',    'آراستن پروفایل',       'یک عکس پروفایل برای خود انتخاب کنید.',            'account_circle_rounded',     'avatar_set',               1,  15, 13),
('m_chat_10',         'community',  'هم‌صحبت',              '۱۰ پیام در چت بفرستید.',                          'chat_bubble_rounded',        'chat_message',             10, 30, 14),
('m_ai_teacher_5',    'ai',         'شاگرد هوشمند',         '۵ پاسخ درست با معلم هوشمند بدهید.',               'smart_toy_rounded',          'ai_teacher_correct_answer',5,  40, 15),
('m_seminar_3',       'seminars',   'اهل مجلس',             'در ۳ سمینار ثبت‌نام کنید.',                       'groups_2_rounded',           'seminar_registered',       3,  45, 16),
('m_invite_welcome',  'onboarding', 'خوش‌آمدید!',            'با کد دعوت وارد مکتب دیجیتال شوید.',              'card_giftcard_rounded',      'invite_code_registered',  1,  10, 17),
('m_certificate_1',   'achievement','اولین گواهی‌نامه',      'اولین گواهی‌نامهٔ خود را دریافت کنید.',           'workspace_premium_rounded',  'certificate_earned',       1,  30, 18),
('m_streak_7',        'streak',     'هفتهٔ پیوسته',          '۷ روز پیاپی در برنامه فعال باشید.',               'local_fire_department_rounded','streak_bonus',           1,  70, 19),
('m_streak_30',       'streak',     'ماه بی‌وقفه',           '۳۰ روز پیاپی در برنامه فعال باشید.',              'whatshot_rounded',           'streak_bonus',             2,  200, 20);

-- ─────────────────────── ثبت دریافت پاداش میشن‌ها ─────────────────────────────
CREATE TABLE IF NOT EXISTS student_mission_claims (
  id          TEXT PRIMARY KEY,
  student_id  TEXT NOT NULL,
  mission_id  TEXT NOT NULL,
  claimed_at  TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(student_id, mission_id)
);
CREATE INDEX IF NOT EXISTS idx_mission_claims_student ON student_mission_claims(student_id);

-- ─────────────────── روزشمار فعالیت پیوسته (Daily Streak) ────────────────────
-- هر بار که شاگرد امتیاز می‌گیرد (هر بخش برنامه)، این جدول یک‌بار در روز
-- به‌روزرسانی می‌شود (lib/progress.ts::touchDailyStreak). رسیدن به یک نقطهٔ
-- عطف (۳/۷/۱۴/۳۰/۶۰/۱۰۰ روز) خودش یک ردیف پاداش در دفتر امتیازات می‌سازد
-- (reason='streak_bonus') — دقیقاً همان reason که از ابتدا در نظر گرفته شده
-- بود (نگاه کن به کامنت migration 0018) ولی تا امروز هرگز پیاده‌سازی نشده بود.
CREATE TABLE IF NOT EXISTS student_streaks (
  student_id        TEXT PRIMARY KEY,
  current_streak    INTEGER NOT NULL DEFAULT 0,
  longest_streak    INTEGER NOT NULL DEFAULT 0,
  last_active_date  TEXT,                      -- 'YYYY-MM-DD'
  milestones_awarded TEXT NOT NULL DEFAULT '[]' -- JSON آرایهٔ نقاط عطف دریافت‌شده
);
