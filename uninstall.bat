@echo off
:: Claude Notify Uninstaller - Windows Batch Wrapper
:: This script launches the PowerShell uninstaller

echo.
echo ======================================
echo   Claude Notify Uninstaller
echo ======================================
echo.

:: Check for PowerShell
where powershell >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: PowerShell is required but not found.
    pause
    exit /b 1
)

:: Get script directory
set "SCRIPT_DIR=%~dp0"

:: Run PowerShell uninstaller
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_DIR%uninstall.ps1" %*

:: Check result
if %ERRORLEVEL% neq 0 (
    echo.
    echo Uninstallation failed with error code %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

pause
