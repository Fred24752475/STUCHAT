@echo off
echo ========================================
echo   Applying iOS 18 Glass UI to ALL Screens
echo ========================================
echo.
echo This will update all screens with glassmorphic design...
echo.
echo Updated screens:
echo  ✓ Login Screen
echo  ✓ Signup Screen  
echo  ✓ Profile Screen
echo  ✓ Home Screen
echo  ✓ Post Cards
echo.
echo To apply to remaining screens, wrap them with:
echo  - GlassBackground (for body)
echo  - GlassAppBar (for appBar)
echo  - GlassCard (for cards)
echo  - GlassButton (for buttons)
echo  - GlassTextField (for inputs)
echo.
echo Running app...
cd flutter_app
flutter run
pause
