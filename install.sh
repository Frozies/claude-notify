#!/usr/bin/env bash
#
# Claude Notify Installer
# Installs notification hooks for Claude Code
#

set -euo pipefail

# Parse arguments
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            ;;
        --help|-h)
            echo "Usage: install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n  Show what would be done without making changes"
            echo "  --help, -h     Show this help message"
            exit 0
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation directories
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-notify"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
VERSION_FILE="${CONFIG_DIR}/.version"

# Get current version from repo
get_repo_version() {
    if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
        cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]'
    else
        echo "0.0.0"
    fi
}

# Get installed version
get_installed_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE" | tr -d '[:space:]'
    else
        echo ""
    fi
}

# Compare semantic versions (returns: 0=equal, 1=first greater, 2=second greater)
compare_versions() {
    local v1="$1"
    local v2="$2"

    if [[ "$v1" == "$v2" ]]; then
        echo 0
        return
    fi

    local IFS='.'
    local i
    local v1_parts=($v1)
    local v2_parts=($v2)

    for ((i=0; i<3; i++)); do
        local v1_part="${v1_parts[i]:-0}"
        local v2_part="${v2_parts[i]:-0}"
        if ((v1_part > v2_part)); then
            echo 1
            return
        elif ((v1_part < v2_part)); then
            echo 2
            return
        fi
    done
    echo 0
}

# Logging functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
dry_run_msg() { echo -e "${YELLOW}[DRY-RUN]${NC} Would: $1"; }

# Execute command or show what would be done in dry-run mode
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "$*"
        return 0
    else
        "$@"
    fi
}

# Check for existing installation and handle upgrade
check_upgrade() {
    local repo_version=$(get_repo_version)
    local installed_version=$(get_installed_version)

    if [[ -z "$installed_version" ]]; then
        info "Fresh installation of Claude Notify v${repo_version}"
        return 0
    fi

    local comparison=$(compare_versions "$repo_version" "$installed_version")

    case $comparison in
        0)
            info "Claude Notify v${installed_version} is already installed (same version)"
            if [[ "$DRY_RUN" != true ]]; then
                read -p "Reinstall? [y/N] " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    info "Installation cancelled"
                    exit 0
                fi
            fi
            ;;
        1)
            success "Upgrading Claude Notify: v${installed_version} -> v${repo_version}"
            ;;
        2)
            warn "Installed version (v${installed_version}) is newer than repo (v${repo_version})"
            if [[ "$DRY_RUN" != true ]]; then
                read -p "Downgrade? [y/N] " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    info "Installation cancelled"
                    exit 0
                fi
            fi
            ;;
    esac
}

# Save installed version
save_version() {
    local version=$(get_repo_version)
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "echo $version > $VERSION_FILE"
    else
        echo "$version" > "$VERSION_FILE"
    fi
    info "Version $version recorded"
}

# Check dependencies
check_dependencies() {
    info "Checking dependencies..."

    local missing=()

    # Check for jq
    if ! command -v jq &>/dev/null; then
        missing+=("jq")
    fi

    # Platform-specific checks
    case "$(uname -s)" in
        Linux*)
            if ! command -v notify-send &>/dev/null; then
                warn "notify-send not found. Install libnotify-bin for desktop notifications."
            fi
            ;;
        Darwin*)
            info "macOS detected"
            if ! command -v terminal-notifier &>/dev/null; then
                warn "terminal-notifier not found. Install via: brew install terminal-notifier"
                info "Falling back to osascript (basic notifications)"
            fi
            ;;
    esac

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing[*]}"
        echo ""
        echo "Install them with:"
        echo "  Debian/Ubuntu: sudo apt install ${missing[*]}"
        echo "  Fedora:        sudo dnf install ${missing[*]}"
        echo "  Arch:          sudo pacman -S ${missing[*]}"
        echo "  macOS:         brew install ${missing[*]}"
        exit 1
    fi

    success "All required dependencies found"
}

# Check for Claude Code installation
check_claude_code() {
    info "Checking Claude Code installation..."

    if [[ ! -d "$HOME/.claude" ]]; then
        error "Claude Code configuration directory not found at ~/.claude"
        echo "Please ensure Claude Code is installed and has been run at least once."
        exit 1
    fi

    if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
        warn "Claude Code settings.json not found, will create it"
        mkdir -p "$HOME/.claude"
        echo '{}' > "$CLAUDE_SETTINGS"
    fi

    success "Claude Code installation found"
}

# Backup existing settings
backup_settings() {
    if [[ -f "$CLAUDE_SETTINGS" ]]; then
        local backup="${CLAUDE_SETTINGS}.backup.$(date +%Y%m%d_%H%M%S)"
        if [[ "$DRY_RUN" == true ]]; then
            dry_run_msg "cp $CLAUDE_SETTINGS $backup"
        else
            cp "$CLAUDE_SETTINGS" "$backup"
        fi
        info "Backed up settings to $backup"
    fi
}

# Create installation directories
create_directories() {
    info "Creating directories..."

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "mkdir -p $CONFIG_DIR/hooks"
        dry_run_msg "mkdir -p $ICON_DIR"
    else
        mkdir -p "$CONFIG_DIR/hooks"
        mkdir -p "$ICON_DIR"
    fi

    success "Directories created"
}

# Install hook scripts
install_hooks() {
    info "Installing hook scripts..."

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "cp $SCRIPT_DIR/hooks/notify.sh $CONFIG_DIR/hooks/"
        dry_run_msg "chmod +x $CONFIG_DIR/hooks/notify.sh"
    else
        cp "$SCRIPT_DIR/hooks/notify.sh" "$CONFIG_DIR/hooks/"
        chmod +x "$CONFIG_DIR/hooks/notify.sh"
    fi

    success "Hook scripts installed to $CONFIG_DIR/hooks/"
}

# Install configuration
install_config() {
    info "Installing configuration..."

    if [[ ! -f "$CONFIG_DIR/config.json" ]] || [[ "$DRY_RUN" == true ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
                dry_run_msg "cp $SCRIPT_DIR/config/config.example.json $CONFIG_DIR/config.json"
                success "Configuration installed to $CONFIG_DIR/config.json"
            else
                info "Configuration already exists, skipping"
            fi
        else
            cp "$SCRIPT_DIR/config/config.example.json" "$CONFIG_DIR/config.json"
            success "Configuration installed to $CONFIG_DIR/config.json"
        fi
    else
        info "Configuration already exists, skipping"
    fi
}

# Install icon (if available)
install_icon() {
    info "Setting up notification icon..."

    # Check for existing Claude icon
    local existing_icon="$HOME/.local/share/icons/claude-ai.png"
    if [[ -f "$existing_icon" ]]; then
        success "Using existing Claude icon at $existing_icon"
        return
    fi

    # Check if we have an icon in the repo
    if [[ -f "$SCRIPT_DIR/icons/claude-ai.png" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            dry_run_msg "cp $SCRIPT_DIR/icons/claude-ai.png $ICON_DIR/"
        else
            cp "$SCRIPT_DIR/icons/claude-ai.png" "$ICON_DIR/"
        fi
        success "Icon installed to $ICON_DIR/claude-ai.png"
    else
        warn "No icon found. Notifications will use system default icon."
        info "You can add a custom icon later at $ICON_DIR/claude-ai.png"
    fi
}

# Configure Claude Code hooks
configure_hooks() {
    info "Configuring Claude Code hooks..."

    local notify_cmd="$CONFIG_DIR/hooks/notify.sh --type input"
    local stop_cmd="$CONFIG_DIR/hooks/notify.sh --type complete"

    # Read current settings
    local current_settings
    current_settings=$(cat "$CLAUDE_SETTINGS")

    # Check if hooks already exist (skip prompts in dry-run mode)
    if [[ "$DRY_RUN" != true ]]; then
        if echo "$current_settings" | jq -e '.hooks.Notification' &>/dev/null; then
            warn "Notification hook already exists in Claude Code settings"
            read -p "Overwrite existing Notification hook? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Keeping existing Notification hook"
                notify_cmd=""
            fi
        fi

        if echo "$current_settings" | jq -e '.hooks.Stop' &>/dev/null; then
            warn "Stop hook already exists in Claude Code settings"
            read -p "Overwrite existing Stop hook? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                info "Keeping existing Stop hook"
                stop_cmd=""
            fi
        fi
    fi

    # Build the new hooks configuration
    local new_settings="$current_settings"

    if [[ -n "$notify_cmd" ]]; then
        new_settings=$(echo "$new_settings" | jq --arg cmd "$notify_cmd" '
            .hooks.Notification = [
                {
                    "matcher": "",
                    "hooks": [
                        {
                            "type": "command",
                            "command": $cmd
                        }
                    ]
                }
            ]
        ')
    fi

    if [[ -n "$stop_cmd" ]]; then
        new_settings=$(echo "$new_settings" | jq --arg cmd "$stop_cmd" '
            .hooks.Stop = [
                {
                    "matcher": "",
                    "hooks": [
                        {
                            "type": "command",
                            "command": $cmd
                        }
                    ]
                }
            ]
        ')
    fi

    # Write updated settings
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Update $CLAUDE_SETTINGS with hooks configuration"
        info "Would add Notification hook: $notify_cmd"
        info "Would add Stop hook: $stop_cmd"
    else
        echo "$new_settings" | jq '.' > "$CLAUDE_SETTINGS"
    fi

    success "Claude Code hooks configured"
}

# Test notification
test_notification() {
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_msg "Send test notification via $CONFIG_DIR/hooks/notify.sh --test"
        return
    fi

    read -p "Send a test notification? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        return
    fi

    info "Sending test notification..."
    if "$CONFIG_DIR/hooks/notify.sh" --test; then
        success "Test notification sent!"
    else
        error "Test notification failed"
    fi
}

# Print summary
print_summary() {
    local version=$(get_repo_version)
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Claude Notify v${version} installed successfully!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "Installation locations:"
    echo "  Config:  $CONFIG_DIR/config.json"
    echo "  Hooks:   $CONFIG_DIR/hooks/"
    echo ""
    echo "Next steps:"
    echo "  1. Edit $CONFIG_DIR/config.json to customize notifications"
    echo "  2. For push notifications (ntfy, Pushover), add your credentials"
    echo "  3. Start using Claude Code - you'll now receive notifications!"
    echo ""
    echo "To uninstall, run: $SCRIPT_DIR/uninstall.sh"
    echo ""
}

# Main installation
main() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Claude Notify Installer${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}Running in DRY-RUN mode - no changes will be made${NC}"
        echo ""
    fi

    check_dependencies
    check_claude_code
    check_upgrade
    backup_settings
    create_directories
    install_hooks
    install_config
    install_icon
    configure_hooks
    save_version
    test_notification
    print_summary
}

main "$@"
