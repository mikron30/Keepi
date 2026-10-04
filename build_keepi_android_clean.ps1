param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi")
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectPath

Write-Host ""
Write-Host "Keepi verified clean Android build" -ForegroundColor Green
Write-Host ""

git fetch origin main | Out-Host
if ($LASTEXITCODE -ne 0) { throw "git fetch failed." }

$head = (git rev-parse HEAD).Trim()
$origin = (git rev-parse origin/main).Trim()

Write-Host "Local HEAD : $head"
Write-Host "origin/main: $origin"

if ($head -ne $origin) {
    throw "Local repository is not exactly origin/main. Run git pull before building."
}

$dirty = git status --porcelain --untracked-files=no
if ($dirty) {
    Write-Host ""
    Write-Host "Tracked local changes found:" -ForegroundColor Red
    $dirty | Out-Host
    throw "Clean or restore tracked changes before building. Signing files are untracked and are not affected."
}

$keyProperties = Join-Path $ProjectPath "android\key.properties"
$keystore = Join-Path $ProjectPath "android\app\upload-keystore.jks"
if (-not (Test-Path $keyProperties) -or -not (Test-Path $keystore)) {
    throw "Android release signing is not configured."
}

Write-Host "Cleaning Flutter output..." -ForegroundColor Cyan
flutter.bat clean | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed." }

flutter.bat pub get | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

dart.bat run "tool\generate_native_icons.dart" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Icon generation failed." }

flutter.bat analyze | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter analyze failed." }

flutter.bat test | Out-Host
if ($LASTEXITCODE -ne 0) { throw "flutter test failed." }

$firebaseDefines = @(dart.bat run "tool\print_firebase_defines.dart" android)
if ($LASTEXITCODE -ne 0 -or $firebaseDefines.Count -lt 4) {
    throw "Could not read Android Firebase configuration."
}

flutter.bat build appbundle --release @firebaseDefines | Out-Host
if ($LASTEXITCODE -ne 0) { throw "AAB build failed." }

$aab = Join-Path $ProjectPath "build\app\outputs\bundle\release\app-release.aab"
if (-not (Test-Path $aab)) { throw "AAB was not created." }

$versionLine = (Get-Content (Join-Path $ProjectPath "pubspec.yaml") |
    Where-Object { $_ -match '^version:' } |
    Select-Object -First 1)

Write-Host ""
Write-Host "VERIFIED BUILD COMPLETE" -ForegroundColor Green
Write-Host "Git commit: $head" -ForegroundColor Yellow
Write-Host $versionLine -ForegroundColor Yellow
Write-Host "AAB: $aab" -ForegroundColor Yellow
