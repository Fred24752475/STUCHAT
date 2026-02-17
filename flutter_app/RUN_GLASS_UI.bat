@echo off
echo ========================================
echo   iOS 18 Glassmorphic UI - STUCHAT
echo ========================================
echo.
echo Installing dependencies...
call flutter pub get
echo.
echo Cleaning build...
call flutter clean
echo.
echo Starting app with Glass UI...
echo.
call flutter run
pause
