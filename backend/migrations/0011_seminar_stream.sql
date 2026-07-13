-- پخش زندهٔ سمینار با Cloudflare Stream.
-- stream_uid: شناسهٔ ورودیِ زندهٔ (Live Input) Cloudflare.
-- stream_playback_url: نشانی پخش HLS برای شاگردان.
ALTER TABLE seminars ADD COLUMN stream_uid TEXT NOT NULL DEFAULT '';
ALTER TABLE seminars ADD COLUMN stream_playback_url TEXT NOT NULL DEFAULT '';
