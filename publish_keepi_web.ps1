param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi")
)

$ErrorActionPreference = "Stop"

function Require-Command([string]$Name, [string]$HelpText) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Host "Missing required command: $Name" -ForegroundColor Red
        Write-Host $HelpText -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Keepi - Publish Web to Firebase Hosting" -ForegroundColor Green

Require-Command "git.exe" "Install Git for Windows."
Require-Command "flutter.bat" "Install Flutter and make sure it is in PATH."
Require-Command "firebase.cmd" "Install Firebase CLI with: npm.cmd install -g firebase-tools"

if (-not (Test-Path $ProjectPath)) {
    throw "Keepi folder not found: $ProjectPath"
}

Set-Location $ProjectPath

Write-Host ""
Write-Host "Updating repository..." -ForegroundColor Cyan
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
Write-Host "Building Flutter Web..." -ForegroundColor Cyan
flutter pub get
flutter build web --release

Write-Host ""
Write-Host "Deploying to Firebase Hosting..." -ForegroundColor Cyan
firebase.cmd deploy --only "hosting" --project "$projectId"
if ($LASTEXITCODE -ne 0) {
    throw "Firebase Hosting deployment failed."
}

$url = "https://$projectId.web.app"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Keepi is live:" -ForegroundColor Green
Write-Host $url -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Green

Start-Process $url
