# Claude Notify - Development Roadmap

This document tracks the development progress of Claude Notify, a multi-platform notification system for Claude Code.

## Project Status: Alpha

---

## Phase 1: Core Infrastructure (Current)

### 1.1 Project Setup
- [x] Initialize git repository
- [x] Add Apache 2.0 license
- [x] Create directory structure
- [x] Write README.md documentation
- [x] Create TODO.md roadmap

### 1.2 Linux Desktop Notifications (notify-send)
- [x] Create notification hook script
- [x] Create stop hook script
- [x] Support custom icons
- [x] Support notification urgency levels
- [x] Add notification categories/hints
- [x] Support notification actions (buttons)

### 1.3 Configuration System
- [x] Create JSON configuration schema
- [x] Support environment variable overrides
- [x] Create example configuration file
- [x] Add configuration validation
- [x] Support per-project configuration overrides

### 1.4 Installation System
- [x] Create install.sh for Linux
- [x] Create uninstall.sh
- [x] Auto-detect existing Claude Code installation
- [x] Backup existing hooks before modification
- [x] Add --dry-run option to installer
- [x] Add version detection and upgrade path

---

## Phase 2: macOS Support

### 2.1 Native Notifications (osascript/terminal-notifier)
- [x] Create macOS notification script using osascript
- [x] Add terminal-notifier support for richer notifications
- [x] Support macOS notification center grouping
- [x] Add sound customization
- [x] Support notification actions

### 2.2 macOS Installation
- [x] Create install.sh logic for macOS
- [x] Detect Homebrew and offer terminal-notifier install
- [x] Support macOS icon formats (.icns)
- [x] Handle macOS permission requirements

---

## Phase 3: Windows Support

### 3.1 Windows Toast Notifications
- [x] Create PowerShell notification script
- [x] Support Windows Toast notification format
- [x] Add BurntToast module support for rich notifications
- [x] Support notification sounds
- [x] Handle Windows notification permissions

### 3.2 Windows Installation
- [x] Create install.ps1 for Windows
- [x] Create install.bat wrapper
- [x] Handle Windows path conventions
- [x] Support Windows icon formats (.ico)

---

## Phase 4: Push Notification Services

### 4.1 ntfy.sh Integration
- [x] Create ntfy notification backend
- [x] Support self-hosted ntfy servers
- [x] Add priority levels mapping
- [x] Support ntfy tags/emojis
- [x] Add attachment support (screenshots, logs)
- [x] Support ntfy actions (buttons with URLs)
- [x] Add click action to open Claude Code

### 4.2 Pushover Integration
- [ ] Create Pushover notification backend
- [ ] Support priority levels (-2 to 2)
- [ ] Add sound customization
- [ ] Support HTML message formatting
- [ ] Add supplementary URL support
- [ ] Implement device targeting

### 4.3 Telegram Bot Integration
- [ ] Create Telegram bot notification backend
- [ ] Support inline keyboard buttons
- [ ] Add markdown/HTML formatting
- [ ] Support silent notifications
- [ ] Add photo/document attachments

### 4.4 Discord Webhook Integration
- [ ] Create Discord webhook backend
- [ ] Support rich embeds
- [ ] Add color coding by notification type
- [ ] Support @mentions

### 4.5 Slack Webhook Integration
- [ ] Create Slack webhook backend
- [ ] Support Block Kit formatting
- [ ] Add channel targeting
- [ ] Support thread replies

---

## Phase 5: Advanced Features

### 5.1 Multi-Backend Support
- [ ] Allow multiple notification backends simultaneously
- [ ] Add backend priority/fallback system
- [ ] Support conditional backend selection (e.g., ntfy when away from desk)
- [ ] Add rate limiting per backend

### 5.2 Notification Filtering
- [ ] Filter by notification type (input needed, task complete, error)
- [ ] Filter by project/directory
- [ ] Add quiet hours / do-not-disturb schedule
- [ ] Support notification batching/debouncing

### 5.3 Rich Notifications
- [ ] Include context in notifications (current task, file being edited)
- [ ] Add notification history/log
- [ ] Support notification templates
- [ ] Add custom sounds per notification type

### 5.4 Status Monitoring
- [ ] Add health check endpoint for monitoring
- [ ] Create status dashboard (optional web UI)
- [ ] Add notification delivery confirmation
- [ ] Support notification read receipts (where available)

---

## Phase 6: Developer Experience

### 6.1 Testing
- [ ] Add unit tests for configuration parsing
- [ ] Add integration tests for each backend
- [ ] Create mock notification backend for testing
- [ ] Add CI/CD pipeline (GitHub Actions)

### 6.2 Documentation
- [x] Create comprehensive README
- [x] Add installation instructions for all platforms
- [x] Document configuration options
- [ ] Add troubleshooting guide
- [ ] Create video tutorial
- [ ] Add architecture documentation
- [x] Create contribution guidelines (CONTRIBUTING.md)

### 6.3 Distribution
- [ ] Publish to GitHub
- [ ] Add GitHub release automation
- [ ] Create Homebrew formula (macOS)
- [ ] Create AUR package (Arch Linux)
- [ ] Create .deb package (Debian/Ubuntu)
- [ ] Create .rpm package (Fedora/RHEL)
- [ ] Add to Claude Code plugin marketplace (if available)

---

## Phase 7: Ecosystem Integration

### 7.1 IDE Integration
- [ ] Document VS Code + Claude Code setup
- [ ] Document JetBrains IDE setup
- [ ] Add workspace-specific notification settings

### 7.2 Mobile Companion App (Stretch Goal)
- [ ] Design mobile app for notification management
- [ ] Add quick reply functionality
- [ ] Support viewing Claude Code session status
- [ ] Add remote session reconnection

---

## Backlog / Ideas

- [ ] Support for email notifications
- [ ] Integration with Home Assistant
- [ ] Physical notification devices (blink(1), etc.)
- [ ] Voice announcements (text-to-speech)
- [ ] Integration with calendar for smart scheduling
- [ ] AI-powered notification summarization
- [ ] Notification analytics and insights

---

## Version History

### v0.1.0 (Initial Release)
- Linux notify-send support
- Basic configuration system
- Install/uninstall scripts
- Documentation

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to this project.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.
