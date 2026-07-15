-- ═══════════════════════════════════════════════════════════════════════════
-- 0018_gamification.sql — امتیازدهی بر اساس فعالیت شاگرد (دفتر کل امتیازات).
-- هر فعالیت مثبت (دیدن درس، تکمیل فصل، عبور از امتحان، ...) یک ردیف اینجا
-- درج می‌کند؛ مجموع امتیازات هر شاگرد = SUM(points) از این جدول.
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0018_gamification.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS student_points_ledger (
  id          TEXT PRIMARY KEY,
  student_id  TEXT NOT NULL,
  points      INTEGER NOT NULL,
  reason      TEXT NOT NULL,          -- lesson_view|chapter_complete|exam_pass|streak_bonus|...
  ref_id      TEXT NOT NULL DEFAULT '', -- شناسهٔ درس/فصل/امتحان مرتبط (برای جلوگیری از تکرار و برای نمایش جزئیات)
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_points_student ON student_points_ledger(student_id);
CREATE INDEX IF NOT EXISTS idx_points_student_created ON student_points_ledger(student_id, created_at);

-- سطح‌بندی بر اساس مجموع امتیاز (برای نشان‌دادن نشان/رتبه در داشبورد شاگرد).
-- منطق سطح در کد Backend محاسبه می‌شود (مثلاً هر ۱۰۰ امتیاز = یک سطح)، این
-- جدول فقط برای مرجع نگه‌داشته شده تا در آینده قابل تنظیم باشد بدون تغییر کد.
CREATE TABLE IF NOT EXISTS points_levels (
  level       INTEGER PRIMARY KEY,
  min_points  INTEGER NOT NULL,
  title_fa    TEXT NOT NULL
);
INSERT OR IGNORE INTO points_levels (level, min_points, title_fa) VALUES
  (1, 0,    'نوآموز'),
  (2, 100,  'کوشا'),
  (3, 250,  'ستارهٔ درس'),
  (4, 500,  'قهرمان دانش'),
  (5, 1000, 'نابغهٔ مکتب');
