param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi")
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectPath

$expectedVersion = "0.1.12+12"
$releaseDir = Join-Path $ProjectPath "release\google_play"
$finalAab = Join-Path $releaseDir "Keepi-0.1.12-build12.aab"

Write-Host ""
Write-Host "Preparing Keepi 0.1.12 build 12 for Google Play Internal testing" -ForegroundColor Green
Write-Host ""

git fetch origin main | Out-Host
if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }

$head = (git rev-parse HEAD).Trim()
$origin = (git rev-parse origin/main).Trim()

if ($head -ne $origin) {
    throw "Your local Keepi is not the latest origin/main. Run git pull and try again."
}

$dirty = git status --porcelain --untracked-files=no
if ($dirty) {
    Write-Host "Tracked local changes:" -ForegroundColor Red
    $dirty | Out-Host
    throw "Restore or commit tracked local changes before preparing version 12."
}

$versionLine = (Get-Content (Join-Path $ProjectPath "pubspec.yaml") |
    Where-Object { $_ -match '^version:' } |
    Select-Object -First 1)

if ($versionLine -notmatch [regex]::Escape($expectedVersion)) {
    throw "Expected Keepi version $expectedVersion, but found: $versionLine"
}

$keyProperties = Join-Path $ProjectPath "android\key.properties"
$keystore = Join-Path $ProjectPath "android\app\upload-keystore.jks"

if (-not (Test-Path $keyProperties) -or -not (Test-Path $keystore)) {
    throw "Google Play upload signing is missing. Expected android\key.properties and android\app\upload-keystore.jks."
}

Write-Host "1/7 Cleaning..." -ForegroundColor Cyan
flutter.bat clean | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed." }

Write-Host "2/7 Dependencies..." -ForegroundColor Cyan
flutter.bat pub get | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

Write-Host "3/7 Generating icons..." -ForegroundColor Cyan
dart.bat run "tool\generate_native_icons.dart" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Icon generation failed." }

Write-Host "4/7 Analyze..." -ForegroundColor Cyan
flutter.bat analyze | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed." }

Write-Host "5/7 Tests..." -ForegroundColor Cyan
flutter.bat test | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter test failed." }

Write-Host "6/7 Firebase production config..." -ForegroundColor Cyan
$firebaseDefines = @(dart.bat run "tool\print_firebase_defines.dart" android)
if ($LASTEXITCODE -ne 0 -or $firebaseDefines.Count -lt 4) {
    throw "Could not read Android Firebase configuration."
}

Write-Host "7/7 Building signed AAB..." -ForegroundColor Cyan
flutter.bat build appbundle --release @firebaseDefines | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Android AAB build failed." }

$sourceAab = Join-Path $ProjectPath "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path $sourceAab)) {
    throw "The AAB was not created."
}

New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
Copy-Item -Force $sourceAab $finalAab

$sizeMb = [math]::Round((Get-Item $finalAab).Length / 1MB, 1)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "KEEPI VERSION 12 IS READY FOR GOOGLE PLAY TESTING" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Version: $expectedVersion" -ForegroundColor Yellow
Write-Host "Git commit: $head" -ForegroundColor Yellow
Write-Host "AAB size: $sizeMb MB" -ForegroundColor Yellow
Write-Host ""
Write-Host "UPLOAD THIS FILE:" -ForegroundColor Cyan
Write-Host $finalAab -ForegroundColor Yellow
Write-Host ""
