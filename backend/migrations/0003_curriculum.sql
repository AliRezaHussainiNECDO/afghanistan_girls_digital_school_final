-- ═══════════════════════════════════════════════════════════════════════════
-- 0003_curriculum.sql — نصاب: صنف/مضمون/فصل/درس + بازدید درس (بخش ۶.۱/۱۷.۲)
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0003_curriculum.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS grades (
  number   INTEGER PRIMARY KEY,          -- 7..12
  name_fa  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS subjects (
  id          TEXT PRIMARY KEY,          -- کلید یکسان با اپ فلاتر: math, physics, ...
  name_fa     TEXT NOT NULL,
  name_en     TEXT NOT NULL DEFAULT '',
  order_index INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS chapters (
  id           TEXT PRIMARY KEY,
  grade_number INTEGER NOT NULL,
  subject_id   TEXT NOT NULL,
  title_fa     TEXT NOT NULL,
  order_index  INTEGER NOT NULL DEFAULT 0,
  status       TEXT NOT NULL DEFAULT 'published',   -- draft|published
  FOREIGN KEY (grade_number) REFERENCES grades(number),
  FOREIGN KEY (subject_id)   REFERENCES subjects(id)
);
CREATE INDEX IF NOT EXISTS idx_chapters_gs ON chapters(grade_number, subject_id);

CREATE TABLE IF NOT EXISTS lessons (
  id                TEXT PRIMARY KEY,
  chapter_id        TEXT NOT NULL,
  title_fa          TEXT NOT NULL,
  estimated_minutes INTEGER NOT NULL DEFAULT 15,
  order_index       INTEGER NOT NULL DEFAULT 0,
  content_body      TEXT NOT NULL DEFAULT '',
  status            TEXT NOT NULL DEFAULT 'published',
  FOREIGN KEY (chapter_id) REFERENCES chapters(id)
);
CREATE INDEX IF NOT EXISTS idx_lessons_chapter ON lessons(chapter_id);

-- بازدید درس توسط دانش‌آموز (ورودی منطق C1 بخش ۶.۲؛ منبع حقیقت Backend).
CREATE TABLE IF NOT EXISTS student_lesson_views (
  user_id    TEXT NOT NULL,
  lesson_id  TEXT NOT NULL,
  viewed_at  TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, lesson_id)
);
CREATE INDEX IF NOT EXISTS idx_views_user ON student_lesson_views(user_id);

-- ─────────────────────────── داده‌های اولیه (Seed) ───────────────────────────
INSERT OR IGNORE INTO grades (number, name_fa) VALUES
  (7,'صنف هفتم'),(8,'صنف هشتم'),(9,'صنف نهم'),
  (10,'صنف دهم'),(11,'صنف یازدهم'),(12,'صنف دوازدهم');

INSERT OR IGNORE INTO subjects (id, name_fa, name_en, order_index) VALUES
  ('math','ریاضی','Mathematics',1),
  ('physics','فزیک','Physics',2),
  ('chemistry','کیمیا','Chemistry',3),
  ('biology','بیولوژی','Biology',4),
  ('english','انگلیسی','English',5),
  ('dari_lit','ادبیات دری','Dari Literature',6),
  ('history','تاریخ','History',7),
  ('geography','جغرافیه','Geography',8),
  ('islamic','تعلیمات اسلامی','Islamic Studies',9),
  ('computer','کمپیوتر ساینس','Computer Science',10);

-- محتوای نمونهٔ صنف ۷ برای ریاضی و فزیک (تا مرور واقعی از سرور ممکن شود).
INSERT OR IGNORE INTO chapters (id, grade_number, subject_id, title_fa, order_index) VALUES
  ('ch-g7-math-1',7,'math','فصل ۱: اعداد صحیح',1),
  ('ch-g7-math-2',7,'math','فصل ۲: کسرها',2),
  ('ch-g7-math-3',7,'math','فصل ۳: هندسهٔ مقدماتی',3),
  ('ch-g7-physics-1',7,'physics','فصل ۱: اندازه‌گیری',1),
  ('ch-g7-physics-2',7,'physics','فصل ۲: حرکت',2);

INSERT OR IGNORE INTO lessons (id, chapter_id, title_fa, estimated_minutes, order_index, content_body) VALUES
  ('ls-g7-math-1-1','ch-g7-math-1','درس ۱: معرفی اعداد صحیح',15,1,'اعداد صحیح شامل اعداد مثبت، منفی و صفر هستند...'),
  ('ls-g7-math-1-2','ch-g7-math-1','درس ۲: جمع و تفریق',20,2,'برای جمع اعداد صحیح با علامت‌های مختلف...'),
  ('ls-g7-math-1-3','ch-g7-math-1','درس ۳: ضرب و تقسیم',20,3,'قواعد علامت در ضرب و تقسیم...'),
  ('ls-g7-math-2-1','ch-g7-math-2','درس ۱: مفهوم کسر',15,1,'کسر بخشی از یک کل را نشان می‌دهد...'),
  ('ls-g7-math-2-2','ch-g7-math-2','درس ۲: جمع کسرها',20,2,'برای جمع کسرها ابتدا مخرج مشترک...'),
  ('ls-g7-math-3-1','ch-g7-math-3','درس ۱: نقطه، خط و زاویه',18,1,'مفاهیم پایهٔ هندسه...'),
  ('ls-g7-physics-1-1','ch-g7-physics-1','درس ۱: کمیت‌های فیزیکی',15,1,'کمیت‌های اصلی و فرعی...'),
  ('ls-g7-physics-1-2','ch-g7-physics-1','درس ۲: یکاها',18,2,'سیستم بین‌المللی یکاها (SI)...'),
  ('ls-g7-physics-2-1','ch-g7-physics-2','درس ۱: سرعت و شتاب',20,1,'تعریف سرعت متوسط و لحظه‌ای...');
