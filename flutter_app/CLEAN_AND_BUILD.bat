@echo off
echo ========================================
echo   Clean Build for Live Streaming
echo ========================================
echo.

cd /d "%~dp0"

echo Step 1: Cleaning previous build...
flutter clean
echo.

echo Step 2: Removing cache...
if exist .dart_tool\hooks_runner rmdir /s /q .dart_tool\hooks_runner
echo.

echo Step 3: Getting packages...
flutter pub get
echo.

echo Step 4: Building for web...
flutter build web
echo.

echo ========================================
echo   Build Complete!
echo ========================================
echo.
echo To run the app:
echo   flutter run -d chrome
echo.
pause
