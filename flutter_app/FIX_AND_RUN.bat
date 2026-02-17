@echo off
set PATH=%PATH%;E:\Windows Downloads\flutter_windows_3.38.5-stable\flutter\bin

echo Cleaning project...
flutter clean

echo Getting dependencies...
flutter pub get

echo Running app in Chrome...
flutter run -d chrome

pause
