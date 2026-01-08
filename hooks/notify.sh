#!/usr/bin/env bash
#
# Claude Notify - Main notification script
# Sends notifications via the configured backend
#
# Usage:
#   notify.sh --type input|complete|error
#   notify.sh --title "Title" --message "Message"
#   notify.sh --backend notify-send --type input
#   notify.sh --test
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-notify"
CONFIG_FILE="${CONFIG_DIR}/config.json"

# Defaults
DEFAULT_BACKEND="auto"
DEFAULT_ICON=""
DEFAULT_URGENCY="normal"
DEFAULT_TIMEOUT=5000

# Notification presets
declare -A PRESET_TITLES=(
    [input]="Claude Code"
    [complete]="Claude Code"
    [error]="Claude Code"
)

declare -A PRESET_MESSAGES=(
    [input]="Claude needs your input"
    [complete]="Task completed"
    [error]="An error occurred"
)

declare -A PRESET_URGENCY=(
    [input]="normal"
    [complete]="low"
    [error]="critical"
)

declare -A PRESET_ICONS=(
    [input]="dialog-question"
    [complete]="dialog-ok"
    [error]="dialog-error"
)

# Parse command line arguments
TYPE=""
TITLE=""
MESSAGE=""
BACKEND=""
URGENCY=""
ICON=""
TEST_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --type|-t)
            TYPE="$2"
            shift 2
            ;;
        --title)
            TITLE="$2"
            shift 2
            ;;
        --message|-m)
            MESSAGE="$2"
            shift 2
            ;;
        --backend|-b)
            BACKEND="$2"
            shift 2
            ;;
        --urgency|-u)
            URGENCY="$2"
            shift 2
            ;;
        --icon|-i)
            ICON="$2"
            shift 2
            ;;
        --test)
            TEST_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: notify.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --type, -t TYPE      Notification type: input, complete, error"
            echo "  --title TITLE        Custom notification title"
            echo "  --message, -m MSG    Custom notification message"
            echo "  --backend, -b NAME   Backend: auto, notify-send, osascript, ntfy, pushover"
            echo "  --urgency, -u LEVEL  Urgency: low, normal, critical"
            echo "  --icon, -i PATH      Path to icon file"
            echo "  --test               Send a test notification"
            echo "  --help, -h           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Check if jq is available
        if command -v jq &>/dev/null; then
            CONFIG_BACKEND=$(jq -r '.backend // "auto"' "$CONFIG_FILE" 2>/dev/null || echo "auto")
            CONFIG_ICON=$(jq -r '.icon // ""' "$CONFIG_FILE" 2>/dev/null || echo "")

            # Load notification-specific settings if type is set
            if [[ -n "$TYPE" ]]; then
                local type_enabled=$(jq -r ".notifications.${TYPE}_needed.enabled // .notifications.task_${TYPE}.enabled // true" "$CONFIG_FILE" 2>/dev/null || echo "true")
                if [[ "$type_enabled" == "false" ]]; then
                    exit 0  # Notification type is disabled
                fi
            fi
        fi
    fi

    # Environment variable overrides
    BACKEND="${BACKEND:-${CLAUDE_NOTIFY_BACKEND:-${CONFIG_BACKEND:-$DEFAULT_BACKEND}}}"
    ICON="${ICON:-${CLAUDE_NOTIFY_ICON:-${CONFIG_ICON:-$DEFAULT_ICON}}}"
}

# Expand ~ in paths
expand_path() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}

# Detect the best available backend
detect_backend() {
    case "$(uname -s)" in
        Linux*)
            if command -v notify-send &>/dev/null; then
                echo "notify-send"
            else
                echo "none"
            fi
            ;;
        Darwin*)
            if command -v terminal-notifier &>/dev/null; then
                echo "terminal-notifier"
            else
                echo "osascript"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "powershell"
            ;;
        *)
            echo "none"
            ;;
    esac
}

# Send notification via notify-send (Linux)
send_notify_send() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    local icon="$4"

    local args=()
    args+=("--urgency=$urgency")

    if [[ -n "$icon" ]]; then
        local expanded_icon=$(expand_path "$icon")
        if [[ -f "$expanded_icon" ]]; then
            args+=("--icon=$expanded_icon")
        else
            args+=("--icon=$icon")
        fi
    fi

    args+=("--app-name=Claude Code")
    args+=("$title")
    args+=("$message")

    notify-send "${args[@]}"
}

# Send notification via osascript (macOS)
send_osascript() {
    local title="$1"
    local message="$2"

    osascript -e "display notification \"$message\" with title \"$title\""
}

# Send notification via terminal-notifier (macOS)
send_terminal_notifier() {
    local title="$1"
    local message="$2"
    local icon="$3"

    local args=()
    args+=("-title" "$title")
    args+=("-message" "$message")
    args+=("-group" "claude-notify")

    if [[ -n "$icon" ]]; then
        local expanded_icon=$(expand_path "$icon")
        if [[ -f "$expanded_icon" ]]; then
            args+=("-contentImage" "$expanded_icon")
        fi
    fi

    terminal-notifier "${args[@]}"
}

# Send notification via PowerShell (Windows)
send_powershell() {
    local title="$1"
    local message="$2"

    powershell.exe -Command "
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        \$template = @\"
        <toast>
            <visual>
                <binding template=\"ToastText02\">
                    <text id=\"1\">$title</text>
                    <text id=\"2\">$message</text>
                </binding>
            </visual>
        </toast>
\"@

        \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        \$xml.LoadXml(\$template)
        \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show(\$toast)
    "
}

# Send notification via ntfy
send_ntfy() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"

    local server="${CLAUDE_NOTIFY_NTFY_SERVER:-https://ntfy.sh}"
    local topic="${CLAUDE_NOTIFY_NTFY_TOPIC:-}"

    if [[ -z "$topic" ]]; then
        # Try to read from config
        if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
            topic=$(jq -r '.backends.ntfy.topic // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
            server=$(jq -r '.backends.ntfy.server // "https://ntfy.sh"' "$CONFIG_FILE" 2>/dev/null || echo "$server")
        fi
    fi

    if [[ -z "$topic" ]]; then
        echo "Error: ntfy topic not configured" >&2
        return 1
    fi

    local ntfy_priority="default"
    case "$priority" in
        low) ntfy_priority="low" ;;
        normal) ntfy_priority="default" ;;
        critical) ntfy_priority="urgent" ;;
    esac

    curl -s \
        -H "Title: $title" \
        -H "Priority: $ntfy_priority" \
        -H "Tags: robot" \
        -d "$message" \
        "${server}/${topic}" >/dev/null
}

# Send notification via Pushover
send_pushover() {
    local title="$1"
    local message="$2"
    local priority="${3:-0}"

    local user_key="${CLAUDE_NOTIFY_PUSHOVER_USER:-}"
    local api_token="${CLAUDE_NOTIFY_PUSHOVER_TOKEN:-}"

    if [[ -z "$user_key" || -z "$api_token" ]]; then
        # Try to read from config
        if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
            user_key=$(jq -r '.backends.pushover.user_key // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
            api_token=$(jq -r '.backends.pushover.api_token // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
        fi
    fi

    if [[ -z "$user_key" || -z "$api_token" ]]; then
        echo "Error: Pushover credentials not configured" >&2
        return 1
    fi

    local pushover_priority=0
    case "$priority" in
        low) pushover_priority="-1" ;;
        normal) pushover_priority="0" ;;
        critical) pushover_priority="1" ;;
    esac

    curl -s \
        --form-string "token=$api_token" \
        --form-string "user=$user_key" \
        --form-string "title=$title" \
        --form-string "message=$message" \
        --form-string "priority=$pushover_priority" \
        https://api.pushover.net/1/messages.json >/dev/null
}

# Main function
main() {
    load_config

    # Test mode
    if [[ "$TEST_MODE" == true ]]; then
        TYPE="${TYPE:-input}"
        TITLE="${TITLE:-Test Notification}"
        MESSAGE="${MESSAGE:-This is a test notification from Claude Notify}"
    fi

    # Apply presets if type is specified
    if [[ -n "$TYPE" ]]; then
        TITLE="${TITLE:-${PRESET_TITLES[$TYPE]:-Claude Code}}"
        MESSAGE="${MESSAGE:-${PRESET_MESSAGES[$TYPE]:-Notification}}"
        URGENCY="${URGENCY:-${PRESET_URGENCY[$TYPE]:-normal}}"
        if [[ -z "$ICON" ]]; then
            ICON="${PRESET_ICONS[$TYPE]:-}"
        fi
    fi

    # Require title and message
    if [[ -z "$TITLE" || -z "$MESSAGE" ]]; then
        echo "Error: --title and --message are required, or use --type" >&2
        exit 1
    fi

    # Set defaults
    URGENCY="${URGENCY:-$DEFAULT_URGENCY}"

    # Auto-detect backend if needed
    if [[ "$BACKEND" == "auto" ]]; then
        BACKEND=$(detect_backend)
    fi

    # Send notification
    case "$BACKEND" in
        notify-send)
            send_notify_send "$TITLE" "$MESSAGE" "$URGENCY" "$ICON"
            ;;
        osascript)
            send_osascript "$TITLE" "$MESSAGE"
            ;;
        terminal-notifier)
            send_terminal_notifier "$TITLE" "$MESSAGE" "$ICON"
            ;;
        powershell)
            send_powershell "$TITLE" "$MESSAGE"
            ;;
        ntfy)
            send_ntfy "$TITLE" "$MESSAGE" "$URGENCY"
            ;;
        pushover)
            send_pushover "$TITLE" "$MESSAGE" "$URGENCY"
            ;;
        none)
            echo "Warning: No notification backend available" >&2
            exit 0
            ;;
        *)
            echo "Error: Unknown backend: $BACKEND" >&2
            exit 1
            ;;
    esac

    if [[ "$TEST_MODE" == true ]]; then
        echo "Test notification sent via $BACKEND"
    fi
}

main "$@"
