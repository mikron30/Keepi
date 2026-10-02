param(
    [string]$ProjectPath = (Join-Path $HOME "Keepi")
)

$ErrorActionPreference = "Stop"
Set-Location $ProjectPath

$keystorePath = Join-Path $ProjectPath "android\app\upload-keystore.jks"
$keyPropertiesPath = Join-Path $ProjectPath "android\key.properties"
$keyAlias = "keepi-upload"

Write-Host ""
Write-Host "Keepi Android upload signing setup" -ForegroundColor Green
Write-Host "This is a one-time setup. Keep the keystore and password backed up safely." -ForegroundColor Yellow
Write-Host ""

if ((Test-Path $keystorePath) -and (Test-Path $keyPropertiesPath)) {
    Write-Host "Signing files already exist. Nothing changed." -ForegroundColor Green
    Write-Host $keystorePath -ForegroundColor Yellow
    exit 0
}

$keytool = $null
if ($env:JAVA_HOME) {
    $candidate = Join-Path $env:JAVA_HOME "bin\keytool.exe"
    if (Test-Path $candidate) { $keytool = $candidate }
}

if (-not $keytool) {
    $cmd = Get-Command keytool.exe -ErrorAction SilentlyContinue
    if ($cmd) { $keytool = $cmd.Source }
}

if (-not $keytool) {
    throw "keytool.exe was not found. Install/use the JDK that comes with Android Studio or set JAVA_HOME."
}

$securePassword = Read-Host "Choose a password for the Keepi upload key" -AsSecureString
$confirmPassword = Read-Host "Enter the same password again" -AsSecureString

$ptr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$ptr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($confirmPassword)
try {
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr1)
    $confirm = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr2)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr1)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr2)
}

if ([string]::IsNullOrWhiteSpace($password)) { throw "Password cannot be empty." }
if ($password -ne $confirm) { throw "Passwords do not match." }
if ($password.Length -lt 6) { throw "Use a password of at least 6 characters." }

New-Item -ItemType Directory -Force -Path (Split-Path $keystorePath) | Out-Null

$keytoolArgs = @(
    "-genkeypair",
    "-v",
    "-keystore", $keystorePath,
    "-storepass", $password,
    "-keypass", $password,
    "-alias", $keyAlias,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-dname", "CN=Keepi Upload, OU=Keepi, O=mikron30, L=Haifa, ST=Haifa, C=IL"
)

& $keytool @keytoolArgs
if ($LASTEXITCODE -ne 0) { throw "keytool failed to create the Keepi upload keystore." }

$properties = @(
    "storePassword=$password",
    "keyPassword=$password",
    "keyAlias=$keyAlias",
    "storeFile=upload-keystore.jks"
)
$properties | Set-Content -Encoding ASCII $keyPropertiesPath

Write-Host ""
Write-Host "Keepi upload signing created successfully." -ForegroundColor Green
Write-Host "Keystore: $keystorePath" -ForegroundColor Yellow
Write-Host "Properties: $keyPropertiesPath" -ForegroundColor Yellow
Write-Host "IMPORTANT: Back up upload-keystore.jks and the password somewhere safe." -ForegroundColor Yellow
