param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi"),
    [ValidateSet("chrome", "none")]
    [string]$RunTarget = "chrome",
    [switch]$SkipFirebaseDeploy
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

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

Write-Host ""
Write-Host "KEEPi - Windows one-shot setup" -ForegroundColor Green
Write-Host "Project path: $ProjectPath"

Write-Step "1/9 - Checking prerequisites"
Require-Command "git.exe" "Install Git for Windows, then run this script again."
Require-Command "flutter.bat" "Install Flutter and make sure flutter is in PATH."
Require-Command "dart.bat" "Dart should come with Flutter. Run 'flutter doctor' if it is missing."

if (-not (Get-Command "npm.cmd" -ErrorAction SilentlyContinue)) {
    Write-Host "npm was not found." -ForegroundColor Yellow
    Write-Host "Firebase CLI needs Node.js/npm. Install Node.js LTS, then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "Git:     $(git --version)"
Write-Host "Flutter: $(flutter --version | Select-Object -First 1)"
Write-Host "Dart:    $(dart.bat --version 2>&1)"

Write-Step "2/9 - Installing/updating Firebase CLI"
if (-not (Get-Command "firebase.cmd" -ErrorAction SilentlyContinue)) {
    npm.cmd install -g firebase-tools
} else {
    Write-Host "Firebase CLI already installed: $(firebase.cmd --version)"
}

Write-Step "3/9 - Getting the Keepi repository"
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

Write-Step "4/9 - Flutter dependencies"
flutter pub get

Write-Step "5/9 - Firebase login"
Write-Host "A browser window may open. Complete the Google/Firebase sign-in there." -ForegroundColor Yellow
firebase.cmd login

Write-Step "6/9 - Installing FlutterFire CLI"
dart.bat pub global activate flutterfire_cli
Add-PubCacheToPath

if (-not (Get-Command "flutterfire.bat" -ErrorAction SilentlyContinue) -and
    -not (Get-Command "flutterfire" -ErrorAction SilentlyContinue)) {
    Write-Host "FlutterFire was installed but is not visible in PATH for this process." -ForegroundColor Red
    Write-Host "Expected Pub Cache under LOCALAPPDATA or APPDATA." -ForegroundColor Yellow
    exit 1
}

Write-Step "7/9 - Configuring Firebase for Android, iOS and Web"
Write-Host "Choose the Firebase project for Keepi when prompted." -ForegroundColor Yellow
flutterfire configure --platforms=android,ios,web

Write-Step "8/9 - Analyze and test"
flutter analyze
flutter test

if (-not $SkipFirebaseDeploy) {
    Write-Step "9/9 - Deploying Firestore and Storage rules"

    $firebaseOptions = Join-Path $ProjectPath "lib\firebase_options.dart"
    $projectId = $null

    if (Test-Path $firebaseOptions) {
        $match = Select-String -Path $firebaseOptions -Pattern "projectId:\s*'([^']+)'" | Select-Object -First 1
        if ($match -and $match.Matches.Count -gt 0) {
            $projectId = $match.Matches[0].Groups[1].Value
        }
    }

    if ($projectId) {
        Write-Host "Firebase project: $projectId"

        try {
            firebase.cmd deploy --only firestore:rules,storage --project $projectId
        }
        catch {
            Write-Host ""
            Write-Host "Firebase rule deployment did not complete." -ForegroundColor Yellow
            Write-Host "This usually means Firestore or Storage is not enabled yet in Firebase Console," -ForegroundColor Yellow
            Write-Host "or Storage requires a billing-enabled project. The local app setup is still complete." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Could not read projectId from lib/firebase_options.dart; skipping rule deployment." -ForegroundColor Yellow
    }
} else {
    Write-Step "9/9 - Firebase deployment skipped"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Keepi setup completed." -ForegroundColor Green
Write-Host "Folder: $ProjectPath"
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
