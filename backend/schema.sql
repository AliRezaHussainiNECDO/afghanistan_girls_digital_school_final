-- طرحوارهٔ دیتابیس D1 — بک‌اند واقعی چت صنف‌محور، کتاب‌های نصاب، و رضایت‌نامه‌ها.
-- اجرا: wrangler d1 execute afghan_girls_school_db --remote --file=./schema.sql
--
-- منطق چت (هماهنگ با اپ فلاتر، بخش ۱۰ سند):
--   • هر گفتگو به یک صنف (class_id) تعلق دارد تا مدیر بتواند چت‌ها را
--     صنف‌به‌صنف بازبینی کند (بخش ۱۰.۴).
--   • هر پیام هویت واقعی فرستنده (sender_name + sender_class_name) را حمل
--     می‌کند تا در نمای نظارتی مدیر نمایش داده شود.
--   • پیام flag‌شده تا تأیید مدیر (review_status) به گیرنده نمی‌رسد.

CREATE TABLE IF NOT EXISTS conversations (
  id TEXT PRIMARY KEY,               -- dm_<idA>_<idB> (مرتب‌شده) یا admin_<studentId>
  type TEXT NOT NULL DEFAULT 'dm',   -- 'dm' | 'admin'
  class_id TEXT NOT NULL,
  class_name TEXT NOT NULL DEFAULT '',
  participants TEXT NOT NULL,        -- JSON: [{id, name, className}, ...]
  last_message TEXT,
  last_message_at TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_conversations_class ON conversations(class_id);
CREATE INDEX IF NOT EXISTS idx_conversations_type ON conversations(type);

CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  sender_name TEXT NOT NULL DEFAULT '',       -- هویت واقعی برای نمای مدیر
  sender_class_name TEXT NOT NULL DEFAULT '',
  body TEXT,
  kind TEXT NOT NULL DEFAULT 'text', -- 'text' | 'voice'
  audio_key TEXT,                    -- کلید فایل صوتی در R2
  duration_ms INTEGER,
  flagged INTEGER NOT NULL DEFAULT 0,
  review_status TEXT NOT NULL DEFAULT 'none', -- 'none'|'pending'|'approved'|'rejected'
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (conversation_id) REFERENCES conversations(id)
);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_flagged ON messages(flagged, review_status);

CREATE TABLE IF NOT EXISTS chat_reports (
  id TEXT PRIMARY KEY,
  message_id TEXT NOT NULL,
  reason TEXT NOT NULL,
  reported_by_id TEXT NOT NULL,
  reported_by_name TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'open', -- 'open'|'reviewed'|'dismissed'|'escalated'
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS curriculum_books (
  id TEXT PRIMARY KEY,
  subject_id TEXT NOT NULL,
  title TEXT NOT NULL,
  page_count INTEGER,
  pdf_key TEXT NOT NULL,       -- کلید فایل پی‌دی‌اف در R2
  extracted_text TEXT,         -- متن استخراج‌شده (پایهٔ RAG)
  uploaded_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_books_subject ON curriculum_books(subject_id);

CREATE TABLE IF NOT EXISTS consents (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  version TEXT NOT NULL,
  accepted_at TEXT NOT NULL DEFAULT (datetime('now'))
);
