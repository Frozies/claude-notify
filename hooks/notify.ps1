#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Notify - Windows notification script
.DESCRIPTION
    Sends notifications via Windows Toast notifications or BurntToast module
.PARAMETER Type
    Notification type: input, complete, error
.PARAMETER Title
    Custom notification title
.PARAMETER Message
    Custom notification message
.PARAMETER Backend
    Backend: auto, toast, burnttoast
.PARAMETER Urgency
    Urgency level: low, normal, critical
.PARAMETER Icon
    Path to icon file (.ico or .png)
.PARAMETER Sound
    Play notification sound
.PARAMETER Test
    Send a test notification
.PARAMETER Validate
    Validate configuration file
.PARAMETER Version
    Show version information
.EXAMPLE
    .\notify.ps1 -Type input
.EXAMPLE
    .\notify.ps1 -Title "Test" -Message "Hello from Claude Notify"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('input', 'complete', 'error')]
    [string]$Type,

    [Parameter()]
    [string]$Title,

    [Parameter()]
    [string]$Message,

    [Parameter()]
    [ValidateSet('auto', 'toast', 'burnttoast')]
    [string]$Backend = 'auto',

    [Parameter()]
    [ValidateSet('low', 'normal', 'critical')]
    [string]$Urgency = 'normal',

    [Parameter()]
    [string]$Icon,

    [Parameter()]
    [switch]$Sound,

    [Parameter()]
    [switch]$Test,

    [Parameter()]
    [string]$Validate,

    [Parameter()]
    [switch]$Version
)

# Configuration paths
$ConfigDir = Join-Path $env:APPDATA "claude-notify"
$ConfigFile = Join-Path $ConfigDir "config.json"
$VersionFile = Join-Path $ConfigDir ".version"
$ProjectConfigName = ".claude-notify.json"

# Notification presets
$Presets = @{
    input = @{
        Title = "Claude Code"
        Message = "Claude needs your input"
        Urgency = "normal"
        Icon = "dialog-question"
    }
    complete = @{
        Title = "Claude Code"
        Message = "Task completed"
        Urgency = "low"
        Icon = "dialog-ok"
    }
    error = @{
        Title = "Claude Code"
        Message = "An error occurred"
        Urgency = "critical"
        Icon = "dialog-error"
    }
}

# Show version
if ($Version) {
    if (Test-Path $VersionFile) {
        $ver = Get-Content $VersionFile -Raw
        Write-Host "Claude Notify v$($ver.Trim())"
    } else {
        Write-Host "Claude Notify (version unknown - not installed via installer)"
    }
    exit 0
}

# Find project-specific config
function Find-ProjectConfig {
    $dir = Get-Location
    while ($dir -ne $null -and $dir.FullName -ne "") {
        $configPath = Join-Path $dir.FullName $ProjectConfigName
        if (Test-Path $configPath) {
            return $configPath
        }
        $parent = Split-Path $dir.FullName -Parent
        if ($parent -eq $dir.FullName) { break }
        $dir = Get-Item $parent -ErrorAction SilentlyContinue
    }
    return $null
}

# Load and merge configuration
function Get-EffectiveConfig {
    $config = @{}

    # Load global config
    if (Test-Path $ConfigFile) {
        try {
            $globalConfig = Get-Content $ConfigFile -Raw | ConvertFrom-Json -AsHashtable
            $config = $globalConfig
        } catch {
            Write-Warning "Failed to parse global config: $_"
        }
    }

    # Load and merge project config
    $projectConfigPath = Find-ProjectConfig
    if ($projectConfigPath -and (Test-Path $projectConfigPath)) {
        try {
            $projectConfig = Get-Content $projectConfigPath -Raw | ConvertFrom-Json -AsHashtable
            # Simple merge - project overrides global
            foreach ($key in $projectConfig.Keys) {
                $config[$key] = $projectConfig[$key]
            }
        } catch {
            Write-Warning "Failed to parse project config: $_"
        }
    }

    return $config
}

# Validate configuration
function Test-Configuration {
    param([string]$ConfigPath)

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Config file not found: $ConfigPath"
        return $false
    }

    $errors = @()

    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        Write-Host "Invalid JSON syntax in $ConfigPath"
        return $false
    }

    # Validate backend
    $validBackends = @('auto', 'notify-send', 'osascript', 'terminal-notifier', 'powershell', 'toast', 'burnttoast', 'ntfy', 'pushover')
    if ($config.backend -and $config.backend -notin $validBackends) {
        $errors += "Invalid backend '$($config.backend)'. Valid: $($validBackends -join ', ')"
    }

    # Validate urgency levels
    $validUrgencies = @('low', 'normal', 'critical')
    foreach ($notifType in @('input_needed', 'task_complete', 'error')) {
        if ($config.notifications -and $config.notifications[$notifType] -and $config.notifications[$notifType].urgency) {
            $urg = $config.notifications[$notifType].urgency
            if ($urg -notin $validUrgencies) {
                $errors += "Invalid urgency '$urg' in notifications.$notifType. Valid: $($validUrgencies -join ', ')"
            }
        }
    }

    # Validate quiet hours format
    $timeRegex = '^([01][0-9]|2[0-3]):[0-5][0-9]$'
    if ($config.quiet_hours) {
        if ($config.quiet_hours.start -and $config.quiet_hours.start -notmatch $timeRegex) {
            $errors += "Invalid quiet_hours.start format '$($config.quiet_hours.start)'. Use HH:MM (24-hour)"
        }
        if ($config.quiet_hours.end -and $config.quiet_hours.end -notmatch $timeRegex) {
            $errors += "Invalid quiet_hours.end format '$($config.quiet_hours.end)'. Use HH:MM (24-hour)"
        }
    }

    if ($errors.Count -gt 0) {
        Write-Host "Configuration errors in $ConfigPath`:"
        foreach ($err in $errors) {
            Write-Host "  - $err"
        }
        return $false
    }

    return $true
}

# Handle validate mode
if ($Validate) {
    $fileToValidate = if ($Validate -eq $true -or $Validate -eq "") { $ConfigFile } else { $Validate }
    if (Test-Path $fileToValidate) {
        if (Test-Configuration $fileToValidate) {
            Write-Host "Configuration is valid: $fileToValidate"
            exit 0
        } else {
            exit 1
        }
    } else {
        Write-Host "No configuration file found at $fileToValidate"
        Write-Host "Using default settings."
        exit 0
    }
}

# Detect best backend
function Get-NotificationBackend {
    if ($Backend -ne 'auto') {
        return $Backend
    }

    # Check for BurntToast module
    if (Get-Module -ListAvailable -Name BurntToast) {
        return 'burnttoast'
    }

    # Fall back to native toast
    return 'toast'
}

# Send notification via native Windows Toast (no dependencies)
function Send-ToastNotification {
    param(
        [string]$NotifTitle,
        [string]$NotifMessage,
        [string]$NotifUrgency,
        [string]$NotifIcon,
        [bool]$PlaySound
    )

    # Load required assemblies
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

    # Build toast XML
    $audioElement = if ($PlaySound) {
        '<audio src="ms-winsoundevent:Notification.Default"/>'
    } else {
        '<audio silent="true"/>'
    }

    # Map urgency to scenario
    $scenario = switch ($NotifUrgency) {
        'critical' { 'urgency="critical"' }
        'low' { '' }
        default { '' }
    }

    $toastXml = @"
<toast $scenario>
    <visual>
        <binding template="ToastGeneric">
            <text>$([System.Security.SecurityElement]::Escape($NotifTitle))</text>
            <text>$([System.Security.SecurityElement]::Escape($NotifMessage))</text>
        </binding>
    </visual>
    $audioElement
</toast>
"@

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($toastXml)

    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)

    # Use Claude Code as the app ID
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Claude Code")
    $notifier.Show($toast)
}

# Send notification via BurntToast module
function Send-BurntToastNotification {
    param(
        [string]$NotifTitle,
        [string]$NotifMessage,
        [string]$NotifUrgency,
        [string]$NotifIcon,
        [bool]$PlaySound
    )

    Import-Module BurntToast -ErrorAction Stop

    $params = @{
        Text = @($NotifTitle, $NotifMessage)
    }

    # Add icon if specified and exists
    if ($NotifIcon -and (Test-Path $NotifIcon)) {
        $params.AppLogo = $NotifIcon
    }

    # Configure sound
    if (-not $PlaySound) {
        $params.Silent = $true
    }

    # Set urgency via expiration time
    switch ($NotifUrgency) {
        'critical' {
            # Critical notifications stay longer
            $params.ExpirationTime = (Get-Date).AddMinutes(30)
        }
        'low' {
            $params.ExpirationTime = (Get-Date).AddMinutes(1)
        }
    }

    New-BurntToastNotification @params
}

# Main execution
function Main {
    # Load config
    $config = Get-EffectiveConfig

    # Test mode
    if ($Test) {
        if (-not $Type) { $Type = 'input' }
        if (-not $Title) { $Title = "Test Notification" }
        if (-not $Message) { $Message = "This is a test notification from Claude Notify" }
    }

    # Apply presets
    if ($Type) {
        $preset = $Presets[$Type]
        if (-not $Title) { $Title = $preset.Title }
        if (-not $Message) { $Message = $preset.Message }
        if (-not $PSBoundParameters.ContainsKey('Urgency')) { $Urgency = $preset.Urgency }
        if (-not $Icon) { $Icon = $preset.Icon }
    }

    # Validate required params
    if (-not $Title -or -not $Message) {
        Write-Error "Error: -Title and -Message are required, or use -Type"
        exit 1
    }

    # Apply config overrides
    if ($config.icon -and -not $Icon) {
        $Icon = $config.icon -replace '~', $env:USERPROFILE
    }

    # Check for notification type enabled in config
    if ($Type -and $config.notifications) {
        $typeKey = switch ($Type) {
            'input' { 'input_needed' }
            'complete' { 'task_complete' }
            default { $Type }
        }
        if ($config.notifications[$typeKey] -and $config.notifications[$typeKey].enabled -eq $false) {
            # Notification type is disabled
            exit 0
        }
    }

    # Determine if sound should play
    $playSound = $Sound.IsPresent
    if (-not $PSBoundParameters.ContainsKey('Sound')) {
        # Check config
        if ($Type -and $config.notifications) {
            $typeKey = switch ($Type) {
                'input' { 'input_needed' }
                'complete' { 'task_complete' }
                default { $Type }
            }
            if ($config.notifications[$typeKey] -and $config.notifications[$typeKey].PSObject.Properties['sound']) {
                $playSound = $config.notifications[$typeKey].sound
            }
        }
        # Default based on urgency
        if (-not $playSound) {
            $playSound = $Urgency -in @('normal', 'critical')
        }
    }

    # Get backend
    $effectiveBackend = Get-NotificationBackend

    # Send notification
    try {
        switch ($effectiveBackend) {
            'burnttoast' {
                Send-BurntToastNotification -NotifTitle $Title -NotifMessage $Message -NotifUrgency $Urgency -NotifIcon $Icon -PlaySound $playSound
            }
            default {
                Send-ToastNotification -NotifTitle $Title -NotifMessage $Message -NotifUrgency $Urgency -NotifIcon $Icon -PlaySound $playSound
            }
        }

        if ($Test) {
            Write-Host "Test notification sent via $effectiveBackend"
        }
    } catch {
        Write-Error "Failed to send notification: $_"
        exit 1
    }
}

Main
