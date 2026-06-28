@echo off
REM Double-click to enter airplane-wifi mode (blocks bandwidth hogs + VPN/torrent ports).
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0flight-wifi.ps1" on
echo.
pause
