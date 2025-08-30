#!/usr/bin/env bash

###########################################
### AUTO WALLPAPER CHANGER SCRIPT     ###
###########################################

# Configuration
WALLPAPERS_DIR="$HOME/Pictures/Wallpapers"
SCRIPT_DIR="$HOME/.config/hypr/scripts"
CHANGE_INTERVAL=300  # 5 minutes in seconds

# Function to log messages
log() {
    echo "[$(date '+%H:%M:%S')] AUTO-WALLPAPER: $1"
}

# Function to check if auto-changer is already running
check_running() {
    local pid_file="/tmp/hypr_auto_wallpaper.pid"
    
    if [ -f "$pid_file" ]; then
        local old_pid=$(cat "$pid_file")
        if kill -0 "$old_pid" 2>/dev/null; then
            log "❌ Auto wallpaper changer is already running (PID: $old_pid)"
            exit 1
        else
            log "🧹 Removing stale PID file"
            rm -f "$pid_file"
        fi
    fi
    
    # Save current PID
    echo $$ > "$pid_file"
}

# Function to cleanup on exit
cleanup() {
    log "🛑 Stopping auto wallpaper changer"
    rm -f "/tmp/hypr_auto_wallpaper.pid"
    exit 0
}

# Function to show usage
show_usage() {
    cat << EOF
🔄 Hyprland Auto Wallpaper Changer

Usage: $0 [OPTIONS]

OPTIONS:
    -i, --interval SECONDS  Change interval in seconds (default: 300)
    -s, --stop             Stop the auto changer
    -h, --help             Show this help message

EXAMPLES:
    $0                     # Start with default 5-minute interval
    $0 -i 600              # Start with 10-minute interval  
    $0 -s                  # Stop auto changer

EOF
}

# Function to stop auto changer
stop_auto_changer() {
    local pid_file="/tmp/hypr_auto_wallpaper.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log "🛑 Stopping auto wallpaper changer (PID: $pid)"
            kill "$pid"
            rm -f "$pid_file"
            log "✅ Auto wallpaper changer stopped"
        else
            log "❌ Auto wallpaper changer is not running"
            rm -f "$pid_file"
        fi
    else
        log "❌ Auto wallpaper changer is not running"
    fi
}

# Main function
main() {
    local action="start"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interval)
                CHANGE_INTERVAL="$2"
                shift 2
                ;;
            -s|--stop)
                action="stop"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log "❌ Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    case $action in
        "stop")
            stop_auto_changer
            exit 0
            ;;
        "start")
            check_running
            
            # Setup signal handlers
            trap cleanup EXIT INT TERM
            
            log "🚀 Starting auto wallpaper changer (interval: ${CHANGE_INTERVAL}s)"
            
            # Main loop
            while true; do
                log "🎨 Changing wallpaper..."
                "$SCRIPT_DIR/change_wallpapers.sh" -r
                
                log "💤 Sleeping for ${CHANGE_INTERVAL} seconds..."
                sleep "$CHANGE_INTERVAL"
            done
            ;;
    esac
}

# Run main function
main "$@"
