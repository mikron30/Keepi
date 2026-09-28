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

function Require-Command([string]$Name, [string]$HelpText) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Host "Missing required command: $Name" -ForegroundColor Red
        Write-Host $HelpText -ForegroundColor Yellow
        exit 1
    }
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

    throw "Could not find the existing Keepi Firebase Hosting site."
}

Write-Host ""
Write-Host "Keepi - Publish MINIMAL PWA baseline" -ForegroundColor Green

Require-Command "git.exe" "Install Git for Windows."
Require-Command "firebase.cmd" "Install Firebase CLI with: npm.cmd install -g firebase-tools"

if (-not (Test-Path $ProjectPath)) {
    throw "Keepi folder not found: $ProjectPath"
}

Set-Location $ProjectPath

Write-Host ""
Write-Host "Updating repository..." -ForegroundColor Cyan
git restore -- firebase.json 2>$null
git fetch origin
git checkout main
git pull --ff-only origin main
if ($LASTEXITCODE -ne 0) {
    throw "Could not update Keepi from Git."
}

$projectFile = Join-Path $ProjectPath ".keepi-firebase-project"
if (-not (Test-Path $projectFile)) {
    throw "Missing .keepi-firebase-project. Run setup_keepi.ps1 once."
}

$projectId = (Get-Content $projectFile -Raw).Trim()
if (-not $projectId) {
    throw "Firebase project id is empty."
}

if ($projectId -like "matzav*") {
    throw "Safety stop: Keepi will not deploy to Matzav."
}

$minimalPath = Join-Path $ProjectPath "minimal_web"
if (-not (Test-Path (Join-Path $minimalPath "index.html"))) {
    throw "minimal_web\index.html is missing."
}

$siteId = Resolve-HostingSite -ProjectId $projectId -RepoPath $ProjectPath

Write-Host ""
Write-Host "Firebase project: $projectId" -ForegroundColor Green
Write-Host "Hosting site: https://$siteId.web.app" -ForegroundColor Green
Write-Host "Mode: MINIMAL PWA ONLY - Flutter/backend are not being redeployed." -ForegroundColor Yellow

firebase.cmd target:apply hosting "$HostingTarget" "$siteId" --project "$projectId" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Could not configure Firebase Hosting target."
}

$commitId = (git rev-parse --short HEAD).Trim()
$versionText = "Keepi minimal baseline commit: $commitId`nPublished: $(Get-Date -Format o)"
Set-Content -Path (Join-Path $minimalPath "version.txt") -Value $versionText -Encoding ascii

Write-Host ""
Write-Host "Deploying minimal Keepi PWA..." -ForegroundColor Cyan
firebase.cmd deploy --only "hosting:$HostingTarget" --project "$projectId" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Firebase Hosting deployment failed."
}

$url = "https://$siteId.web.app"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Minimal Keepi PWA is live:" -ForegroundColor Green
Write-Host $url -ForegroundColor Yellow
Write-Host "Version: $url/version.txt" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Green

Start-Process "$url/?v=$commitId"
