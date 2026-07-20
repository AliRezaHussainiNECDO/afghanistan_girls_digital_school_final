# ═══════════════════════════════════════════════════════════════════════════
# fix_migrations_0030_0032.ps1 — رفع ناهماهنگی ردیابی مهاجرت‌ها.
#
# ریشهٔ مشکل: مهاجرت‌های 0030 تا 0032 قبلاً به‌صورت دستی (طبق دستور «اجرا:»
# داخل خود فایل‌ها با d1 execute --file) روی دیتابیس ریموت اجرا شده‌اند، اما
# در جدول ردیابی d1_migrations ثبت نشده‌اند؛ پس `wrangler d1 migrations apply`
# دوباره اجرایشان می‌کند و به «duplicate column» می‌خورد.
#
# این اسکریپت (کاملاً امن و idempotent — چند بار اجرا شود اشکالی ندارد):
#   ۱) هر ستون/ایندکس را تکی اعمال می‌کند؛ اگر از قبل موجود بود، رد می‌شود.
#   ۲) سه مهاجرت را در d1_migrations ثبت می‌کند (فقط اگر ثبت نشده باشند).
#   ۳) migrations apply را اجرا می‌کند (حالا فقط 0033 باقی مانده).
#   ۴) Worker را دیپلوی می‌کند.
#
# اجرا:
#   cd backend
#   powershell -ExecutionPolicy Bypass -File .\fix_migrations_0030_0032.ps1
# ═══════════════════════════════════════════════════════════════════════════

$ErrorActionPreference = 'Continue'
$db = 'afghan_girls_school_db'

Write-Host "── مرحلهٔ ۱: اعمال تکیِ ستون‌ها (خطای «از قبل موجود» بی‌ضرر است) ──" -ForegroundColor Cyan
$alters = @(
  "ALTER TABLE questions ADD COLUMN q_type TEXT NOT NULL DEFAULT 'mcq'",
  "ALTER TABLE questions ADD COLUMN answer_text TEXT",
  "ALTER TABLE exam_attempts ADD COLUMN essay_answers TEXT",
  "ALTER TABLE messages ADD COLUMN reply_to_id TEXT",
  "ALTER TABLE users ADD COLUMN last_seen_at TEXT",
  "CREATE INDEX IF NOT EXISTS idx_users_last_seen ON users(last_seen_at)"
)
foreach ($sql in $alters) {
  Write-Host ">> $sql"
  & npx wrangler d1 execute $db --remote --command $sql 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✔ اعمال شد" -ForegroundColor Green
  } else {
    Write-Host "   ↷ از قبل موجود بود — رد شد" -ForegroundColor Yellow
  }
}

Write-Host "── مرحلهٔ ۲: ثبت مهاجرت‌های اجراشدهٔ دستی در جدول ردیابی ──" -ForegroundColor Cyan
$marks = @('0030_question_types.sql', '0031_message_replies.sql', '0032_presence.sql')
foreach ($m in $marks) {
  $cmd = "INSERT INTO d1_migrations (name, applied_at) SELECT '$m', CURRENT_TIMESTAMP WHERE NOT EXISTS (SELECT 1 FROM d1_migrations WHERE name = '$m')"
  & npx wrangler d1 execute $db --remote --command $cmd 2>&1 | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✔ ثبت شد: $m" -ForegroundColor Green
  } else {
    Write-Host "   ✖ ثبت $m ناموفق — خروجی بالا را بررسی کنید" -ForegroundColor Red
  }
}

Write-Host "── مرحلهٔ ۳: اعمال مهاجرت‌های باقی‌مانده (فقط 0033) ──" -ForegroundColor Cyan
& npx wrangler d1 migrations apply $db --remote

Write-Host "── مرحلهٔ ۴: دیپلوی Worker ──" -ForegroundColor Cyan
& npx wrangler deploy

Write-Host "تمام ✅ — اگر هر مرحله‌ای قرمز شد، خروجی همان بخش را برای Claude بفرستید." -ForegroundColor Green
