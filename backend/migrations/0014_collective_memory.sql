-- ═══════════════════════════════════════════════════════════════════════════
-- 0014_collective_memory.sql — «حافظهٔ جمعی»: پست‌ها و کامنت‌ها روی سرور
-- تا بین همهٔ کاربران به‌اشتراک گذاشته شوند (نه فقط روی یک دستگاه).
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0014_collective_memory.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS memory_posts (
  id                  TEXT PRIMARY KEY,
  author_id           TEXT NOT NULL,
  author_name         TEXT NOT NULL DEFAULT '',
  author_is_admin     INTEGER NOT NULL DEFAULT 0,
  author_avatar_b64   TEXT,                              -- عکس نویسنده (Base64) یا NULL
  body                TEXT NOT NULL DEFAULT '',
  images_json         TEXT NOT NULL DEFAULT '[]',        -- آرایهٔ JSON از تصاویر Base64
  reactions_json      TEXT NOT NULL DEFAULT '{}',        -- {emoji: [userId,...]}
  created_at          TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at          TEXT,
  FOREIGN KEY (author_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_memory_posts_created ON memory_posts(created_at DESC);

CREATE TABLE IF NOT EXISTS memory_comments (
  id                  TEXT PRIMARY KEY,
  post_id             TEXT NOT NULL,
  parent_comment_id   TEXT,                              -- NULL = کامنت اصلی
  author_id           TEXT NOT NULL,
  author_name         TEXT NOT NULL DEFAULT '',
  author_is_admin     INTEGER NOT NULL DEFAULT 0,
  author_avatar_b64   TEXT,
  body                TEXT NOT NULL DEFAULT '',
  created_at          TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (post_id) REFERENCES memory_posts(id)
);
CREATE INDEX IF NOT EXISTS idx_memory_comments_post ON memory_comments(post_id);

-- روایت‌های نمونهٔ محترمانه (اولین‌بار) — تا فضای خالی نباشد.
INSERT OR IGNORE INTO memory_posts (id, author_id, author_name, author_is_admin, body, reactions_json, created_at) VALUES
  ('seed_post_1', 'u_super_admin_ali', 'مدیریت مکتب دیجیتال', 1,
   'به «حافظهٔ جمعی» خوش آمدید 🌸 این‌جا فضایی امن برای روایت تجربه‌ها، بازدیدها و صدای دختران و زنان افغانستان است. هر داستانی که این‌جا می‌نویسید، بخشی از تاریخ ماندگار می‌شود.',
   '{"🌸":["u_super_admin_ali"],"🙏":["u_super_admin_ali"]}', datetime('now','-3 days'));
