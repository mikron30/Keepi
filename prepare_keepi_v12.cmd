@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0prepare_keepi_v12.ps1"
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
  echo Keepi Version 12 preparation FAILED with exit code %EXITCODE%.
  pause
  exit /b %EXITCODE%
)

echo Keepi Version 12 is ready for Google Play Internal testing.
pause
exit /b 0
