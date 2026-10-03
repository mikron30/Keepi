@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish_keepi_web.ps1" %*
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
  echo Keepi web publish FAILED with exit code %EXITCODE%.
  pause
  exit /b %EXITCODE%
)

echo Keepi web publish completed successfully.
pause
exit /b 0
