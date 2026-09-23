param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi"),
    [ValidateSet("chrome", "none")]
    [string]$RunTarget = "chrome",
    [switch]$SkipFirebaseDeploy
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$KeepiFirebaseDisplayName = "Keepi"
$KeepiFirebaseProjectCandidates = @(
    "keepi-mikron30-53993027",
    "keepi-mikron30-53993027-app",
    "keepi-mikron30-53993027-prod"
)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor DarkGray
}

function Require-Command([string]$Name, [string]$HelpText) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "Missing required command: $Name" -ForegroundColor Red
        Write-Host $HelpText -ForegroundColor Yellow
        exit 1
    }
}

function Add-PubCacheToPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"),
        (Join-Path $env:APPDATA "Pub\Cache\bin")
    )

    foreach ($path in $candidates) {
        if ((Test-Path $path) -and (($env:Path -split ";") -notcontains $path)) {
            $env:Path = "$path;$env:Path"
        }
    }
}

function Get-FirebaseProjects {
    $raw = firebase.cmd projects:list --json | Out-String
    $json = $raw | ConvertFrom-Json

    if ($null -ne $json.result) {
        return @($json.result)
    }

    if ($json -is [System.Array]) {
        return @($json)
    }

    return @()
}

function Resolve-KeepiFirebaseProject {
    param([string]$RepoPath)

    $localProjectFile = Join-Path $RepoPath ".keepi-firebase-project"

    if (Test-Path $localProjectFile) {
        $saved = (Get-Content $localProjectFile -Raw).Trim()
        if ($saved) {
            $projects = Get-FirebaseProjects
            $match = $projects | Where-Object { $_.projectId -eq $saved } | Select-Object -First 1
            if ($match) {
                Write-Host "Using saved Keepi Firebase project: $saved" -ForegroundColor Green
                return $saved
            }

            Write-Host "Saved Firebase project '$saved' is not available to this account. Re-resolving..." -ForegroundColor Yellow
        }
    }

    $projects = Get-FirebaseProjects

    foreach ($candidate in $KeepiFirebaseProjectCandidates) {
        $match = $projects | Where-Object { $_.projectId -eq $candidate } | Select-Object -First 1
        if ($match) {
            Set-Content -Path $localProjectFile -Value $candidate -Encoding ascii
            Write-Host "Found dedicated Keepi Firebase project: $candidate" -ForegroundColor Green
            return $candidate
        }
    }

    $displayMatch = $projects |
        Where-Object { $_.displayName -eq $KeepiFirebaseDisplayName -and $_.projectId -like "keepi*" } |
        Select-Object -First 1

    if ($displayMatch) {
        $id = $displayMatch.projectId
        Set-Content -Path $localProjectFile -Value $id -Encoding ascii
        Write-Host "Found existing Keepi Firebase project: $id" -ForegroundColor Green
        return $id
    }

    Write-Host "No dedicated Keepi Firebase project exists yet." -ForegroundColor Yellow
    Write-Host "Creating one now. Matzav will NOT be used." -ForegroundColor Yellow

    foreach ($candidate in $KeepiFirebaseProjectCandidates) {
        Write-Host "Trying Firebase project id: $candidate"

        try {
            firebase.cmd projects:create $candidate --display-name $KeepiFirebaseDisplayName
            Set-Content -Path $localProjectFile -Value $candidate -Encoding ascii
            Write-Host "Created dedicated Keepi Firebase project: $candidate" -ForegroundColor Green
            return $candidate
        }
        catch {
            Write-Host "Could not create '$candidate'; trying the next dedicated Keepi id..." -ForegroundColor Yellow
        }
    }

    throw "Could not create a dedicated Firebase project for Keepi. No Matzav project was modified by this script."
}

Write-Host ""
Write-Host "KEEPi - Windows one-shot setup" -ForegroundColor Green
Write-Host "Project path: $ProjectPath"

Write-Step "1/10 - Checking prerequisites"
Require-Command "git.exe" "Install Git for Windows, then run this script again."
Require-Command "flutter.bat" "Install Flutter and make sure Flutter is in PATH."
Require-Command "dart.bat" "Dart should come with Flutter. Run 'flutter doctor' if it is missing."

if (-not (Get-Command "npm.cmd" -ErrorAction SilentlyContinue)) {
    Write-Host "npm was not found." -ForegroundColor Yellow
    Write-Host "Firebase CLI needs Node.js/npm. Install Node.js LTS, then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "Git:     $(git --version)"
Write-Host "Flutter: $(flutter --version | Select-Object -First 1)"
Write-Host "Dart:    $(dart.bat --version 2>&1)"

Write-Step "2/10 - Installing/updating Firebase CLI"
if (-not (Get-Command "firebase.cmd" -ErrorAction SilentlyContinue)) {
    npm.cmd install -g firebase-tools
} else {
    Write-Host "Firebase CLI already installed: $(firebase.cmd --version)"
}

Write-Step "3/10 - Getting the latest Keepi repository"
if (Test-Path $ProjectPath) {
    if (-not (Test-Path (Join-Path $ProjectPath ".git"))) {
        Write-Host "The folder already exists but is not a Git repository:" -ForegroundColor Red
        Write-Host $ProjectPath -ForegroundColor Red
        exit 1
    }

    Push-Location $ProjectPath
    try {
        $remote = git remote get-url origin 2>$null
        if ($remote -notmatch "mikron30/Keepi") {
            Write-Host "Existing repository has a different origin: $remote" -ForegroundColor Red
            exit 1
        }

        git fetch origin
        git checkout main
        git pull --ff-only origin main
    }
    finally {
        Pop-Location
    }
} else {
    git clone https://github.com/mikron30/Keepi.git $ProjectPath
}

Set-Location $ProjectPath

Write-Step "4/10 - Flutter dependencies"
flutter pub get

Write-Step "5/10 - Firebase login"
Write-Host "A browser may open only if Firebase needs you to sign in." -ForegroundColor Yellow
firebase.cmd login

Write-Step "6/10 - Installing FlutterFire CLI"
dart.bat pub global activate flutterfire_cli
Add-PubCacheToPath

$flutterfireCommand = $null
if (Get-Command "flutterfire.bat" -ErrorAction SilentlyContinue) {
    $flutterfireCommand = "flutterfire.bat"
} elseif (Get-Command "flutterfire" -ErrorAction SilentlyContinue) {
    $flutterfireCommand = "flutterfire"
}

if (-not $flutterfireCommand) {
    Write-Host "FlutterFire was installed but is not visible in PATH for this process." -ForegroundColor Red
    Write-Host "Expected Pub Cache under LOCALAPPDATA or APPDATA." -ForegroundColor Yellow
    exit 1
}

Write-Step "7/10 - Creating/selecting a dedicated Keepi Firebase project"
$projectId = Resolve-KeepiFirebaseProject -RepoPath $ProjectPath

if ($projectId -like "matzav*") {
    throw "Safety stop: resolved Firebase project '$projectId' looks like Matzav. Keepi will not use it."
}

Write-Host ""
Write-Host "KEEPi Firebase project: $projectId" -ForegroundColor Green
Write-Host "Matzav Firebase project will not be used." -ForegroundColor Green

Write-Step "8/10 - Configuring Firebase for Keepi only"
Write-Host "Registering Android, iOS and Web apps inside: $projectId" -ForegroundColor Cyan
& $flutterfireCommand configure --project=$projectId --platforms=android,ios,web --yes

Write-Step "9/10 - Analyze and test"
flutter analyze
flutter test

Write-Step "10/10 - Firebase rules"
if (-not $SkipFirebaseDeploy) {
    try {
        firebase.cmd deploy --only firestore:rules,storage --project $projectId
        Write-Host "Firebase rules deployed." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "Firebase app configuration is complete, but rules deployment was skipped/failed." -ForegroundColor Yellow
        Write-Host "This is normal if Firestore or Cloud Storage has not been enabled yet." -ForegroundColor Yellow
        Write-Host "Keepi is still configured against its own Firebase project: $projectId" -ForegroundColor Yellow
    }
} else {
    Write-Host "Firebase rules deployment skipped by command-line option."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Keepi setup completed." -ForegroundColor Green
Write-Host "Folder:           $ProjectPath"
Write-Host "Firebase project: $projectId"
Write-Host "============================================================" -ForegroundColor Green

if (Get-Command "code.cmd" -ErrorAction SilentlyContinue) {
    Write-Host "Opening Keepi in VS Code..."
    code.cmd $ProjectPath
}

if ($RunTarget -eq "chrome") {
    Write-Host ""
    Write-Host "Starting Keepi in Chrome. Press q in this window to stop Flutter." -ForegroundColor Cyan
    flutter run -d chrome
} else {
    Write-Host ""
    Write-Host "Run later with: flutter run -d chrome" -ForegroundColor Cyan
}
