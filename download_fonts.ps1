# دانلود فونت Vazirmatn برای bundle کردن داخل اپ (حالت کاملاً آفلاین)
# طرز استفاده: راست-کلیک -> "Run with PowerShell"
# بعد از اجرای موفق این اسکریپت، به کلود بگویید تا pubspec و تم را به
# فونت محلی سویچ کند (یا خودتان بخش کامنت‌شدهٔ pubspec.yaml را باز کنید).

$ErrorActionPreference = "Stop"
$root = Join-Path $PSScriptRoot "assets\fonts"
New-Item -ItemType Directory -Force -Path $root | Out-Null

$base = "https://github.com/rastikerdar/vazirmatn/raw/master/fonts/ttf"
$weights = @("Regular", "Medium", "SemiBold", "Bold")

foreach ($w in $weights) {
    $file = "Vazirmatn-$w.ttf"
    $dest = Join-Path $root $file
    Write-Host "در حال دانلود $file ..."
    Invoke-WebRequest -Uri "$base/$file" -OutFile $dest
    Write-Host "  ذخیره شد: $dest" -ForegroundColor Green
}

Write-Host ""
Write-Host "همهٔ فونت‌ها دانلود شدند ✔" -ForegroundColor Green
Write-Host "حالا بخش fonts در pubspec.yaml را فعال کنید (یا از کلود بخواهید)."
