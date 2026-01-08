#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Notify Uninstaller for Windows
.DESCRIPTION
    Removes notification hooks from Claude Code on Windows
.PARAMETER Force
    Skip confirmation prompts
.EXAMPLE
    .\uninstall.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Installation directories
$ConfigDir = Join-Path $env:APPDATA "claude-notify"
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$ClaudeSettings = Join-Path $ClaudeDir "settings.json"
$IconDir = Join-Path $env:LOCALAPPDATA "claude-notify"

# Logging functions
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Remove hooks from Claude Code settings
function Remove-ClaudeHooks {
    Write-Info "Removing hooks from Claude Code settings..."

    if (-not (Test-Path $ClaudeSettings)) {
        Write-Warning "Claude Code settings not found, skipping hook removal"
        return
    }

    # Backup settings
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = "$ClaudeSettings.backup.$timestamp"
    Copy-Item $ClaudeSettings $backup
    Write-Info "Backed up settings to $backup"

    # Read current settings
    $settings = Get-Content $ClaudeSettings -Raw | ConvertFrom-Json

    $removedNotification = $false
    $removedStop = $false

    # Check and remove Notification hook if it's ours
    if ($settings.hooks -and $settings.hooks.Notification) {
        $hookCmd = $settings.hooks.Notification[0].hooks[0].command
        if ($hookCmd -match "claude-notify") {
            $settings.hooks.PSObject.Properties.Remove("Notification")
            $removedNotification = $true
            Write-Success "Removed Notification hook"
        } else {
            Write-Warning "Notification hook exists but doesn't appear to be from Claude Notify, leaving it"
        }
    }

    # Check and remove Stop hook if it's ours
    if ($settings.hooks -and $settings.hooks.Stop) {
        $hookCmd = $settings.hooks.Stop[0].hooks[0].command
        if ($hookCmd -match "claude-notify") {
            $settings.hooks.PSObject.Properties.Remove("Stop")
            $removedStop = $true
            Write-Success "Removed Stop hook"
        } else {
            Write-Warning "Stop hook exists but doesn't appear to be from Claude Notify, leaving it"
        }
    }

    # Clean up empty hooks object
    if ($settings.hooks -and ($settings.hooks.PSObject.Properties | Measure-Object).Count -eq 0) {
        $settings.PSObject.Properties.Remove("hooks")
    }

    # Write updated settings
    $settings | ConvertTo-Json -Depth 10 | Set-Content $ClaudeSettings

    if ($removedNotification -or $removedStop) {
        Write-Success "Claude Code hooks cleaned up"
    } else {
        Write-Info "No Claude Notify hooks found to remove"
    }
}

# Remove configuration files
function Remove-Config {
    if (-not (Test-Path $ConfigDir)) {
        Write-Info "Configuration directory not found, nothing to remove"
        return
    }

    if (-not $Force) {
        Write-Host ""
        $response = Read-Host "Remove configuration files at $ConfigDir? [y/N]"
        if ($response -notmatch '^[Yy]') {
            Write-Info "Keeping configuration files"
            return
        }
    }

    Remove-Item -Path $ConfigDir -Recurse -Force
    Write-Success "Configuration directory removed"
}

# Remove icon directory
function Remove-Icons {
    if (-not (Test-Path $IconDir)) {
        return
    }

    if (-not $Force) {
        Write-Host ""
        $response = Read-Host "Remove icon directory at $IconDir? [y/N]"
        if ($response -notmatch '^[Yy]') {
            Write-Info "Keeping icon directory"
            return
        }
    }

    Remove-Item -Path $IconDir -Recurse -Force
    Write-Success "Icon directory removed"
}

# Print summary
function Write-Summary {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Claude Notify uninstalled" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Claude Code will no longer send notifications."
    Write-Host ""
    Write-Host "To reinstall, run: .\install.ps1"
    Write-Host ""
}

# Main
function Main {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Blue
    Write-Host "  Claude Notify Uninstaller (Windows)" -ForegroundColor Blue
    Write-Host "======================================" -ForegroundColor Blue
    Write-Host ""

    if (-not $Force) {
        $response = Read-Host "Are you sure you want to uninstall Claude Notify? [y/N]"
        if ($response -notmatch '^[Yy]') {
            Write-Info "Uninstallation cancelled"
            exit 0
        }
    }

    Remove-ClaudeHooks
    Remove-Config
    Remove-Icons
    Write-Summary
}

Main
