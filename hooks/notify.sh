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

# Error trap: output useful message if script fails unexpectedly
trap 'echo "Error: notify.sh failed at line $LINENO" >&2' ERR

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-notify"
CONFIG_FILE="${CONFIG_DIR}/config.json"
PROJECT_CONFIG_NAME=".claude-notify.json"
VERSION_FILE="${CONFIG_DIR}/.version"

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

declare -A PRESET_CATEGORIES=(
    [input]="im.received"
    [complete]="transfer.complete"
    [error]="im.error"
)

declare -A PRESET_ACTIONS=(
    [input]="view=View in Terminal"
    [complete]="view=View in Terminal"
    [error]="view=View Error"
)

declare -A PRESET_SOUNDS=(
    [input]="default"
    [complete]="false"
    [error]="default"
)

# Parse command line arguments
TYPE=""
TITLE=""
MESSAGE=""
BACKEND=""
URGENCY=""
ICON=""
CATEGORY=""
ACTION=""
SOUND=""
WAIT_FOR_ACTION=false
TEST_MODE=false
VALIDATE_MODE=false
VALIDATE_FILE=""
ATTACHMENT=""

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
        --category|-c)
            CATEGORY="$2"
            shift 2
            ;;
        --action|-a)
            ACTION="$2"
            shift 2
            ;;
        --sound|-s)
            SOUND="${2:-default}"
            shift
            [[ "${1:-}" != -* ]] && shift 2>/dev/null || true
            ;;
        --no-sound)
            SOUND="false"
            shift
            ;;
        --attach)
            ATTACHMENT="$2"
            shift 2
            ;;
        --wait|-w)
            WAIT_FOR_ACTION=true
            shift
            ;;
        --test)
            TEST_MODE=true
            shift
            ;;
        --validate)
            VALIDATE_MODE=true
            if [[ -n "${2:-}" && ! "$2" =~ ^-- ]]; then
                VALIDATE_FILE="$2"
                shift
            fi
            shift
            ;;
        --version|-V)
            if [[ -f "$VERSION_FILE" ]]; then
                echo "Claude Notify v$(cat "$VERSION_FILE" | tr -d '[:space:]')"
            else
                echo "Claude Notify (version unknown - not installed via installer)"
            fi
            exit 0
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
            echo "  --category, -c CAT   Notification category (e.g., im.received)"
            echo "  --action, -a ACTION  Add action button (format: id=Label)"
            echo "  --sound, -s [NAME]   Play notification sound (macOS: sound name)"
            echo "  --no-sound           Disable notification sound"
            echo "  --attach PATH/URL    Attach file or URL to notification (ntfy only)"
            echo "  --wait, -w           Wait for action response (Linux only)"
            echo "  --test               Send a test notification"
            echo "  --validate [FILE]    Validate configuration file and exit"
            echo "  --version, -V        Show version information"
            echo "  --help, -h           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Find project-specific config file (walks up directory tree)
# Security: Only searches within user's home directory to prevent loading
# configs from system directories or other users' directories
find_project_config() {
    local dir="$PWD"
    local home_dir="${HOME:-/}"

    # Ensure we start within home directory for security
    if [[ "$dir" != "$home_dir"* ]]; then
        return 1
    fi

    while [[ "$dir" != "/" && "$dir" == "$home_dir"* ]]; do
        if [[ -f "$dir/$PROJECT_CONFIG_NAME" ]]; then
            echo "$dir/$PROJECT_CONFIG_NAME"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Merge two JSON configs (second takes precedence)
merge_configs() {
    local base="$1"
    local overlay="$2"

    if ! command -v jq &>/dev/null; then
        # Without jq, just use overlay if it exists
        if [[ -f "$overlay" ]]; then
            cat "$overlay"
        else
            cat "$base"
        fi
        return
    fi

    # Deep merge: overlay values take precedence
    jq -s '.[0] * .[1]' "$base" "$overlay" 2>/dev/null
}

# Validate configuration file
validate_config() {
    local config_file="$1"
    local errors=()

    if [[ ! -f "$config_file" ]]; then
        echo "Config file not found: $config_file"
        return 1
    fi

    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        echo "Warning: jq not installed, skipping config validation"
        return 0
    fi

    # Validate JSON syntax
    if ! jq '.' "$config_file" &>/dev/null; then
        echo "Invalid JSON syntax in $config_file"
        return 1
    fi

    # Validate backend value
    local backend
    backend=$(jq -r '.backend // "auto"' "$config_file" 2>/dev/null)
    local valid_backends="auto notify-send osascript terminal-notifier powershell ntfy pushover"
    if [[ ! " $valid_backends " =~ " $backend " ]]; then
        errors+=("Invalid backend '$backend'. Valid: $valid_backends")
    fi

    # Validate urgency levels in notifications
    local urgency_fields=("input_needed" "task_complete" "error")
    local valid_urgencies="low normal critical"
    for field in "${urgency_fields[@]}"; do
        local urgency
        urgency=$(jq -r ".notifications.${field}.urgency // \"normal\"" "$config_file" 2>/dev/null)
        if [[ -n "$urgency" && ! " $valid_urgencies " =~ " $urgency " ]]; then
            errors+=("Invalid urgency '$urgency' in notifications.${field}. Valid: $valid_urgencies")
        fi
    done

    # Validate quiet hours format (HH:MM)
    local quiet_start quiet_end
    quiet_start=$(jq -r '.quiet_hours.start // ""' "$config_file" 2>/dev/null)
    quiet_end=$(jq -r '.quiet_hours.end // ""' "$config_file" 2>/dev/null)
    local time_regex='^([01][0-9]|2[0-3]):[0-5][0-9]$'
    if [[ -n "$quiet_start" && ! "$quiet_start" =~ $time_regex ]]; then
        errors+=("Invalid quiet_hours.start format '$quiet_start'. Use HH:MM (24-hour)")
    fi
    if [[ -n "$quiet_end" && ! "$quiet_end" =~ $time_regex ]]; then
        errors+=("Invalid quiet_hours.end format '$quiet_end'. Use HH:MM (24-hour)")
    fi

    # Validate ntfy priority
    local ntfy_priority
    ntfy_priority=$(jq -r '.backends.ntfy.priority // "default"' "$config_file" 2>/dev/null)
    local valid_ntfy_priorities="min low default high max urgent"
    if [[ -n "$ntfy_priority" && ! " $valid_ntfy_priorities " =~ " $ntfy_priority " ]]; then
        errors+=("Invalid ntfy priority '$ntfy_priority'. Valid: $valid_ntfy_priorities")
    fi

    # Validate pushover priority (-2 to 2)
    local pushover_priority
    pushover_priority=$(jq -r '.backends.pushover.priority // 0' "$config_file" 2>/dev/null)
    if [[ "$pushover_priority" =~ ^-?[0-9]+$ ]]; then
        if (( pushover_priority < -2 || pushover_priority > 2 )); then
            errors+=("Invalid pushover priority '$pushover_priority'. Must be between -2 and 2")
        fi
    fi

    # Report errors
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "Configuration errors in $config_file:"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
        return 1
    fi

    return 0
}

# Load configuration
load_config() {
    local effective_config=""
    local project_config=""

    # Initialize config variables to prevent unset variable errors
    CONFIG_BACKEND=""
    CONFIG_ICON=""

    # Check for project-specific config
    project_config=$(find_project_config 2>/dev/null || echo "")

    # Check if jq is available
    if command -v jq &>/dev/null; then
        # Determine effective config (merge global + project)
        if [[ -f "$CONFIG_FILE" && -n "$project_config" && -f "$project_config" ]]; then
            # Merge global and project configs
            effective_config=$(merge_configs "$CONFIG_FILE" "$project_config")
        elif [[ -n "$project_config" && -f "$project_config" ]]; then
            effective_config=$(cat "$project_config")
        elif [[ -f "$CONFIG_FILE" ]]; then
            effective_config=$(cat "$CONFIG_FILE")
        fi

        if [[ -n "$effective_config" ]]; then
            CONFIG_BACKEND=$(echo "$effective_config" | jq -r '.backend // "auto"' 2>/dev/null || echo "auto")
            CONFIG_ICON=$(echo "$effective_config" | jq -r '.icon // ""' 2>/dev/null || echo "")

            # Load notification-specific settings if type is set
            if [[ -n "$TYPE" ]]; then
                local type_enabled=$(echo "$effective_config" | jq -r ".notifications.${TYPE}_needed.enabled // .notifications.task_${TYPE}.enabled // true" 2>/dev/null || echo "true")
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
    local category="${5:-}"
    local action="${6:-}"
    local wait_for_action="${7:-false}"

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

    # Add notification category/hint
    if [[ -n "$category" ]]; then
        args+=("--category=$category")
    fi

    # Add action buttons (only if waiting, since --action blocks)
    if [[ "$wait_for_action" == true ]]; then
        if [[ -n "$action" ]]; then
            args+=("--action=$action")
        fi
        args+=("--wait")
    fi

    args+=("--app-name=Claude Code")
    args+=("$title")
    args+=("$message")

    local result
    if ! result=$(notify-send "${args[@]}" 2>&1); then
        echo "notify-send failed: ${result:-unknown error}" >&2
        return 1
    fi

    # Return the clicked action (if any)
    if [[ -n "$result" ]]; then
        echo "$result"
    fi
}

# Escape string for safe use in AppleScript
# Prevents command injection via malicious input
escape_applescript() {
    local str="$1"
    # Escape backslashes first, then double quotes
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    echo "$str"
}

# Send notification via osascript (macOS)
send_osascript() {
    local title="$1"
    local message="$2"
    local subtitle="${3:-}"
    local sound="${4:-}"

    # Escape all user-provided strings to prevent command injection
    local safe_title safe_message safe_subtitle safe_sound
    safe_title=$(escape_applescript "$title")
    safe_message=$(escape_applescript "$message")

    local script="display notification \"$safe_message\" with title \"$safe_title\""

    # Add subtitle if provided
    if [[ -n "$subtitle" ]]; then
        safe_subtitle=$(escape_applescript "$subtitle")
        script="$script subtitle \"$safe_subtitle\""
    fi

    # Add sound if requested
    if [[ -n "$sound" && "$sound" != "false" ]]; then
        # Use default sound or specified sound name
        if [[ "$sound" == "true" || "$sound" == "default" ]]; then
            script="$script sound name \"default\""
        else
            safe_sound=$(escape_applescript "$sound")
            script="$script sound name \"$safe_sound\""
        fi
    fi

    osascript -e "$script"
}

# Send notification via terminal-notifier (macOS)
send_terminal_notifier() {
    local title="$1"
    local message="$2"
    local icon="${3:-}"
    local subtitle="${4:-}"
    local sound="${5:-}"
    local action_label="${6:-}"

    local args=()
    args+=("-title" "$title")
    args+=("-message" "$message")
    args+=("-group" "claude-notify")
    args+=("-sender" "com.anthropic.claude-code")

    # Add subtitle if provided
    if [[ -n "$subtitle" ]]; then
        args+=("-subtitle" "$subtitle")
    fi

    # Add icon if specified and exists
    if [[ -n "$icon" ]]; then
        local expanded_icon=$(expand_path "$icon")
        if [[ -f "$expanded_icon" ]]; then
            # Use appIcon for .icns files, contentImage for others
            if [[ "$expanded_icon" == *.icns ]]; then
                args+=("-appIcon" "$expanded_icon")
            else
                args+=("-contentImage" "$expanded_icon")
            fi
        fi
    fi

    # Add sound if requested
    if [[ -n "$sound" && "$sound" != "false" ]]; then
        if [[ "$sound" == "true" ]]; then
            args+=("-sound" "default")
        else
            args+=("-sound" "$sound")
        fi
    fi

    # Add action button if specified
    if [[ -n "$action_label" ]]; then
        args+=("-actions" "$action_label")
    fi

    # Execute and capture result (clicked action)
    local result
    if ! result=$(terminal-notifier "${args[@]}" 2>&1); then
        echo "terminal-notifier failed: ${result:-unknown error}" >&2
        return 1
    fi

    if [[ -n "$result" ]]; then
        echo "$result"
    fi
}

# Escape string for safe use in XML
# Prevents XML injection via malicious input
escape_xml() {
    local str="$1"
    str="${str//&/&amp;}"
    str="${str//</&lt;}"
    str="${str//>/&gt;}"
    str="${str//\"/&quot;}"
    str="${str//\'/&apos;}"
    echo "$str"
}

# Sanitize string for safe use in HTTP headers
# Prevents HTTP header injection via newlines and control characters
sanitize_http_header() {
    local str="$1"
    # Remove carriage returns, newlines, and other control characters
    str="${str//$'\r'/}"
    str="${str//$'\n'/ }"
    # Remove null bytes
    str="${str//$'\0'/}"
    echo "$str"
}

# Send notification via PowerShell (Windows)
send_powershell() {
    local title="$1"
    local message="$2"

    # Escape for XML to prevent injection
    local safe_title safe_message
    safe_title=$(escape_xml "$title")
    safe_message=$(escape_xml "$message")

    powershell.exe -Command "
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        \$template = @\"
        <toast>
            <visual>
                <binding template=\"ToastText02\">
                    <text id=\"1\">$safe_title</text>
                    <text id=\"2\">$safe_message</text>
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
    local notification_type="${4:-}"
    local attachment="${5:-}"

    local server="${CLAUDE_NOTIFY_NTFY_SERVER:-https://ntfy.sh}"
    local topic="${CLAUDE_NOTIFY_NTFY_TOPIC:-}"
    local tags="${CLAUDE_NOTIFY_NTFY_TAGS:-}"
    local click_url="${CLAUDE_NOTIFY_NTFY_CLICK:-}"
    local actions="${CLAUDE_NOTIFY_NTFY_ACTIONS:-}"
    local auth_token="${CLAUDE_NOTIFY_NTFY_TOKEN:-}"

    # Try to read from config
    if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
        [[ -z "$topic" ]] && topic=$(jq -r '.backends.ntfy.topic // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
        [[ -z "$server" || "$server" == "https://ntfy.sh" ]] && server=$(jq -r '.backends.ntfy.server // "https://ntfy.sh"' "$CONFIG_FILE" 2>/dev/null || echo "$server")
        [[ -z "$tags" ]] && tags=$(jq -r '.backends.ntfy.tags // "robot"' "$CONFIG_FILE" 2>/dev/null || echo "robot")
        [[ -z "$click_url" ]] && click_url=$(jq -r '.backends.ntfy.click // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
        [[ -z "$actions" ]] && actions=$(jq -r '.backends.ntfy.actions // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
        [[ -z "$auth_token" ]] && auth_token=$(jq -r '.backends.ntfy.token // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
    fi

    if [[ -z "$topic" ]]; then
        echo "Error: ntfy topic not configured" >&2
        return 1
    fi

    # Map urgency to ntfy priority
    local ntfy_priority="default"
    case "$priority" in
        low) ntfy_priority="low" ;;
        normal) ntfy_priority="default" ;;
        critical) ntfy_priority="urgent" ;;
    esac

    # Override priority from config if specified
    if [[ -f "$CONFIG_FILE" ]] && command -v jq &>/dev/null; then
        local config_priority
        config_priority=$(jq -r '.backends.ntfy.priority // ""' "$CONFIG_FILE" 2>/dev/null || echo "")
        if [[ -n "$config_priority" && "$config_priority" != "default" ]]; then
            ntfy_priority="$config_priority"
        fi
    fi

    # Add notification-type-specific tags
    local type_tags=""
    case "$notification_type" in
        input) type_tags="question,bell" ;;
        complete) type_tags="white_check_mark" ;;
        error) type_tags="warning,exclamation" ;;
    esac

    # Combine tags (config tags + type-specific tags)
    local final_tags="$tags"
    if [[ -n "$type_tags" ]]; then
        if [[ -n "$final_tags" ]]; then
            final_tags="${final_tags},${type_tags}"
        else
            final_tags="$type_tags"
        fi
    fi

    # Sanitize all header values to prevent HTTP header injection
    local safe_title safe_tags safe_click safe_actions
    safe_title=$(sanitize_http_header "$title")
    safe_tags=$(sanitize_http_header "$final_tags")
    safe_click=$(sanitize_http_header "$click_url")
    safe_actions=$(sanitize_http_header "$actions")

    # Build curl arguments
    local curl_args=()
    curl_args+=(-s)
    curl_args+=(-H "Title: $safe_title")
    curl_args+=(-H "Priority: $ntfy_priority")

    if [[ -n "$safe_tags" ]]; then
        curl_args+=(-H "Tags: $safe_tags")
    fi

    # Add click action (opens URL when notification is clicked)
    if [[ -n "$safe_click" ]]; then
        curl_args+=(-H "Click: $safe_click")
    fi

    # Add action buttons
    # Format: "action=view, Open Terminal, http://...; action=http, View Logs, http://..."
    if [[ -n "$safe_actions" ]]; then
        curl_args+=(-H "Actions: $safe_actions")
    fi

    # Add attachment if specified
    if [[ -n "$attachment" ]]; then
        if [[ "$attachment" =~ ^https?:// ]]; then
            # URL attachment
            curl_args+=(-H "Attach: $attachment")
        elif [[ -f "$attachment" ]]; then
            # File attachment - use filename header and send file contents
            local filename
            filename=$(basename "$attachment")
            curl_args+=(-H "Filename: $filename")
            curl_args+=(-T "$attachment")
        fi
    fi

    # Add authentication if token is provided
    if [[ -n "$auth_token" ]]; then
        curl_args+=(-H "Authorization: Bearer $auth_token")
    fi

    # Send notification
    if [[ -n "$attachment" && -f "$attachment" ]]; then
        # File upload mode - message goes in header
        curl_args+=(-H "Message: $message")
        curl "${curl_args[@]}" "${server}/${topic}" >/dev/null
    else
        # Standard mode - message in body
        curl_args+=(-d "$message")
        curl "${curl_args[@]}" "${server}/${topic}" >/dev/null
    fi
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
    # Validate mode - just validate config and exit
    if [[ "$VALIDATE_MODE" == true ]]; then
        local file_to_validate="${VALIDATE_FILE:-$CONFIG_FILE}"
        if [[ -f "$file_to_validate" ]]; then
            if validate_config "$file_to_validate"; then
                echo "Configuration is valid: $file_to_validate"
                exit 0
            else
                exit 1
            fi
        else
            echo "No configuration file found at $file_to_validate"
            echo "Using default settings."
            exit 0
        fi
    fi

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
        if [[ -z "$CATEGORY" ]]; then
            CATEGORY="${PRESET_CATEGORIES[$TYPE]:-}"
        fi
        if [[ -z "$ACTION" ]]; then
            ACTION="${PRESET_ACTIONS[$TYPE]:-}"
        fi
        if [[ -z "$SOUND" ]]; then
            SOUND="${PRESET_SOUNDS[$TYPE]:-}"
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
            send_notify_send "$TITLE" "$MESSAGE" "$URGENCY" "$ICON" "$CATEGORY" "$ACTION" "$WAIT_FOR_ACTION"
            ;;
        osascript)
            send_osascript "$TITLE" "$MESSAGE" "" "$SOUND"
            ;;
        terminal-notifier)
            send_terminal_notifier "$TITLE" "$MESSAGE" "$ICON" "" "$SOUND" "$ACTION"
            ;;
        powershell)
            send_powershell "$TITLE" "$MESSAGE"
            ;;
        ntfy)
            send_ntfy "$TITLE" "$MESSAGE" "$URGENCY" "$TYPE" "$ATTACHMENT"
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
