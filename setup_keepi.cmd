@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_keepi.ps1" %*
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
  echo Keepi setup FAILED with exit code %EXITCODE%.
  pause
  exit /b %EXITCODE%
)

echo Keepi setup completed successfully.
pause
exit /b 0
