@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0register_keepi_play_signing.ps1"
set EXITCODE=%ERRORLEVEL%
echo.
if not "%EXITCODE%"=="0" (
  echo Keepi Play signing registration FAILED with exit code %EXITCODE%.
  pause
  exit /b %EXITCODE%
)
echo Keepi Play signing fingerprints registered.
pause
exit /b 0
