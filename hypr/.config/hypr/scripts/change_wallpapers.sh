#!/usr/bin/env bash

###########################################
### HYPRLAND WALLPAPER CHANGER SCRIPT ###
###########################################

# Load wallpaper settings if available
SETTINGS_FILE="$HOME/.config/hypr/configs/appearance/wallpaper-settings.conf"
if [ -f "$SETTINGS_FILE" ]; then
    source "$SETTINGS_FILE"
fi

# Default wallpapers directory (can be overridden by settings file)
WALLPAPERS_DIR="${WALLPAPERS_DIR:-$HOME/Pictures/Wallpapers}"

# Supported image formats
FORMATS="jpg,jpeg,png,webp,bmp"

# Function to log messages
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Function to check if hyprpaper is running
check_hyprpaper() {
    if ! pgrep -x "hyprpaper" > /dev/null; then
        log "❌ hyprpaper is not running! Starting hyprpaper..."
        hyprpaper &
        sleep 2
    fi
}

# Function to get random wallpaper
get_random_wallpaper() {
    local wallpapers=()
    
    # Find all supported image files
    while IFS= read -r -d '' file; do
        wallpapers+=("$file")
    done < <(find "$WALLPAPERS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) -print0 2>/dev/null)
    
    if [ ${#wallpapers[@]} -eq 0 ]; then
        log "❌ No wallpapers found in $WALLPAPERS_DIR"
        exit 1
    fi
    
    # Get current wallpaper to avoid setting the same one
    local current_wall=$(hyprctl hyprpaper listloaded 2>/dev/null || echo "")
    
    # Select random wallpaper that's different from current
    local attempts=0
    local wallpaper=""
    while [ $attempts -lt 10 ]; do
        local random_index=$((RANDOM % ${#wallpapers[@]}))
        wallpaper="${wallpapers[$random_index]}"
        
        # If different from current or we've tried too many times, use it
        if [ "$wallpaper" != "$current_wall" ] || [ $attempts -ge 5 ]; then
            break
        fi
        ((attempts++))
    done
    
    echo "$wallpaper"
}

# Function to change wallpaper using the new reload method
change_wallpaper() {
    local wallpaper="$1"
    local monitor="${2:-all}"
    
    if [ ! -f "$wallpaper" ]; then
        log "❌ Wallpaper file not found: $wallpaper"
        return 1
    fi
    
    log "🎨 Changing wallpaper to: $(basename "$wallpaper")"
    
    # Use the new reload method which is more efficient
    if [ "$monitor" = "all" ]; then
        log "🖥️ Setting wallpaper on all monitors using reload..."
        if hyprctl hyprpaper reload ",$wallpaper"; then
            log "✅ Wallpaper changed successfully!"
        else
            log "❌ Failed to change wallpaper using reload method, trying legacy method..."
            # Fallback to legacy method
            change_wallpaper_legacy "$wallpaper" "$monitor"
        fi
    else
        log "🖥️ Setting wallpaper on monitor: $monitor using reload..."
        if hyprctl hyprpaper reload "$monitor,$wallpaper"; then
            log "✅ Wallpaper changed successfully!"
        else
            log "❌ Failed to change wallpaper using reload method, trying legacy method..."
            # Fallback to legacy method
            change_wallpaper_legacy "$wallpaper" "$monitor"
        fi
    fi
}

# Legacy wallpaper change method (backup)
change_wallpaper_legacy() {
    local wallpaper="$1"
    local monitor="${2:-all}"
    
    log "📥 Using legacy method: Preloading wallpaper..."
    if ! hyprctl hyprpaper preload "$wallpaper"; then
        log "❌ Failed to preload wallpaper"
        return 1
    fi
    
    # Wait a bit for preload to complete
    sleep 0.5
    
    # Set wallpaper
    if [ "$monitor" = "all" ]; then
        log "🖥️ Setting wallpaper on all monitors..."
        hyprctl hyprpaper wallpaper ",$wallpaper"
    else
        log "🖥️ Setting wallpaper on monitor: $monitor"
        hyprctl hyprpaper wallpaper "$monitor,$wallpaper"
    fi
    
    # Wait a bit for wallpaper to be set
    sleep 0.5
    
    # Clean up unused wallpapers
    log "🧹 Cleaning up unused wallpapers..."
    hyprctl hyprpaper unload unused
    
    log "✅ Wallpaper changed successfully!"
}

# Function to list available wallpapers
list_wallpapers() {
    log "📁 Available wallpapers in $WALLPAPERS_DIR:"
    find "$WALLPAPERS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) -printf "%f\n" 2>/dev/null | sort
}

# Function to show usage
show_usage() {
    cat << EOF
🎨 Hyprland Wallpaper Changer

Usage: $0 [OPTIONS] [WALLPAPER_PATH]

OPTIONS:
    -r, --random           Set random wallpaper (default)
    -l, --list             List available wallpapers
    -m, --monitor MONITOR  Set wallpaper for specific monitor (e.g., DP-1, HDMI-A-1)
    -h, --help             Show this help message

EXAMPLES:
    $0                                    # Set random wallpaper on all monitors
    $0 -r                                 # Set random wallpaper on all monitors
    $0 -m DP-1                           # Set random wallpaper on DP-1 monitor
    $0 ~/Pictures/my_wallpaper.png       # Set specific wallpaper on all monitors
    $0 -m HDMI-A-1 ~/Pictures/wall.jpg  # Set specific wallpaper on HDMI-A-1

DIRECTORY: $WALLPAPERS_DIR
EOF
}

# Main script logic
main() {
    local monitor="all"
    local wallpaper=""
    local action="random"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--random)
                action="random"
                shift
                ;;
            -l|--list)
                list_wallpapers
                exit 0
                ;;
            -m|--monitor)
                monitor="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log "❌ Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                wallpaper="$1"
                action="specific"
                shift
                ;;
        esac
    done
    
    # Check if wallpapers directory exists
    if [ ! -d "$WALLPAPERS_DIR" ]; then
        log "❌ Wallpapers directory not found: $WALLPAPERS_DIR"
        log "💡 Please create the directory and add some wallpapers"
        exit 1
    fi
    
    # Check hyprpaper
    check_hyprpaper
    
    # Execute action
    case $action in
        "random")
            wallpaper=$(get_random_wallpaper)
            change_wallpaper "$wallpaper" "$monitor"
            ;;
        "specific")
            if [ -z "$wallpaper" ]; then
                log "❌ No wallpaper specified"
                show_usage
                exit 1
            fi
            change_wallpaper "$wallpaper" "$monitor"
            ;;
    esac
}

# Run main function
main "$@"
