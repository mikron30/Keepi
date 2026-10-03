@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0diagnose_keepi_android.ps1"
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
  echo Keepi Android diagnostic FAILED with exit code %EXITCODE%.
  pause
  exit /b %EXITCODE%
)

echo.
echo Keepi Android diagnostic completed.
pause
exit /b 0
