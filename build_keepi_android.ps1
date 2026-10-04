param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi")
)

$ErrorActionPreference = "Stop"

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
        throw "google-services.json does not contain Android package com.mikron30.keepi."
    }

    $webClient = @($matchingClient.oauth_client | Where-Object {
        [int]$_.client_type -eq 3
    } | Select-Object -First 1)

    if (-not $webClient -or [string]::IsNullOrWhiteSpace($webClient.client_id)) {
        throw "Google Sign-In is not fully configured: google-services.json has no Web OAuth client (client_type 3). Enable Google in Firebase Authentication, then run .\setup_keepi.cmd -RunTarget none again."
    }

    return "--dart-define=KEEPI_GOOGLE_SERVER_CLIENT_ID=$($webClient.client_id)"
}


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

dart.bat run "tool\export_play_store_assets.dart" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Google Play asset generation failed." }

$firebaseDefines = @(dart.bat run "tool\print_firebase_defines.dart" android)
if ($LASTEXITCODE -ne 0 -or $firebaseDefines.Count -lt 4) {
    throw "Could not read Android Firebase configuration."
}
$googleServerClientDefine = Get-GoogleServerClientDefine
$firebaseDefines += $googleServerClientDefine

flutter build apk --release @firebaseDefines
if ($LASTEXITCODE -ne 0) { throw "Android APK build failed." }

flutter build appbundle --release @firebaseDefines
if ($LASTEXITCODE -ne 0) { throw "Android AAB build failed." }

Write-Host ""
Write-Host "Android build complete:" -ForegroundColor Green
Write-Host (Join-Path $ProjectPath "build\app\outputs\flutter-apk\app-release.apk") -ForegroundColor Yellow
Write-Host (Join-Path $ProjectPath "build\app\outputs\bundle\release\app-release.aab") -ForegroundColor Yellow
Write-Host ""
Write-Host "Google Play assets:" -ForegroundColor Green
Write-Host (Join-Path $ProjectPath "release\google_play\assets\app_icon_512.png") -ForegroundColor Yellow
Write-Host (Join-Path $ProjectPath "release\google_play\assets\feature_graphic_1024x500.png") -ForegroundColor Yellow
