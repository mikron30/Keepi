param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi"),
    [string]$Sha1 = "",
    [string]$Sha256 = ""
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectPath

if (-not (Get-Command "firebase.cmd" -ErrorAction SilentlyContinue)) {
    throw "Firebase CLI is missing. Run .\setup_keepi.cmd -RunTarget none first."
}

$optionsPath = Join-Path $ProjectPath "lib\firebase_options.dart"
if (-not (Test-Path $optionsPath)) {
    throw "Missing lib\firebase_options.dart."
}

$content = Get-Content $optionsPath -Raw
$androidBlock = [regex]::Match(
    $content,
    "static const FirebaseOptions android = FirebaseOptions\((?<body>.*?)\n\s*\);",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)

if (-not $androidBlock.Success) {
    throw "Could not read Firebase Android options."
}

$body = $androidBlock.Groups["body"].Value

function Read-Field([string]$Name) {
    $m = [regex]::Match($body, $Name + "\s*:\s*'([^']*)'")
    if (-not $m.Success) { return "" }
    return $m.Groups[1].Value
}

$projectId = Read-Field "projectId"
$appId = Read-Field "appId"

if ([string]::IsNullOrWhiteSpace($projectId) -or
    [string]::IsNullOrWhiteSpace($appId)) {
    throw "Firebase projectId/appId are missing."
}

Write-Host ""
Write-Host "Keepi Firebase project: $projectId" -ForegroundColor Cyan
Write-Host "Keepi Android app id:  $appId" -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrWhiteSpace($Sha1)) {
    $Sha1 = Read-Host "Paste PLAY APP SIGNING SHA-1"
}

if ([string]::IsNullOrWhiteSpace($Sha256)) {
    $Sha256 = Read-Host "Paste PLAY APP SIGNING SHA-256 (or press Enter to skip)"
}

$Sha1 = $Sha1.Trim()
$Sha256 = $Sha256.Trim()

if ([string]::IsNullOrWhiteSpace($Sha1)) {
    throw "SHA-1 is required for Google Sign-In."
}

Write-Host ""
Write-Host "Registering Play App Signing SHA-1 in Firebase..." -ForegroundColor Green
firebase.cmd apps:android:sha:create $appId $Sha1 --project $projectId | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host "SHA-1 may already exist. Listing current fingerprints..." -ForegroundColor Yellow
}

if (-not [string]::IsNullOrWhiteSpace($Sha256)) {
    Write-Host "Registering Play App Signing SHA-256 in Firebase..." -ForegroundColor Green
    firebase.cmd apps:android:sha:create $appId $Sha256 --project $projectId | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Host "SHA-256 may already exist." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Current Firebase Android SHA fingerprints:" -ForegroundColor Cyan
firebase.cmd apps:android:sha:list $appId --project $projectId | Out-Host

Write-Host ""
Write-Host "DONE." -ForegroundColor Green
Write-Host "Wait 5-10 minutes, force-close Keepi, reopen it, and try Google Sign-In again." -ForegroundColor Yellow
Write-Host "No new AAB is normally required for this Play-signing fingerprint fix." -ForegroundColor Yellow
