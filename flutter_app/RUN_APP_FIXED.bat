@echo off
echo ========================================
echo   Running STUCHAT with Live Streaming
echo ========================================
echo.

echo Cleaning previous build...
flutter clean > nul 2>&1
echo.

echo Getting packages...
flutter pub get
echo.

echo ========================================
echo   Starting App...
echo ========================================
echo.
echo The app will open in Chrome.
echo Look for the videocam icon (top right)!
echo.

flutter run -d chrome --no-sound-null-safety

pause
