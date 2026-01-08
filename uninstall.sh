#!/usr/bin/env bash
#
# Claude Notify Uninstaller
# Removes notification hooks from Claude Code
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directories
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-notify"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"

# Logging functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Remove hooks from Claude Code settings
remove_hooks() {
    info "Removing hooks from Claude Code settings..."

    if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
        warn "Claude Code settings not found, skipping hook removal"
        return
    fi

    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        error "jq is required to modify settings. Please remove hooks manually from $CLAUDE_SETTINGS"
        return 1
    fi

    # Backup settings
    local backup="${CLAUDE_SETTINGS}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CLAUDE_SETTINGS" "$backup"
    info "Backed up settings to $backup"

    # Read current settings
    local current_settings
    current_settings=$(cat "$CLAUDE_SETTINGS")

    # Check if our hooks exist
    local notify_hook_cmd
    notify_hook_cmd=$(echo "$current_settings" | jq -r '.hooks.Notification[0].hooks[0].command // ""' 2>/dev/null || echo "")
    local stop_hook_cmd
    stop_hook_cmd=$(echo "$current_settings" | jq -r '.hooks.Stop[0].hooks[0].command // ""' 2>/dev/null || echo "")

    local removed_notification=false
    local removed_stop=false

    # Remove Notification hook if it's ours
    if [[ "$notify_hook_cmd" == *"claude-notify"* ]]; then
        current_settings=$(echo "$current_settings" | jq 'del(.hooks.Notification)')
        removed_notification=true
        success "Removed Notification hook"
    elif [[ -n "$notify_hook_cmd" ]]; then
        warn "Notification hook exists but doesn't appear to be from Claude Notify, leaving it"
    fi

    # Remove Stop hook if it's ours
    if [[ "$stop_hook_cmd" == *"claude-notify"* ]]; then
        current_settings=$(echo "$current_settings" | jq 'del(.hooks.Stop)')
        removed_stop=true
        success "Removed Stop hook"
    elif [[ -n "$stop_hook_cmd" ]]; then
        warn "Stop hook exists but doesn't appear to be from Claude Notify, leaving it"
    fi

    # Clean up empty hooks object
    local hooks_count
    hooks_count=$(echo "$current_settings" | jq '.hooks | length' 2>/dev/null || echo "0")
    if [[ "$hooks_count" == "0" ]]; then
        current_settings=$(echo "$current_settings" | jq 'del(.hooks)')
    fi

    # Write updated settings
    echo "$current_settings" | jq '.' > "$CLAUDE_SETTINGS"

    if [[ "$removed_notification" == true || "$removed_stop" == true ]]; then
        success "Claude Code hooks cleaned up"
    else
        info "No Claude Notify hooks found to remove"
    fi
}

# Remove configuration files
remove_config() {
    if [[ ! -d "$CONFIG_DIR" ]]; then
        info "Configuration directory not found, nothing to remove"
        return
    fi

    echo ""
    read -p "Remove configuration files at $CONFIG_DIR? [y/N] " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR"
        success "Configuration directory removed"
    else
        info "Keeping configuration files"
    fi
}

# Remove icon
remove_icon() {
    local icon_file="$ICON_DIR/claude-ai.png"

    if [[ ! -f "$icon_file" ]]; then
        return
    fi

    echo ""
    read -p "Remove notification icon at $icon_file? [y/N] " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$icon_file"
        success "Icon removed"
    else
        info "Keeping icon file"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Claude Notify uninstalled${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "Claude Code will no longer send notifications."
    echo ""
    echo "To reinstall, run: ./install.sh"
    echo ""
}

# Main uninstallation
main() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Claude Notify Uninstaller${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""

    read -p "Are you sure you want to uninstall Claude Notify? [y/N] " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Uninstallation cancelled"
        exit 0
    fi

    remove_hooks
    remove_config
    remove_icon
    print_summary
}

main "$@"
