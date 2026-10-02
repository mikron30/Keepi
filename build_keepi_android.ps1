param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi")
)

$ErrorActionPreference = "Stop"

Set-Location $ProjectPath

Write-Host ""
Write-Host "Keepi Android - production build" -ForegroundColor Green

if (-not (Test-Path "lib\firebase_options.dart")) {
    throw "Missing lib\firebase_options.dart. Run setup_keepi.ps1 / flutterfire configure first."
}

if (-not (Test-Path "android\key.properties") -or -not (Test-Path "android\app\upload-keystore.jks")) {
    throw "Android release signing is not configured. Run .\setup_android_signing.cmd once, then run this build again."
}

flutter clean
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed." }

flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed." }

dart.bat run "tool\generate_native_icons.dart" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Keepi icon generation failed." }

$firebaseDefines = @(dart.bat run "tool\print_firebase_defines.dart" android)
if ($LASTEXITCODE -ne 0 -or $firebaseDefines.Count -lt 4) {
    throw "Could not read Android Firebase configuration."
}

flutter build apk --release @firebaseDefines
if ($LASTEXITCODE -ne 0) { throw "Android APK build failed." }

flutter build appbundle --release @firebaseDefines
if ($LASTEXITCODE -ne 0) { throw "Android AAB build failed." }

Write-Host ""
Write-Host "Android build complete:" -ForegroundColor Green
Write-Host (Join-Path $ProjectPath "build\app\outputs\flutter-apk\app-release.apk") -ForegroundColor Yellow
Write-Host (Join-Path $ProjectPath "build\app\outputs\bundle\release\app-release.aab") -ForegroundColor Yellow
