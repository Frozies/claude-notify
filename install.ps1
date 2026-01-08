#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Notify Installer for Windows
.DESCRIPTION
    Installs notification hooks for Claude Code on Windows
.PARAMETER DryRun
    Show what would be done without making changes
.PARAMETER Force
    Skip confirmation prompts
.EXAMPLE
    .\install.ps1
.EXAMPLE
    .\install.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [Parameter()]
    [Alias('n')]
    [switch]$DryRun,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Installation directories
$ConfigDir = Join-Path $env:APPDATA "claude-notify"
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$ClaudeSettings = Join-Path $ClaudeDir "settings.json"
$IconDir = Join-Path $env:LOCALAPPDATA "claude-notify\icons"
$VersionFile = Join-Path $ConfigDir ".version"

# Get repo version
function Get-RepoVersion {
    $versionPath = Join-Path $ScriptDir "VERSION"
    if (Test-Path $versionPath) {
        return (Get-Content $versionPath -Raw).Trim()
    }
    return "0.0.0"
}

# Get installed version
function Get-InstalledVersion {
    if (Test-Path $VersionFile) {
        return (Get-Content $VersionFile -Raw).Trim()
    }
    return $null
}

# Compare versions (returns: 0=equal, 1=first greater, -1=second greater)
function Compare-Versions {
    param([string]$v1, [string]$v2)

    $parts1 = $v1.Split('.')
    $parts2 = $v2.Split('.')

    for ($i = 0; $i -lt 3; $i++) {
        $p1 = if ($i -lt $parts1.Count) { [int]$parts1[$i] } else { 0 }
        $p2 = if ($i -lt $parts2.Count) { [int]$parts2[$i] } else { 0 }

        if ($p1 -gt $p2) { return 1 }
        if ($p1 -lt $p2) { return -1 }
    }
    return 0
}

# Logging functions
function Write-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-DryRun { param([string]$Message) Write-Host "[DRY-RUN] Would: $Message" -ForegroundColor Yellow }

# Check dependencies
function Test-Dependencies {
    Write-Info "Checking dependencies..."

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Err "PowerShell 5.1 or later is required"
        exit 1
    }

    # Check for BurntToast (optional)
    if (Get-Module -ListAvailable -Name BurntToast) {
        Write-Success "BurntToast module found (rich notifications available)"
    } else {
        Write-Warning "BurntToast module not found. Install for richer notifications:"
        Write-Host "  Install-Module -Name BurntToast -Scope CurrentUser"
    }

    Write-Success "Dependencies check completed"
}

# Check Claude Code installation
function Test-ClaudeCode {
    Write-Info "Checking Claude Code installation..."

    if (-not (Test-Path $ClaudeDir)) {
        Write-Err "Claude Code configuration directory not found at $ClaudeDir"
        Write-Host "Please ensure Claude Code is installed and has been run at least once."
        exit 1
    }

    if (-not (Test-Path $ClaudeSettings)) {
        Write-Warning "Claude Code settings.json not found, will create it"
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
            '{}' | Set-Content $ClaudeSettings
        } else {
            Write-DryRun "Create $ClaudeSettings with empty object"
        }
    }

    Write-Success "Claude Code installation found"
}

# Check for upgrade
function Test-Upgrade {
    $repoVersion = Get-RepoVersion
    $installedVersion = Get-InstalledVersion

    if (-not $installedVersion) {
        Write-Info "Fresh installation of Claude Notify v$repoVersion"
        return
    }

    $comparison = Compare-Versions $repoVersion $installedVersion

    switch ($comparison) {
        0 {
            Write-Info "Claude Notify v$installedVersion is already installed (same version)"
            if (-not $Force -and -not $DryRun) {
                $response = Read-Host "Reinstall? [y/N]"
                if ($response -notmatch '^[Yy]') {
                    Write-Info "Installation cancelled"
                    exit 0
                }
            }
        }
        1 {
            Write-Success "Upgrading Claude Notify: v$installedVersion -> v$repoVersion"
        }
        -1 {
            Write-Warning "Installed version (v$installedVersion) is newer than repo (v$repoVersion)"
            if (-not $Force -and -not $DryRun) {
                $response = Read-Host "Downgrade? [y/N]"
                if ($response -notmatch '^[Yy]') {
                    Write-Info "Installation cancelled"
                    exit 0
                }
            }
        }
    }
}

# Backup settings
function Backup-Settings {
    if (Test-Path $ClaudeSettings) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backup = "$ClaudeSettings.backup.$timestamp"
        if ($DryRun) {
            Write-DryRun "Copy $ClaudeSettings to $backup"
        } else {
            Copy-Item $ClaudeSettings $backup
        }
        Write-Info "Backed up settings to $backup"
    }
}

# Create directories
function New-Directories {
    Write-Info "Creating directories..."

    $dirs = @(
        (Join-Path $ConfigDir "hooks"),
        $IconDir
    )

    foreach ($dir in $dirs) {
        if ($DryRun) {
            Write-DryRun "New-Item -ItemType Directory -Path $dir"
        } else {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }

    Write-Success "Directories created"
}

# Install hooks
function Install-Hooks {
    Write-Info "Installing hook scripts..."

    $source = Join-Path $ScriptDir "hooks\notify.ps1"
    $dest = Join-Path $ConfigDir "hooks\notify.ps1"

    if ($DryRun) {
        Write-DryRun "Copy $source to $dest"
    } else {
        Copy-Item $source $dest -Force
    }

    Write-Success "Hook scripts installed to $ConfigDir\hooks\"
}

# Install configuration
function Install-Config {
    Write-Info "Installing configuration..."

    $configDest = Join-Path $ConfigDir "config.json"

    if (-not (Test-Path $configDest) -or $DryRun) {
        $source = Join-Path $ScriptDir "config\config.example.json"
        if ($DryRun) {
            if (-not (Test-Path $configDest)) {
                Write-DryRun "Copy $source to $configDest"
                Write-Success "Configuration installed to $configDest"
            } else {
                Write-Info "Configuration already exists, skipping"
            }
        } else {
            if (-not (Test-Path $configDest)) {
                Copy-Item $source $configDest
                Write-Success "Configuration installed to $configDest"
            } else {
                Write-Info "Configuration already exists, skipping"
            }
        }
    } else {
        Write-Info "Configuration already exists, skipping"
    }
}

# Install icon
function Install-Icon {
    Write-Info "Setting up notification icon..."

    # Check for existing icon
    $existingIcon = Join-Path $IconDir "claude-ai.png"
    if (Test-Path $existingIcon) {
        Write-Success "Using existing Claude icon at $existingIcon"
        return
    }

    # Check for icon in repo
    $sourceIcon = Join-Path $ScriptDir "icons\claude-ai.png"
    if (Test-Path $sourceIcon) {
        if ($DryRun) {
            Write-DryRun "Copy $sourceIcon to $IconDir\"
        } else {
            Copy-Item $sourceIcon $IconDir -Force
        }
        Write-Success "Icon installed to $IconDir\claude-ai.png"
    } else {
        Write-Warning "No icon found. Notifications will use system default icon."
        Write-Info "You can add a custom icon later at $IconDir\claude-ai.png"
    }
}

# Configure Claude Code hooks
function Set-ClaudeHooks {
    Write-Info "Configuring Claude Code hooks..."

    $notifyCmd = "powershell.exe -ExecutionPolicy Bypass -File `"$ConfigDir\hooks\notify.ps1`" -Type input"
    $stopCmd = "powershell.exe -ExecutionPolicy Bypass -File `"$ConfigDir\hooks\notify.ps1`" -Type complete"

    # Read current settings
    $settings = Get-Content $ClaudeSettings -Raw | ConvertFrom-Json

    # Initialize hooks if not present
    if (-not $settings.hooks) {
        $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue @{} -Force
    }

    # Check for existing hooks (skip prompts in dry-run mode)
    if (-not $DryRun -and -not $Force) {
        if ($settings.hooks.Notification) {
            Write-Warning "Notification hook already exists in Claude Code settings"
            $response = Read-Host "Overwrite existing Notification hook? [y/N]"
            if ($response -notmatch '^[Yy]') {
                Write-Info "Keeping existing Notification hook"
                $notifyCmd = $null
            }
        }

        if ($settings.hooks.Stop) {
            Write-Warning "Stop hook already exists in Claude Code settings"
            $response = Read-Host "Overwrite existing Stop hook? [y/N]"
            if ($response -notmatch '^[Yy]') {
                Write-Info "Keeping existing Stop hook"
                $stopCmd = $null
            }
        }
    }

    # Build hook configuration
    if ($notifyCmd) {
        $settings.hooks | Add-Member -NotePropertyName "Notification" -NotePropertyValue @(
            @{
                matcher = ""
                hooks = @(
                    @{
                        type = "command"
                        command = $notifyCmd
                    }
                )
            }
        ) -Force
    }

    if ($stopCmd) {
        $settings.hooks | Add-Member -NotePropertyName "Stop" -NotePropertyValue @(
            @{
                matcher = ""
                hooks = @(
                    @{
                        type = "command"
                        command = $stopCmd
                    }
                )
            }
        ) -Force
    }

    # Write updated settings
    if ($DryRun) {
        Write-DryRun "Update $ClaudeSettings with hooks configuration"
        Write-Info "Would add Notification hook: $notifyCmd"
        Write-Info "Would add Stop hook: $stopCmd"
    } else {
        $settings | ConvertTo-Json -Depth 10 | Set-Content $ClaudeSettings
    }

    Write-Success "Claude Code hooks configured"
}

# Save version
function Save-Version {
    $version = Get-RepoVersion
    if ($DryRun) {
        Write-DryRun "Set-Content $VersionFile -Value $version"
    } else {
        $version | Set-Content $VersionFile
    }
    Write-Info "Version $version recorded"
}

# Test notification
function Test-Notification {
    if ($DryRun) {
        Write-DryRun "Send test notification via $ConfigDir\hooks\notify.ps1 -Test"
        return
    }

    if (-not $Force) {
        $response = Read-Host "Send a test notification? [Y/n]"
        if ($response -match '^[Nn]') {
            return
        }
    }

    Write-Info "Sending test notification..."
    try {
        & "$ConfigDir\hooks\notify.ps1" -Test
        Write-Success "Test notification sent!"
    } catch {
        Write-Err "Test notification failed: $_"
    }
}

# Print summary
function Write-Summary {
    $version = Get-RepoVersion

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Claude Notify v$version installed successfully!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installation locations:"
    Write-Host "  Config:  $ConfigDir\config.json"
    Write-Host "  Hooks:   $ConfigDir\hooks\"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Edit $ConfigDir\config.json to customize notifications"
    Write-Host "  2. For push notifications (ntfy, Pushover), add your credentials"
    Write-Host "  3. Start using Claude Code - you'll now receive notifications!"
    Write-Host ""
    Write-Host "To uninstall, run: $ScriptDir\uninstall.ps1"
    Write-Host ""
}

# Main
function Main {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Blue
    Write-Host "  Claude Notify Installer (Windows)" -ForegroundColor Blue
    Write-Host "======================================" -ForegroundColor Blue
    Write-Host ""

    if ($DryRun) {
        Write-Host "Running in DRY-RUN mode - no changes will be made" -ForegroundColor Yellow
        Write-Host ""
    }

    Test-Dependencies
    Test-ClaudeCode
    Test-Upgrade
    Backup-Settings
    New-Directories
    Install-Hooks
    Install-Config
    Install-Icon
    Set-ClaudeHooks
    Save-Version
    Test-Notification
    Write-Summary
}

Main
