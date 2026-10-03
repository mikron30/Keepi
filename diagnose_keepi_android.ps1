param(
    [string]$PackageName = "com.mikron30.keepi"
)

$ErrorActionPreference = "Stop"

function Find-Adb {
    $candidates = @()

    if ($env:ANDROID_SDK_ROOT) {
        $candidates += (Join-Path $env:ANDROID_SDK_ROOT "platform-tools\adb.exe")
    }

    if ($env:ANDROID_HOME) {
        $candidates += (Join-Path $env:ANDROID_HOME "platform-tools\adb.exe")
    }

    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe")
    }

    $pathAdb = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($pathAdb) {
        $candidates += $pathAdb.Source
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return $null
}

$adb = Find-Adb
if (-not $adb) {
    throw "adb.exe was not found. Install Android SDK Platform Tools or Android Studio."
}

Write-Host ""
Write-Host "Keepi Android crash diagnostic" -ForegroundColor Green
Write-Host "ADB: $adb" -ForegroundColor Cyan
Write-Host ""

$devices = & $adb devices
$deviceLines = @($devices | Select-Object -Skip 1 | Where-Object {
    $_ -match "\sdevice$"
})

if ($deviceLines.Count -eq 0) {
    Write-Host "No authorized Android device is connected." -ForegroundColor Red
    Write-Host ""
    Write-Host "Connect the phone by USB with USB debugging enabled," -ForegroundColor Yellow
    Write-Host "or use Android Developer options > Wireless debugging." -ForegroundColor Yellow
    Write-Host "Then run this script again." -ForegroundColor Yellow
    exit 2
}

Write-Host "Connected device:" -ForegroundColor Green
$deviceLines | ForEach-Object { Write-Host "  $_" }

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$fullLog = Join-Path $PSScriptRoot "keepi_crash_log_$timestamp.txt"
$summaryLog = Join-Path $PSScriptRoot "keepi_crash_summary_$timestamp.txt"

Write-Host ""
Write-Host "Stopping Keepi and clearing logcat..." -ForegroundColor Cyan
& $adb shell am force-stop $PackageName | Out-Null
& $adb logcat -c | Out-Null

Write-Host "Launching Keepi..." -ForegroundColor Cyan
& $adb shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null

Write-Host "Waiting for the crash..." -ForegroundColor Cyan
Start-Sleep -Seconds 8

Write-Host "Collecting logcat..." -ForegroundColor Cyan
& $adb logcat -d -v time | Set-Content -Encoding UTF8 $fullLog

$patterns = @(
    "FATAL EXCEPTION",
    "AndroidRuntime",
    "Process: $PackageName",
    $PackageName,
    "Caused by:",
    "Exception",
    "Error",
    "Firebase",
    "MobileAds",
    "Google Mobile Ads",
    "flutter"
)

$summary = Get-Content $fullLog | Where-Object {
    $line = $_
    $patterns | Where-Object { $line -match [regex]::Escape($_) }
}

$summary | Set-Content -Encoding UTF8 $summaryLog

Write-Host ""
Write-Host "Diagnostic complete." -ForegroundColor Green
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host $summaryLog
Write-Host "Full log:" -ForegroundColor Yellow
Write-Host $fullLog
Write-Host ""
Write-Host "Last relevant lines:" -ForegroundColor Cyan
$summary | Select-Object -Last 80 | ForEach-Object { Write-Host $_ }
