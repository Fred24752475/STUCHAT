@echo off
echo ========================================
echo   Testing Backend Connection
echo ========================================
echo.
echo Testing if backend is running on port 3000...
echo.

curl -X GET http://localhost:3000/api/auth/test 2>nul
if %errorlevel% equ 0 (
    echo.
    echo ✅ Backend is running and accessible!
) else (
    echo.
    echo ❌ Cannot connect to backend!
    echo.
    echo Make sure:
    echo 1. Backend server is running (run START_SERVER.bat in backend_node folder)
    echo 2. Server is on port 3000
    echo 3. No firewall blocking the connection
)

echo.
echo Testing with PowerShell...
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://localhost:3000' -TimeoutSec 5; Write-Host '✅ Server responded with status:' $response.StatusCode } catch { Write-Host '❌ Connection failed:' $_.Exception.Message }"

echo.
pause
