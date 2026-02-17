@echo off
echo ========================================
echo   Fixing Flutter Path Issues
echo ========================================
echo.

echo Cleaning Flutter build cache...
cd /d "%~dp0"
if exist .dart_tool rmdir /s /q .dart_tool
if exist build rmdir /s /q build
echo.

echo Running Flutter clean...
flutter clean
echo.

echo Getting Flutter packages...
flutter pub get
echo.

echo ========================================
echo   Starting Flutter App
echo ========================================
echo.
echo Note: If you still get path errors, consider:
echo 1. Moving Flutter to a path without spaces
echo    Example: C:\flutter instead of "E:\Windows Downloads\flutter"
echo.
echo 2. Or run: flutter run -d chrome
echo.

flutter run -d chrome

pause
