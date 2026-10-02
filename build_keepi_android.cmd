@echo off
setlocal
cd /d "%~dp0"

echo.
echo ============================================
echo Keepi Android production build
echo ============================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_keepi_android.ps1"
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
  echo Keepi Android build FAILED with exit code %EXITCODE%.
  echo.
  pause
  exit /b %EXITCODE%
)

echo Keepi Android build completed successfully.
echo.
pause
exit /b 0
