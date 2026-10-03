@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_keepi_android_clean.ps1"
set EXITCODE=%ERRORLEVEL%
echo.
if not "%EXITCODE%"=="0" (
  echo Keepi verified build FAILED with exit code %EXITCODE%.
  pause
  exit /b %EXITCODE%
)
echo Keepi verified build completed successfully.
pause
exit /b 0
