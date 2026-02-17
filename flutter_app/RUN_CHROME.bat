@echo off
set "PATH=%PATH%;E:\Windows Downloads\flutter_windows_3.38.5-stable\flutter\bin"

echo.
echo Starting STUCHAT in Chrome...
echo.

flutter pub get
flutter run -d chrome --web-port=9090

pause
