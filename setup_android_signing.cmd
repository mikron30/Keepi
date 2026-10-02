@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_android_signing.ps1"
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
  echo Keepi Android signing setup FAILED with exit code %EXITCODE%.
  pause
  exit /b %EXITCODE%
)

echo Keepi Android signing setup completed.
pause
exit /b 0
