-- ═══════════════════════════════════════════════════════════════════════════
-- 0049_live_arena.sql — «آرنای زنده»: مسابقهٔ زندهٔ هفتگی برای مقام اول، طبق
-- وعدهٔ docs/Release-Notes-v2.0-EN.md («⚔️ The Live Arena & Rank #1 Battles»)
-- و متن پاداش خودِ مقام ۵۰ در migration 0048 («واجد‌شرایط نبرد زنده... به‌زودی»).
--
-- طراحی: بانک سؤال مستقل از رویداد (قابل استفادهٔ مجدد در چند رویداد هفتگی)
-- + جدول رویدادها (هر هفته یک ردیف) + جدول اتصال «کدام سؤال‌ها با چه ترتیبی
-- در کدام رویداد» + شرکت‌کنندگان و امتیازشان + لاگ پاسخ (ضدتقلب: هر شاگرد
-- فقط یک‌بار می‌تواند به هر سؤال در هر رویداد پاسخ دهد).
--
-- منطق زمان‌بندی/امتیازدهی واقعی در Durable Object است (lib/liveArenaRoom.ts)؛
-- این مهاجرت فقط ساختار داده + یک بانک سؤال شروع‌کننده + یک رویداد نمونه را
-- می‌سازد. مدیر می‌تواند رویدادهای بعدی را با POST /admin/live-arena/schedule
-- بسازد.
--
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0049_live_arena.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS arena_question_bank (
  id            TEXT PRIMARY KEY,
  prompt_fa     TEXT NOT NULL,
  prompt_en     TEXT NOT NULL,
  prompt_ps     TEXT NOT NULL,
  prompt_fr     TEXT NOT NULL,
  options_fa    TEXT NOT NULL,  -- JSON array، ۴ گزینه
  options_en    TEXT NOT NULL,
  options_ps    TEXT NOT NULL,
  options_fr    TEXT NOT NULL,
  correct_index INTEGER NOT NULL,  -- 0..3
  points        INTEGER NOT NULL DEFAULT 100,
  active        INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS arena_events (
  id                  TEXT PRIMARY KEY,
  title_fa            TEXT NOT NULL DEFAULT 'آرنای زنده هفتگی',
  starts_at           TEXT NOT NULL,   -- ISO — DO/کرون این را با now مقایسه می‌کند
  ends_at             TEXT NOT NULL,
  status              TEXT NOT NULL DEFAULT 'scheduled',  -- scheduled|live|ended
  min_rank_no         INTEGER NOT NULL DEFAULT 21,         -- آستانهٔ واجد‌شرایطی (لیگ فرزانگان به بالا)
  question_count      INTEGER NOT NULL DEFAULT 10,
  time_limit_seconds  INTEGER NOT NULL DEFAULT 15,
  champion_student_id TEXT,
  champion_points     INTEGER,
  created_at          TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_arena_events_status ON arena_events(status, starts_at);

-- اتصال سؤال↔رویداد با ترتیب مشخص (وقتی رویداد ساخته می‌شود، N سؤال تصادفی
-- از بانک اینجا کپی می‌شود تا حتی اگر بعداً بانک تغییر کند، رویدادهای
-- گذشته/جاری دست‌نخورده بمانند).
CREATE TABLE IF NOT EXISTS arena_event_questions (
  event_id    TEXT NOT NULL,
  seq         INTEGER NOT NULL,  -- 0-based ترتیب نمایش در همان رویداد
  question_id TEXT NOT NULL,
  PRIMARY KEY (event_id, seq)
);

CREATE TABLE IF NOT EXISTS arena_participants (
  event_id        TEXT NOT NULL,
  student_id      TEXT NOT NULL,
  joined_at       TEXT NOT NULL DEFAULT (datetime('now')),
  score           INTEGER NOT NULL DEFAULT 0,
  correct_count   INTEGER NOT NULL DEFAULT 0,
  last_answer_at  TEXT,
  PRIMARY KEY (event_id, student_id)
);
CREATE INDEX IF NOT EXISTS idx_arena_participants_event_score ON arena_participants(event_id, score DESC);

-- لاگ پاسخ‌ها — هم برای محاسبهٔ امتیاز (سرعت + درستی) و هم ضدتقلب
-- (UNIQUE یعنی پاسخ دوم به همان سؤال در همان رویداد رد می‌شود).
CREATE TABLE IF NOT EXISTS arena_answer_log (
  id            TEXT PRIMARY KEY,
  event_id      TEXT NOT NULL,
  student_id    TEXT NOT NULL,
  question_id   TEXT NOT NULL,
  choice_index  INTEGER NOT NULL,
  correct       INTEGER NOT NULL,
  ms_taken      INTEGER NOT NULL,
  answered_at   TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(event_id, student_id, question_id)
);

-- ─────────────────────── بانک سؤال شروع‌کننده (۱۵ سؤال) ──────────────────────
-- سؤالات عمومی/فرهنگی مناسب همهٔ صنف‌ها؛ تیم نصاب می‌تواند بعداً بیشتر اضافه
-- کند (مستقیم در دیتابیس یا از طریق endpoint مدیریتی آینده).
INSERT OR IGNORE INTO arena_question_bank (id, prompt_fa, prompt_en, prompt_ps, prompt_fr, options_fa, options_en, options_ps, options_fr, correct_index, points) VALUES
('aq_01', 'پایتخت افغانستان کدام شهر است؟', 'What is the capital of Afghanistan?', 'د افغانستان پلازمېنه کومه ښار دی؟', 'Quelle est la capitale de l''Afghanistan ?', '["کابل","هرات","مزار شریف","قندهار"]', '["Kabul","Herat","Mazar-i-Sharif","Kandahar"]', '["کابل","هرات","مزار شریف","کندهار"]', '["Kaboul","Herat","Mazar-i-Charif","Kandahar"]', 0, 100),
('aq_02', 'نتیجهٔ ۷ × ۸ چند است؟', 'What is 7 × 8?', 'د ۷ × ۸ پایله څومره ده؟', 'Combien font 7 × 8 ?', '["54","56","63","64"]', '["54","56","63","64"]', '["۵۴","۵۶","۶۳","۶۴"]', '["54","56","63","64"]', 1, 100),
('aq_03', 'کدام سیاره به «سیارهٔ سرخ» معروف است؟', 'Which planet is known as the Red Planet?', 'کوم سیاره د «سور سیاره» په نوم یادیږي؟', 'Quelle planète est connue sous le nom de planète rouge ?', '["زهره","مریخ","مشتری","زحل"]', '["Venus","Mars","Jupiter","Saturn"]', '["زهره","مریخ","مشتري","زحل"]', '["Vénus","Mars","Jupiter","Saturne"]', 1, 100),
('aq_04', 'آب از چند عنصر شیمیایی ساخته شده؟', 'How many chemical elements make up water?', 'اوبه له څو کیمیاوي عنصرونو څخه جوړې شوې دي؟', 'De combien d''éléments chimiques l''eau est-elle composée ?', '["۱","۲","۳","۴"]', '["1","2","3","4"]', '["۱","۲","۳","۴"]', '["1","2","3","4"]', 1, 100),
('aq_05', 'بزرگ‌ترین اقیانوس جهان کدام است؟', 'What is the largest ocean in the world?', 'د نړۍ ترټولو لوی سمندر کوم دی؟', 'Quel est le plus grand océan du monde ?', '["اطلس","آرام (پاسفیک)","هند","منجمد شمالی"]', '["Atlantic","Pacific","Indian","Arctic"]', '["اتلانتیک","پاسیفیک","هند","شمالي منجمد"]', '["Atlantique","Pacifique","Indien","Arctique"]', 1, 100),
('aq_06', 'نویسندهٔ شاهنامه کیست؟', 'Who wrote the Shahnameh?', 'د شاهنامې لیکوال څوک دی؟', 'Qui a écrit le Shahnameh ?', '["فردوسی","سعدی","حافظ","مولانا"]', '["Ferdowsi","Saadi","Hafez","Rumi"]', '["فردوسي","سعدي","حافظ","مولانا"]', '["Ferdowsi","Saadi","Hafez","Rumi"]', 0, 100),
('aq_07', 'یک سال چند روز دارد (سال کبیسه نبود)؟', 'How many days are in a non-leap year?', 'یو کال څو ورځې لري (کبیسه نه وي)؟', 'Combien de jours compte une année non bissextile ?', '["۳۶۰","۳۶۵","۳۶۶","۳۶۴"]', '["360","365","366","364"]', '["۳۶۰","۳۶۵","۳۶۶","۳۶۴"]', '["360","365","366","364"]', 1, 100),
('aq_08', 'نماد شیمیایی طلا چیست؟', 'What is the chemical symbol for gold?', 'د سرو زرو کیمیاوي سمبول څه دی؟', 'Quel est le symbole chimique de l''or ?', '["Au","Ag","Gd","Fe"]', '["Au","Ag","Gd","Fe"]', '["Au","Ag","Gd","Fe"]', '["Au","Ag","Gd","Fe"]', 0, 100),
('aq_09', 'بلندترین قلهٔ جهان کدام است؟', 'What is the tallest mountain in the world?', 'د نړۍ ترټولو لوړ غره کوم دی؟', 'Quelle est la plus haute montagne du monde ?', '["کی‌ٹو (K2)","اورست","دماوند","نوشاق"]', '["K2","Everest","Damavand","Noshaq"]', '["کی۲","اورست","دماوند","نوشاق"]', '["K2","Everest","Damavand","Noshaq"]', 1, 100),
('aq_10', 'نتیجهٔ جذر ۸۱ چند است؟', 'What is the square root of 81?', 'د ۸۱ جذر څومره دی؟', 'Quelle est la racine carrée de 81 ?', '["۷","۸","۹","۱۰"]', '["7","8","9","10"]', '["۷","۸","۹","۱۰"]', '["7","8","9","10"]', 2, 100),
('aq_11', 'کدام‌یک از این‌ها یک زبان برنامه‌نویسی نیست؟', 'Which of these is NOT a programming language?', 'د دې څخه کوم یو د پروګرام کولو ژبه نه ده؟', 'Lequel de ces éléments n''est PAS un langage de programmation ?', '["Python","Dart","HTML","Java"]', '["Python","Dart","HTML","Java"]', '["Python","Dart","HTML","Java"]', '["Python","Dart","HTML","Java"]', 2, 120),
('aq_12', 'قلب انسان چند حفره دارد؟', 'How many chambers does the human heart have?', 'د انسان زړه څو خونې لري؟', 'Combien de cavités compte le cœur humain ?', '["۲","۳","۴","۵"]', '["2","3","4","5"]', '["۲","۳","۴","۵"]', '["2","3","4","5"]', 2, 100),
('aq_13', 'بزرگ‌ترین کشور جهان از نظر مساحت کدام است؟', 'What is the largest country in the world by area?', 'د نړۍ ترټولو لوی هیواد د مساحت له مخې کوم دی؟', 'Quel est le plus grand pays du monde en superficie ?', '["چین","کانادا","روسیه","امریکا"]', '["China","Canada","Russia","USA"]', '["چین","کاناډا","روسیه","امریکا"]', '["Chine","Canada","Russie","États-Unis"]', 2, 100),
('aq_14', 'نور خورشید تقریباً در چند دقیقه به زمین می‌رسد؟', 'About how many minutes does sunlight take to reach Earth?', 'د لمر رڼا تقریباً په څو دقیقو کې ځمکې ته رسیږي؟', 'Combien de minutes environ la lumière du soleil met-elle pour atteindre la Terre ?', '["۲","۸","۲۰","۶۰"]', '["2","8","20","60"]', '["۲","۸","۲۰","۶۰"]', '["2","8","20","60"]', 1, 120),
('aq_15', 'واحد اندازه‌گیری جریان برق چیست؟', 'What is the unit of electric current?', 'د بریښنایي جریان اندازه کولو واحد څه دی؟', 'Quelle est l''unité de mesure du courant électrique ?', '["ولت","وات","آمپر","اهم"]', '["Volt","Watt","Ampere","Ohm"]', '["ولټ","واټ","امپیر","اوم"]', '["Volt","Watt","Ampère","Ohm"]', 2, 100);

-- یک رویداد نمونه ۳ روز بعد از اجرای این مهاجرت — ۱۰ سؤال تصادفی از بانک بالا،
-- بازهٔ ۴۵ دقیقه‌ای برای پیوستن/برگزاری، فقط شاگردان لیگ «فرزانگان» (مقام ≥۲۱) به بالا.
INSERT INTO arena_events (id, title_fa, starts_at, ends_at, status, min_rank_no, question_count, time_limit_seconds)
VALUES ('arena_launch_event', 'نبرد زندهٔ آغازین آرنا', datetime('now', '+3 days'), datetime('now', '+3 days', '+45 minutes'), 'scheduled', 21, 10, 15);

INSERT INTO arena_event_questions (event_id, seq, question_id)
SELECT 'arena_launch_event', (ROW_NUMBER() OVER (ORDER BY RANDOM())) - 1, id
FROM arena_question_bank WHERE active = 1 LIMIT 10;

-- حالا که آرنا واقعاً ساخته شده، متن «به‌زودی» را از پاداش مقام ۵۰ برمی‌داریم.
UPDATE rank_tiers
SET reward_label_fa = 'مقام سیمرغ دانش — واجد‌شرایط نبرد زندهٔ آرنا برای مقام اول'
WHERE rank_no = 50;
