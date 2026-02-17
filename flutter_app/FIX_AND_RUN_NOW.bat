@echo off
echo ========================================
echo   Fixing Flutter Build Issues
echo ========================================
echo.

echo Step 1: Cleaning build cache...
flutter clean
echo.

echo Step 2: Removing problematic cache...
if exist .dart_tool rmdir /s /q .dart_tool
if exist build rmdir /s /q build
echo.

echo Step 3: Getting packages...
flutter pub get
echo.

echo Step 4: Running app...
echo.
echo Starting Flutter app in Chrome...
echo.
flutter run -d chrome --no-sound-null-safety
echo.

pause
