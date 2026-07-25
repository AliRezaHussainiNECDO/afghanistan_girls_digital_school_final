-- ═══════════════════════════════════════════════════════════════════════════
-- 0045_content_translations.sql — ترجمهٔ نصاب به زبان‌های دیگر (اول پشتو).
--
-- چرا یک جدول جدا (نه ستون title_ps/content_ps روی خودِ subjects/chapters/
-- lessons)؟ چون این‌طور افزودن زبان‌های بعدی (مثلاً انگلیسی در آینده) هیچ
-- مهاجرت جدیدی نمی‌خواهد، و محتوای دری اصلی («منبع حقیقت») دست‌نخورده و جدا
-- می‌ماند — اگر ترجمه‌ای خراب/ناقص بود، فقط همان ردیف پاک می‌شود.
--
-- entity_type: 'subject' | 'chapter' | 'lesson'
--   • برای subject/chapter فقط «title» پر می‌شود (body خالی).
--   • برای lesson هم «title» و هم «body» (متن کامل درس) پر می‌شود.
-- status: 'draft' (تازه با AI ساخته شده، هنوز مدیر مرور نکرده) | 'published'
--   (مدیر تأیید کرده — تنها حالتی که به شاگردان نمایش داده می‌شود).
--
-- اجرا:
--   npx wrangler d1 migrations apply afghan_girls_school_db --remote
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS content_translations (
  id           TEXT PRIMARY KEY,
  entity_type  TEXT NOT NULL,                 -- subject|chapter|lesson
  entity_id    TEXT NOT NULL,
  language     TEXT NOT NULL,                 -- ps (آیندهٔ: en, ...)
  title        TEXT NOT NULL DEFAULT '',
  body         TEXT NOT NULL DEFAULT '',
  status       TEXT NOT NULL DEFAULT 'draft',  -- draft|published
  source       TEXT NOT NULL DEFAULT 'ai',     -- ai|manual — برای شفافیت در پنل مدیر
  translated_by TEXT,                          -- شناسهٔ مدیری که تولید/تأیید کرده (اختیاری)
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at   TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (entity_type, entity_id, language)
);
CREATE INDEX IF NOT EXISTS idx_content_translations_entity ON content_translations(entity_type, entity_id, language);
CREATE INDEX IF NOT EXISTS idx_content_translations_status ON content_translations(status);
