-- ═══════════════════════════════════════════════════════════════════════════
-- 0010_seminar_link.sql — لینک جلسهٔ زندهٔ خارجی سمینار (Zoom/Meet/Jitsi)
-- بخش ۱۲ سند. اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0010_seminar_link.sql
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE seminars ADD COLUMN meeting_link TEXT NOT NULL DEFAULT '';

-- یک لینک نمونه برای سمینار زندهٔ نمایشی (اختیاری — قابل تغییر توسط استاد).
UPDATE seminars SET meeting_link = 'https://meet.jit.si/AGDS-Seminar-Demo' WHERE id = 'sem-seed-1';
