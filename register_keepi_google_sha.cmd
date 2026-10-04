@echo off
setlocal
cd /d "%~dp0"

if "%~1"=="" (
  echo Usage:
  echo   register_keepi_google_sha.cmd XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
  echo.
  pause
  exit /b 2
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0register_keepi_google_sha.ps1" -Sha1 "%~1"
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
  echo Google Play SHA registration FAILED with exit code %EXITCODE%.
  pause
  exit /b %EXITCODE%
)

echo Google Play SHA registration completed.
pause
exit /b 0
