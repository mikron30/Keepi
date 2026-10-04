param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi")
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectPath

$expectedVersion = "0.1.13+13"
$releaseDir = Join-Path $ProjectPath "release\google_play"
$finalAab = Join-Path $releaseDir "Keepi-0.1.13-build13.aab"

function Get-GoogleServerClientDefine {
    $googleServicesPath = Join-Path $ProjectPath "android\app\google-services.json"
    if (-not (Test-Path $googleServicesPath)) {
        throw "Missing android\app\google-services.json. Run .\setup_keepi.cmd -RunTarget none first."
    }

    $googleServices = Get-Content $googleServicesPath -Raw | ConvertFrom-Json
    $matchingClient = @($googleServices.client | Where-Object {
        $_.client_info.android_client_info.package_name -eq "com.mikron30.keepi"
    } | Select-Object -First 1)

    if (-not $matchingClient) {
        throw "google-services.json does not contain com.mikron30.keepi."
    }

    $webClient = @($matchingClient.oauth_client | Where-Object {
        [int]$_.client_type -eq 3
    } | Select-Object -First 1)

    if (-not $webClient -or [string]::IsNullOrWhiteSpace($webClient.client_id)) {
        throw "Google Sign-In is not fully configured. Enable Google provider in Firebase Authentication, then rerun .\setup_keepi.cmd -RunTarget none."
    }

    Write-Host "Google Web OAuth client found." -ForegroundColor Green
    return "--dart-define=KEEPI_GOOGLE_SERVER_CLIENT_ID=$($webClient.client_id)"
}

Write-Host ""
Write-Host "Preparing Keepi 0.1.13 build 13 for Google Play Internal testing" -ForegroundColor Green
Write-Host ""

git fetch origin main | Out-Host
if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }

$head = (git rev-parse HEAD).Trim()
$origin = (git rev-parse origin/main).Trim()

if ($head -ne $origin) {
    throw "Local Keepi is not origin/main. Run git pull first."
}

$dirty = git status --porcelain --untracked-files=no
if ($dirty) {
    Write-Host "Tracked local changes:" -ForegroundColor Red
    $dirty | Out-Host
    throw "Restore or commit tracked local changes before building."
}

$versionLine = (Get-Content (Join-Path $ProjectPath "pubspec.yaml") |
    Where-Object { $_ -match '^version:' } |
    Select-Object -First 1)

if ($versionLine -notmatch [regex]::Escape($expectedVersion)) {
    throw "Expected $expectedVersion, found: $versionLine"
}

if (-not (Test-Path "android\key.properties") -or
    -not (Test-Path "android\app\upload-keystore.jks")) {
    throw "Android Google Play signing is not configured."
}

Write-Host "1/7 Clean..." -ForegroundColor Cyan
flutter.bat clean | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed." }

Write-Host "2/7 Dependencies..." -ForegroundColor Cyan
flutter.bat pub get | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

Write-Host "3/7 Icons..." -ForegroundColor Cyan
dart.bat run "tool\generate_native_icons.dart" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Icon generation failed." }

Write-Host "4/7 Analyze..." -ForegroundColor Cyan
flutter.bat analyze | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed." }

Write-Host "5/7 Tests..." -ForegroundColor Cyan
flutter.bat test | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter test failed." }

Write-Host "6/7 Firebase + Google OAuth config..." -ForegroundColor Cyan
$firebaseDefines = @(dart.bat run "tool\print_firebase_defines.dart" android)
if ($LASTEXITCODE -ne 0 -or $firebaseDefines.Count -lt 4) {
    throw "Could not read Android Firebase configuration."
}
$firebaseDefines += Get-GoogleServerClientDefine

Write-Host "7/7 Signed AAB..." -ForegroundColor Cyan
flutter.bat build appbundle --release @firebaseDefines | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Android AAB build failed." }

$sourceAab = Join-Path $ProjectPath "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path $sourceAab)) { throw "AAB was not created." }

New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
Copy-Item -Force $sourceAab $finalAab

$sizeMb = [math]::Round((Get-Item $finalAab).Length / 1MB, 1)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "KEEPI 0.1.13 BUILD 13 READY" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Git commit: $head" -ForegroundColor Yellow
Write-Host "AAB size: $sizeMb MB" -ForegroundColor Yellow
Write-Host ""
Write-Host "UPLOAD THIS FILE:" -ForegroundColor Cyan
Write-Host $finalAab -ForegroundColor Yellow
