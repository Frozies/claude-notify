# Claude Notify

Multi-platform notification system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Get notified when Claude needs your input or completes a task.

## Features

- **Desktop Notifications** - Native notifications on Linux, macOS, and Windows
- **Push Notifications** - Mobile alerts via ntfy.sh, Pushover, and more
- **Customizable** - Configure icons, sounds, urgency, and notification content
- **Non-intrusive** - Uses Claude Code's built-in hooks system

## Supported Platforms

| Platform | Backend | Status |
|----------|---------|--------|
| Linux | `notify-send` (libnotify) | Stable |
| macOS | `osascript` / `terminal-notifier` | Stable |
| Windows | PowerShell Toast / BurntToast | Stable |
| Mobile | ntfy.sh | Planned |
| Mobile | Pushover | Planned |

## Quick Start

### Linux

```bash
# Clone the repository
git clone https://github.com/yourusername/claude-notify.git
cd claude-notify

# Run the installer
./install.sh
```

### macOS

```bash
# Clone the repository
git clone https://github.com/yourusername/claude-notify.git
cd claude-notify

# Run the installer
./install.sh
```

### Windows

```powershell
# Clone the repository
git clone https://github.com/yourusername/claude-notify.git
cd claude-notify

# Run the installer (PowerShell)
.\install.ps1

# Or use the batch file (double-click or run from cmd)
.\install.bat
```

That's it! You'll now receive desktop notifications when Claude Code needs input.

## Installation

### Prerequisites

#### Linux
- Claude Code installed and configured
- `notify-send` (usually pre-installed, part of `libnotify-bin`)
- Bash shell

```bash
# Debian/Ubuntu - install notify-send if not present
sudo apt install libnotify-bin

# Fedora
sudo dnf install libnotify

# Arch Linux
sudo pacman -S libnotify
```

#### macOS
- Claude Code installed and configured
- Either `terminal-notifier` (recommended) or built-in `osascript`

```bash
# Install terminal-notifier via Homebrew (optional, for richer notifications)
brew install terminal-notifier
```

The installer will automatically detect Homebrew and offer to install `terminal-notifier` for you.

#### Windows
- Claude Code installed and configured
- PowerShell 5.1 or later (included with Windows 10/11)
- Optional: BurntToast module for rich notifications

```powershell
# Install BurntToast (optional, for rich notifications)
Install-Module -Name BurntToast -Scope CurrentUser
```

### Install Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/claude-notify.git
   cd claude-notify
   ```

2. **Review the configuration** (optional)
   ```bash
   cp config/config.example.json config/config.json
   # Edit config/config.json to customize
   ```

3. **Run the installer**
   ```bash
   # Linux/macOS
   ./install.sh

   # Windows (PowerShell as Administrator)
   .\install.ps1
   ```

4. **Verify installation**
   ```bash
   # Test notification
   ./hooks/notify.sh --test
   ```

## Configuration

Claude Notify uses a JSON configuration file located at `~/.config/claude-notify/config.json`.

### Configuration Options

```json
{
  "backend": "auto",
  "icon": "~/.local/share/icons/claude-ai.png",
  "notifications": {
    "input_needed": {
      "enabled": true,
      "title": "Claude Code",
      "message": "Claude needs your input",
      "urgency": "normal",
      "sound": true
    },
    "task_complete": {
      "enabled": true,
      "title": "Claude Code",
      "message": "Task completed",
      "urgency": "low",
      "sound": false
    },
    "error": {
      "enabled": true,
      "title": "Claude Code",
      "message": "An error occurred",
      "urgency": "critical",
      "sound": true
    }
  },
  "quiet_hours": {
    "enabled": false,
    "start": "22:00",
    "end": "08:00"
  },
  "backends": {
    "notify-send": {
      "timeout": 5000
    },
    "ntfy": {
      "server": "https://ntfy.sh",
      "topic": "your-private-topic",
      "priority": "default"
    },
    "pushover": {
      "user_key": "",
      "api_token": ""
    }
  }
}
```

### Configuration Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `backend` | string | `"auto"` | Notification backend: `auto`, `notify-send`, `osascript`, `terminal-notifier`, `powershell`, `ntfy`, `pushover` |
| `icon` | string | `""` | Path to notification icon (supports `~` expansion) |
| `notifications.*.enabled` | bool | `true` | Enable/disable specific notification types |
| `notifications.*.title` | string | varies | Notification title |
| `notifications.*.message` | string | varies | Notification message body |
| `notifications.*.urgency` | string | `"normal"` | Urgency level: `low`, `normal`, `critical` |
| `notifications.*.sound` | bool | varies | Play notification sound |
| `quiet_hours.enabled` | bool | `false` | Enable quiet hours |
| `quiet_hours.start` | string | `"22:00"` | Quiet hours start time (24h format) |
| `quiet_hours.end` | string | `"08:00"` | Quiet hours end time (24h format) |

### Environment Variables

Configuration can be overridden with environment variables:

```bash
export CLAUDE_NOTIFY_BACKEND="ntfy"
export CLAUDE_NOTIFY_ICON="/path/to/icon.png"
export CLAUDE_NOTIFY_NTFY_TOPIC="my-topic"
export CLAUDE_NOTIFY_NTFY_SERVER="https://ntfy.example.com"
export CLAUDE_NOTIFY_PUSHOVER_USER="your-user-key"
export CLAUDE_NOTIFY_PUSHOVER_TOKEN="your-api-token"
```

## Usage

Once installed, Claude Notify runs automatically via Claude Code's hooks system. No manual intervention required.

### Hook Events

| Event | Trigger | Default Behavior |
|-------|---------|------------------|
| `Notification` | Claude needs user input | Desktop notification with bell icon |
| `Stop` | Task completed | Desktop notification with checkmark |

### Manual Testing

```bash
# Test input-needed notification
./hooks/notify.sh --type input

# Test task-complete notification
./hooks/notify.sh --type complete

# Test with custom message
./hooks/notify.sh --title "Test" --message "Hello from Claude Notify"

# Test specific backend
./hooks/notify.sh --backend ntfy --type input
```

## Backends

### notify-send (Linux)

Uses the standard Linux desktop notification system via `libnotify`.

**Pros:**
- No external dependencies on most distros
- Native look and feel
- Supports actions (click to focus)

**Configuration:**
```json
{
  "backends": {
    "notify-send": {
      "timeout": 5000,
      "category": "im.received"
    }
  }
}
```

### ntfy.sh (Cross-platform Push)

Free, open-source push notification service. Get notifications on your phone!

**Setup:**
1. Install the ntfy app on your phone ([Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy), [iOS](https://apps.apple.com/app/ntfy/id1625396347))
2. Subscribe to a unique topic (e.g., `claude-notify-yourname-abc123`)
3. Configure Claude Notify with the same topic

**Configuration:**
```json
{
  "backend": "ntfy",
  "backends": {
    "ntfy": {
      "server": "https://ntfy.sh",
      "topic": "your-private-unique-topic",
      "priority": "default"
    }
  }
}
```

**Self-hosted ntfy:**
```json
{
  "backends": {
    "ntfy": {
      "server": "https://ntfy.yourdomain.com",
      "topic": "claude",
      "username": "user",
      "password": "pass"
    }
  }
}
```

### Pushover (Cross-platform Push)

Commercial push notification service with a one-time purchase for the mobile app.

**Setup:**
1. Create a Pushover account at [pushover.net](https://pushover.net)
2. Get your User Key from the dashboard
3. Create an application and get the API Token
4. Install the Pushover app on your devices

**Configuration:**
```json
{
  "backend": "pushover",
  "backends": {
    "pushover": {
      "user_key": "your-user-key",
      "api_token": "your-api-token",
      "device": "",
      "priority": 0,
      "sound": "pushover"
    }
  }
}
```

## How It Works

Claude Notify integrates with Claude Code's [hooks system](https://docs.anthropic.com/en/docs/claude-code/hooks). When you run the installer, it modifies your Claude Code settings (`~/.claude/settings.json`) to add notification hooks:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.config/claude-notify/hooks/notify.sh --type input"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.config/claude-notify/hooks/notify.sh --type complete"
          }
        ]
      }
    ]
  }
}
```

The hooks are triggered by Claude Code at the appropriate times, and the notification scripts handle the rest.

## Uninstallation

```bash
# Linux/macOS
./uninstall.sh

# Windows (PowerShell as Administrator)
.\uninstall.ps1
```

This will:
1. Remove Claude Notify hooks from Claude Code settings
2. Remove configuration files (optional, prompted)
3. Remove installed scripts

## Troubleshooting

### Notifications not appearing (Linux)

1. **Check if notify-send works:**
   ```bash
   notify-send "Test" "This is a test notification"
   ```

2. **Check notification daemon:**
   ```bash
   # GNOME
   systemctl --user status org.gnome.Shell

   # Other DEs - check your notification daemon
   ps aux | grep -i dunst  # dunst
   ps aux | grep -i mako   # mako (Wayland)
   ```

3. **Check Claude Code hooks:**
   ```bash
   cat ~/.claude/settings.json | jq '.hooks'
   ```

### Notifications not appearing (macOS)

1. **Check System Preferences:** System Preferences > Notifications > Terminal (or your terminal app)
2. **Enable notifications** for your terminal application

### ntfy not working

1. **Test ntfy directly:**
   ```bash
   curl -d "Test message" https://ntfy.sh/your-topic
   ```

2. **Check your phone:** Make sure the ntfy app is installed and subscribed to the correct topic

3. **Check network:** Ensure you can reach the ntfy server

### Hooks not triggering

1. **Verify Claude Code version:** Hooks require a recent version of Claude Code
2. **Check settings.json syntax:** Ensure valid JSON
   ```bash
   cat ~/.claude/settings.json | jq .
   ```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
# Clone the repo
git clone https://github.com/yourusername/claude-notify.git
cd claude-notify

# Run tests
./test.sh

# Test a specific backend
./hooks/notify.sh --backend notify-send --test
```

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.

## Acknowledgments

- Inspired by [Claude Code Hooks: Automating macOS Notifications for Task Completion](https://nakamasato.medium.com/claude-code-hooks-automating-macos-notifications-for-task-completion-42d200e751cc) by nakamasato
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic
- [ntfy](https://ntfy.sh) by Philipp C. Heckel
- [libnotify](https://gitlab.gnome.org/GNOME/libnotify) by the GNOME project
