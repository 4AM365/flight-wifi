@echo off
REM Double-click after you land to remove all airplane-wifi blocks.
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flight-wifi.ps1" off
echo.
pause
