# دانلود کتاب‌های رسمی نصاب تعلیمی وزارت معارف افغانستان (صنف ۷ الی ۱۲)
# منبع: moe.gov.af  |  ذخیره در پوشه curriculum_pdfs کنار پروژه
# طرز استفاده: روی این فایل راست-کلیک کنید -> "Run with PowerShell"
# (اگر اجرا نشد، یک بار این دستور را در PowerShell بزنید: Set-ExecutionPolicy -Scope Process Bypass -Force)

$ErrorActionPreference = "Continue"
$base = "https://moe.gov.af/sites/default/files/2020-03"
$root = Join-Path $PSScriptRoot "curriculum_pdfs"

# نگاشت: نام درس در اپلیکیشن -> (کد فایل در سایت وزارت, صنوف موجود)
$subjects = @{
    "Math"       = @{ token = "Math";          grades = 7..12 }
    "Physics"    = @{ token = "Physic";        grades = 7..12 }
    "Chemistry"  = @{ token = "Chemistry";     grades = 7..12 }
    "Biology"    = @{ token = "Biology";       grades = 7..12 }
    "English"    = @{ token = "English";       grades = 7..12 }
    "Dari"       = @{ token = "Dari";          grades = 7..12 }
    "History"    = @{ token = "History";       grades = 7..12 }
    "Geography"  = @{ token = "Geography";     grades = 7..12 }
    "Islamic"    = @{ token = "Islamic_Study"; grades = 7..12 }
    "Computer"   = @{ token = "Computer";      grades = 10..12 }  # درس کمپیوتر فقط از صنف ۱۰ در نصاب رسمی شامل است
}

New-Item -ItemType Directory -Force -Path $root | Out-Null

$total = 0
$ok = 0
$fail = @()

foreach ($subjName in $subjects.Keys) {
    $info = $subjects[$subjName]
    $subjDir = Join-Path $root $subjName
    New-Item -ItemType Directory -Force -Path $subjDir | Out-Null

    foreach ($g in $info.grades) {
        $total++
        $fileName = "G$g-Ps-$($info.token).pdf"
        $url = "$base/$fileName"
        $outFile = Join-Path $subjDir "Grade$g.pdf"

        if ((Test-Path $outFile) -and (Get-Item $outFile).Length -gt 200000) {
            Write-Host "[SKIP] $subjName Grade $g (already downloaded)" -ForegroundColor DarkGray
            $ok++
            continue
        }

        Write-Host "[...] $subjName Grade $g -> $fileName" -NoNewline
        $attempt = 0
        $success = $false
        while ($attempt -lt 3 -and -not $success) {
            $attempt++
            if (Test-Path $outFile) { Remove-Item $outFile -Force }
            try {
                # حداکثر 45 ثانیه فرصت برای هر تلاش؛ اگر سرور کند/متوقف شد، قطع و تلاش دوباره
                & curl.exe -sS -L --ssl-no-revoke --fail --connect-timeout 15 --max-time 45 -o $outFile $url 2>$null
                if ($LASTEXITCODE -eq 0 -and (Test-Path $outFile) -and (Get-Item $outFile).Length -gt 10000) {
                    $success = $true
                }
            } catch {
                # نادیده گرفتن و تلاش دوباره
            }
        }
        if ($success) {
            $sizeKB = [math]::Round((Get-Item $outFile).Length / 1KB)
            Write-Host "`r[OK]   $subjName Grade $g  ($sizeKB KB)          " -ForegroundColor Green
            $ok++
        } else {
            if (Test-Path $outFile) { Remove-Item $outFile -Force }
            Write-Host "`r[FAIL] $subjName Grade $g  (server too slow/unstable after 3 tries)   " -ForegroundColor Red
            $fail += "$subjName Grade $g ($fileName)"
        }
    }
}

Write-Host ""
Write-Host "==============================================="
Write-Host "تمام شد: $ok از $total کتاب با موفقیت دانلود شد."
if ($fail.Count -gt 0) {
    Write-Host "این موارد دانلود نشدند:" -ForegroundColor Yellow
    $fail | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}
Write-Host "محل ذخیره: $root"
Write-Host "==============================================="
Read-Host "برای بستن، کلید Enter را بزنید"
