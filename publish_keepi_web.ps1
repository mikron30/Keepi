param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi")
)

$ErrorActionPreference = "Stop"

$HostingTarget = "keepi-site"
$HostingCandidates = @(
    "keepi",
    "keepiapp",
    "getkeepi",
    "keepiweb",
    "mykeepi",
    "keepiglobal"
)

function Get-WebFirebaseDartDefines([string]$RepoPath) {
    $optionsPath = Join-Path $RepoPath "lib\firebase_options.dart"

    if (-not (Test-Path $optionsPath)) {
        throw "Missing lib\firebase_options.dart. Run setup_keepi.ps1 first."
    }

    $content = Get-Content $optionsPath -Raw
    $webMatch = [regex]::Match(
        $content,
        "static const FirebaseOptions web = FirebaseOptions\((?<body>.*?)\n\s*\);",
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    if (-not $webMatch.Success) {
        throw "Could not read the Firebase Web configuration from lib\firebase_options.dart."
    }

    $body = $webMatch.Groups["body"].Value
    $mapping = [ordered]@{
        "apiKey" = "FIREBASE_API_KEY"
        "appId" = "FIREBASE_APP_ID"
        "messagingSenderId" = "FIREBASE_MESSAGING_SENDER_ID"
        "projectId" = "FIREBASE_PROJECT_ID"
        "authDomain" = "FIREBASE_AUTH_DOMAIN"
        "storageBucket" = "FIREBASE_STORAGE_BUCKET"
        "measurementId" = "FIREBASE_MEASUREMENT_ID"
    }

    $arguments = @()

    foreach ($entry in $mapping.GetEnumerator()) {
        $pattern = $entry.Key + "\s*:\s*'([^']*)'"
        $match = [regex]::Match($body, $pattern)

        if ($match.Success -and $match.Groups[1].Value) {
            $arguments += "--dart-define=$($entry.Value)=$($match.Groups[1].Value)"
        }
    }

    if (-not ($arguments | Where-Object { $_ -like "--dart-define=FIREBASE_API_KEY=*" })) {
        throw "Firebase Web apiKey was not found."
    }

    return $arguments
}

function Require-Command([string]$Name, [string]$HelpText) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Host "Missing required command: $Name" -ForegroundColor Red
        Write-Host $HelpText -ForegroundColor Yellow
        exit 1
    }
}

function Deploy-FunctionsWithRetry([string]$ProjectId) {
    $maxAttempts = 3

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-Host "Deploying Cloud Functions (attempt $attempt of $maxAttempts)..." -ForegroundColor Cyan
        firebase.cmd deploy --only "functions" --project "$ProjectId" | Out-Host

        if ($LASTEXITCODE -eq 0) {
            return
        }

        if ($attempt -lt $maxAttempts) {
            $waitSeconds = 20 * $attempt
            Write-Host ""
            Write-Host "Functions deployment failed. Google Cloud APIs may still be propagating." -ForegroundColor Yellow
            Write-Host "Waiting $waitSeconds seconds and retrying..." -ForegroundColor Yellow
            Start-Sleep -Seconds $waitSeconds
        }
    }

    throw "Firebase Functions deployment failed after $maxAttempts attempts."
}

function Get-ExistingHostingSites([string]$ProjectId) {
    $raw = firebase.cmd hosting:sites:list --project "$ProjectId" --json | Out-String
    if ($LASTEXITCODE -ne 0) {
        return @()
    }

    try {
        $json = $raw | ConvertFrom-Json

        if ($null -ne $json.result -and $null -ne $json.result.sites) {
            return @($json.result.sites)
        }

        if ($null -ne $json.result -and $json.result -is [System.Array]) {
            return @($json.result)
        }

        return @()
    }
    catch {
        return @()
    }
}

function Resolve-HostingSite([string]$ProjectId, [string]$RepoPath) {
    $siteFile = Join-Path $RepoPath ".keepi-hosting-site"

    if (Test-Path $siteFile) {
        $saved = (Get-Content $siteFile -Raw).Trim()
        if ($saved) {
            Write-Host "Using saved Keepi Hosting site: $saved" -ForegroundColor Green
            return $saved
        }
    }

    $existingSites = Get-ExistingHostingSites -ProjectId $ProjectId

    foreach ($candidate in $HostingCandidates) {
        $found = $existingSites | Where-Object {
            $_.name -eq $candidate -or
            $_.site -eq $candidate -or
            $_.siteId -eq $candidate
        } | Select-Object -First 1

        if ($found) {
            Set-Content -Path $siteFile -Value $candidate -Encoding ascii
            Write-Host "Using existing Keepi Hosting site: $candidate" -ForegroundColor Green
            return $candidate
        }
    }

    foreach ($candidate in $HostingCandidates) {
        Write-Host "Trying Hosting address: https://$candidate.web.app" -ForegroundColor Cyan

        firebase.cmd hosting:sites:create "$candidate" --project "$ProjectId" | Out-Host
        if ($LASTEXITCODE -eq 0) {
            Set-Content -Path $siteFile -Value $candidate -Encoding ascii
            Write-Host "Reserved: https://$candidate.web.app" -ForegroundColor Green
            return $candidate
        }

        Write-Host "'$candidate' is unavailable. Trying the next name..." -ForegroundColor Yellow
    }

    throw "Could not reserve any of the short Keepi Hosting names. Add another candidate to publish_keepi_web.ps1."
}

Write-Host ""
Write-Host "Keepi - Publish Web to Firebase Hosting" -ForegroundColor Green

Require-Command "git.exe" "Install Git for Windows."
Require-Command "flutter.bat" "Install Flutter and make sure it is in PATH."
Require-Command "firebase.cmd" "Install Firebase CLI with: npm.cmd install -g firebase-tools"
Require-Command "npm.cmd" "Install Node.js/npm before deploying Keepi Cloud Functions."

if (-not (Test-Path $ProjectPath)) {
    throw "Keepi folder not found: $ProjectPath"
}

Set-Location $ProjectPath

Write-Host ""
Write-Host "Updating repository..." -ForegroundColor Cyan
Write-Host "Discarding generated firebase.json changes before pull..." -ForegroundColor DarkGray
git restore -- firebase.json 2>$null
git fetch origin
git checkout main
git pull --ff-only origin main

$projectFile = Join-Path $ProjectPath ".keepi-firebase-project"
if (-not (Test-Path $projectFile)) {
    throw "Missing .keepi-firebase-project. Run setup_keepi.ps1 first."
}

$projectId = (Get-Content $projectFile -Raw).Trim()
if (-not $projectId) {
    throw "Firebase project id is empty."
}

if ($projectId -like "matzav*") {
    throw "Safety stop: Keepi will not deploy to Matzav."
}

Write-Host "Firebase project: $projectId" -ForegroundColor Green

Write-Host ""
Write-Host "Finding the shortest available international Keepi address..." -ForegroundColor Cyan
$siteId = Resolve-HostingSite -ProjectId $projectId -RepoPath $ProjectPath

Write-Host ""
Write-Host "Connecting Firebase Hosting target '$HostingTarget' to '$siteId'..." -ForegroundColor Cyan
firebase.cmd target:apply hosting "$HostingTarget" "$siteId" --project "$projectId" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Could not configure Firebase Hosting target."
}

Write-Host ""
$commitId = (git rev-parse --short HEAD).Trim()
Write-Host "Building Keepi commit: $commitId" -ForegroundColor Green
Write-Host "Building Flutter Web with the Keepi Firebase configuration..." -ForegroundColor Cyan
$firebaseDefines = Get-WebFirebaseDartDefines -RepoPath $ProjectPath
flutter clean
flutter pub get
flutter build web --release @firebaseDefines
if ($LASTEXITCODE -ne 0) {
    throw "Flutter Web build failed."
}

$versionText = "Keepi commit: $commitId`nPublished: $(Get-Date -Format o)"
Set-Content -Path (Join-Path $ProjectPath "build\web\keepi-version.txt") -Value $versionText -Encoding ascii

Write-Host ""
Write-Host "Checking Keepi Cloud Function syntax..." -ForegroundColor Cyan
Push-Location (Join-Path $ProjectPath "functions")
npm.cmd install | Out-Host
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    throw "Cloud Functions npm install failed."
}
npm.cmd run check | Out-Host
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    throw "Cloud Functions syntax check failed."
}
Pop-Location

Write-Host ""
Write-Host "Deploying Firebase rules..." -ForegroundColor Cyan
firebase.cmd deploy --only "firestore:rules,storage" --project "$projectId" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Firebase Firestore/Storage rules deployment failed."
}

Write-Host ""
Deploy-FunctionsWithRetry -ProjectId $projectId

Write-Host ""
Write-Host "Deploying to Firebase Hosting..." -ForegroundColor Cyan
firebase.cmd deploy --only "hosting:$HostingTarget" --project "$projectId" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Firebase Hosting deployment failed."
}

$url = "https://$siteId.web.app"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Keepi is live:" -ForegroundColor Green
Write-Host $url -ForegroundColor Yellow
Write-Host "Version check: $url/keepi-version.txt" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Green

Start-Process "$url/?v=$commitId"
