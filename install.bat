@echo off
:: Claude Notify Installer - Windows Batch Wrapper
:: This script launches the PowerShell installer

echo.
echo ======================================
echo   Claude Notify Installer
echo ======================================
echo.

:: Check for PowerShell
where powershell >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: PowerShell is required but not found.
    echo Please install PowerShell 5.1 or later.
    pause
    exit /b 1
)

:: Get script directory
set "SCRIPT_DIR=%~dp0"

:: Run PowerShell installer
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_DIR%install.ps1" %*

:: Check result
if %ERRORLEVEL% neq 0 (
    echo.
    echo Installation failed with error code %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)

pause
