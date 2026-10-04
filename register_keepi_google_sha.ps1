param(
    [Parameter(Mandatory = $true)]
    [string]$Sha1,
    [string]$ProjectPath = (Join-Path $HOME "Keepi")
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectPath

$normalizedSha = ($Sha1.Trim().ToUpper() -replace '[^0-9A-F]', '')
if ($normalizedSha.Length -ne 40) {
    throw "SHA-1 must contain exactly 40 hexadecimal characters."
}
$formattedSha = (($normalizedSha -split '(.{2})' | Where-Object { $_ }) -join ':')

if (-not (Get-Command firebase.cmd -ErrorAction SilentlyContinue)) {
    throw "firebase.cmd was not found. Run .\setup_keepi.cmd -RunTarget none first."
}

$projectFile = Join-Path $ProjectPath ".keepi-firebase-project"
if (-not (Test-Path $projectFile)) {
    throw "Missing .keepi-firebase-project. Run .\setup_keepi.cmd -RunTarget none first."
}

$projectId = (Get-Content $projectFile -Raw).Trim()
if (-not $projectId) {
    throw "Keepi Firebase project id is empty."
}

Write-Host ""
Write-Host "Registering Google Play signing SHA-1 for Keepi" -ForegroundColor Green
Write-Host "Firebase project: $projectId"
Write-Host "SHA-1: $formattedSha" -ForegroundColor Yellow
Write-Host ""

$appsRaw = firebase.cmd apps:list --project "$projectId" --json | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "Could not list Firebase apps."
}

$appsJson = $appsRaw | ConvertFrom-Json
$apps = @()
if ($null -ne $appsJson.result) {
    $apps = @($appsJson.result)
} elseif ($appsJson -is [System.Array]) {
    $apps = @($appsJson)
}

$androidApps = @($apps | Where-Object {
    $_.platform -eq "ANDROID" -or $_.platform -eq "android"
})

if ($androidApps.Count -eq 0) {
    throw "No Android Firebase app was found in project $projectId."
}

if ($androidApps.Count -gt 1) {
    Write-Host "Multiple Android apps found; using the first one:" -ForegroundColor Yellow
}

$app = $androidApps | Select-Object -First 1
$appId = $app.appId
if (-not $appId) {
    throw "Firebase Android app id was not returned."
}

Write-Host "Firebase Android app id: $appId" -ForegroundColor Cyan

$existingRaw = firebase.cmd apps:android:sha:list "$appId" --project "$projectId" --json | Out-String
$alreadyRegistered = $false
if ($LASTEXITCODE -eq 0 -and $existingRaw.Trim()) {
    try {
        $existingJson = $existingRaw | ConvertFrom-Json
        $existing = if ($null -ne $existingJson.result) {
            @($existingJson.result)
        } elseif ($existingJson -is [System.Array]) {
            @($existingJson)
        } else {
            @()
        }

        foreach ($entry in $existing) {
            $hash = $entry.shaHash
            if (-not $hash) { $hash = $entry.sha }
            if ($hash -and (($hash.ToUpper() -replace '[^0-9A-F]', '') -eq $normalizedSha)) {
                $alreadyRegistered = $true
                break
            }
        }
    } catch {
        # Continue and let Firebase reject an exact duplicate if necessary.
    }
}

if ($alreadyRegistered) {
    Write-Host "This SHA-1 is already registered in Firebase." -ForegroundColor Green
} else {
    firebase.cmd apps:android:sha:create "$appId" "$formattedSha" --project "$projectId" | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Firebase could not register the SHA-1."
    }
    Write-Host "SHA-1 registered successfully." -ForegroundColor Green
}

Write-Host ""
Write-Host "Refreshing Firebase Android configuration..." -ForegroundColor Cyan

$pubCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"),
    (Join-Path $env:APPDATA "Pub\Cache\bin")
)
foreach ($candidate in $pubCandidates) {
    if ((Test-Path $candidate) -and (($env:Path -split ';') -notcontains $candidate)) {
        $env:Path = "$candidate;$env:Path"
    }
}

$flutterfire = $null
if (Get-Command flutterfire.bat -ErrorAction SilentlyContinue) {
    $flutterfire = "flutterfire.bat"
} elseif (Get-Command flutterfire -ErrorAction SilentlyContinue) {
    $flutterfire = "flutterfire"
}

if (-not $flutterfire) {
    dart.bat pub global activate flutterfire_cli | Out-Host
    foreach ($candidate in $pubCandidates) {
        if ((Test-Path $candidate) -and (($env:Path -split ';') -notcontains $candidate)) {
            $env:Path = "$candidate;$env:Path"
        }
    }
    if (Get-Command flutterfire.bat -ErrorAction SilentlyContinue) {
        $flutterfire = "flutterfire.bat"
    } elseif (Get-Command flutterfire -ErrorAction SilentlyContinue) {
        $flutterfire = "flutterfire"
    }
}

if (-not $flutterfire) {
    throw "FlutterFire CLI is not available."
}

& $flutterfire configure --project "$projectId" --platforms "android,ios,web" --android-package-name "com.mikron30.keepi" --ios-bundle-id "com.mikron30.keepi" --yes
if ($LASTEXITCODE -ne 0) {
    throw "FlutterFire configuration refresh failed."
}

git restore -- firebase.json 2>$null

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "GOOGLE PLAY SHA-1 REGISTERED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Now rebuild Keepi and upload the next Internal testing bundle." -ForegroundColor Yellow
