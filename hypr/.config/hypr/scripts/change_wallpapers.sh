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

# Default settings (can be overridden by settings file)
WALLPAPER_HISTORY_SIZE="${WALLPAPER_HISTORY_SIZE:-20}"
RANDOMIZATION_METHOD="${RANDOMIZATION_METHOD:-smart}"
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/hypr}"
HISTORY_FILE="${HISTORY_FILE:-$CACHE_DIR/wallpaper_history}"
VALIDATE_IMAGE_FILES="${VALIDATE_IMAGE_FILES:-true}"
CACHE_VALID_WALLPAPERS="${CACHE_VALID_WALLPAPERS:-true}"
NEVER_USED_WEIGHT="${NEVER_USED_WEIGHT:-10}"
OLD_WALLPAPER_WEIGHT="${OLD_WALLPAPER_WEIGHT:-5}"
RECENT_WALLPAPER_WEIGHT="${RECENT_WALLPAPER_WEIGHT:-1}"

# Supported image formats
FORMATS="jpg,jpeg,png,webp,bmp"

# Initialize cache directory
mkdir -p "$CACHE_DIR"

# Function to log messages
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Function to generate secure random number using urandom
secure_random() {
    local max="${1:-32767}"
    if [ "$max" -le 1 ]; then
        echo 0
        return
    fi
    
    # Use /dev/urandom for better randomness
    local random_bytes
    random_bytes=$(od -An -N4 -tu4 < /dev/urandom | tr -d ' ')
    echo $((random_bytes % max))
}

# Function to shuffle array using Fisher-Yates algorithm
shuffle_array() {
    local -n arr=$1
    local i j temp
    
    for ((i=${#arr[@]}-1; i>0; i--)); do
        j=$(secure_random $((i+1)))
        # Swap elements
        temp="${arr[i]}"
        arr[i]="${arr[j]}"
        arr[j]="$temp"
    done
}

# Function to validate image file
validate_image() {
    local file="$1"
    
    if [ "$VALIDATE_IMAGE_FILES" != "true" ]; then
        return 0
    fi
    
    # Check if file exists and is readable
    if [ ! -r "$file" ]; then
        return 1
    fi
    
    # Check file size (should be > 1KB for valid image)
    local file_size
    file_size=$(stat -c%s "$file" 2>/dev/null)
    if [ -z "$file_size" ] || [ "$file_size" -lt 1024 ]; then
        return 1
    fi
    
    # Basic file type validation using file command
    local file_type
    file_type=$(file -b --mime-type "$file" 2>/dev/null)
    case "$file_type" in
        image/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to get all valid wallpapers
get_valid_wallpapers() {
    local cache_file="$CACHE_DIR/valid_wallpapers_cache"
    local wallpapers=()
    
    # Check if cache exists and is recent (less than 1 hour old)
    if [ "$CACHE_VALID_WALLPAPERS" = "true" ] && [ -f "$cache_file" ]; then
        local cache_age file_mtime
        file_mtime=$(stat -c%Y "$cache_file" 2>/dev/null)
        if [ -n "$file_mtime" ]; then
            cache_age=$(($(date +%s) - file_mtime))
            if [ "$cache_age" -lt 3600 ]; then
                mapfile -t wallpapers < "$cache_file"
                if [ ${#wallpapers[@]} -gt 0 ]; then
                    printf '%s\n' "${wallpapers[@]}"
                    return 0
                fi
            fi
        fi
    fi
    
    # Find and validate all wallpaper files
    log "🔍 Scanning for valid wallpapers..."
    local total_found=0
    local valid_count=0
    
    while IFS= read -r -d '' file; do
        ((total_found++))
        if validate_image "$file"; then
            wallpapers+=("$file")
            ((valid_count++))
        fi
    done < <(find "$WALLPAPERS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) -print0 2>/dev/null)
    
    log "📊 Found $valid_count valid wallpapers out of $total_found total files"
    
    if [ ${#wallpapers[@]} -eq 0 ]; then
        log "❌ No valid wallpapers found in $WALLPAPERS_DIR"
        return 1
    fi
    
    # Cache the results if enabled
    if [ "$CACHE_VALID_WALLPAPERS" = "true" ]; then
        printf '%s\n' "${wallpapers[@]}" > "$cache_file"
    fi
    
    printf '%s\n' "${wallpapers[@]}"
}

# Function to get wallpaper history
get_wallpaper_history() {
    if [ -f "$HISTORY_FILE" ]; then
        head -n "$WALLPAPER_HISTORY_SIZE" "$HISTORY_FILE"
    fi
}

# Function to add wallpaper to history
add_to_history() {
    local wallpaper="$1"
    local temp_file="$HISTORY_FILE.tmp"
    
    # Add new wallpaper to top of history
    echo "$wallpaper" > "$temp_file"
    
    # Add existing history (excluding the new wallpaper if it exists)
    if [ -f "$HISTORY_FILE" ]; then
        grep -v "^$wallpaper$" "$HISTORY_FILE" | head -n $((WALLPAPER_HISTORY_SIZE - 1)) >> "$temp_file"
    fi
    
    mv "$temp_file" "$HISTORY_FILE"
}

# Function to check if wallpaper is in recent history
is_in_recent_history() {
    local wallpaper="$1"
    local history
    history=$(get_wallpaper_history)
    
    if [ -z "$history" ]; then
        return 1
    fi
    
    echo "$history" | grep -q "^$wallpaper$"
}

# Function to get current wallpaper
get_current_wallpaper() {
    # Try multiple methods to get current wallpaper
    local current=""
    
    # Method 1: Get from history file (most recent)
    if [ -f "$HISTORY_FILE" ]; then
        current=$(head -n 1 "$HISTORY_FILE" 2>/dev/null)
        if [ -n "$current" ] && [ -f "$current" ]; then
            echo "$current"
            return 0
        fi
    fi
    
    # Method 2: Try hyprctl (may not always work reliably)
    current=$(hyprctl hyprpaper listloaded 2>/dev/null | head -n 1)
    if [ -n "$current" ] && [ -f "$current" ]; then
        echo "$current"
        return 0
    fi
    
    # Method 3: Check hyprpaper config
    local hyprpaper_conf="$HOME/.config/hypr/hyprpaper.conf"
    if [ -f "$hyprpaper_conf" ]; then
        current=$(grep "wallpaper.*=" "$hyprpaper_conf" | tail -n 1 | sed 's/.*=.*,//' | tr -d ' ')
        if [ -n "$current" ] && [ -f "$current" ]; then
            echo "$current"
            return 0
        fi
    fi
    
    echo ""
}

# Function to get weighted random wallpaper (smart method)
get_smart_random_wallpaper() {
    local wallpapers=()
    mapfile -t wallpapers < <(get_valid_wallpapers)
    
    if [ ${#wallpapers[@]} -eq 0 ]; then
        return 1
    fi
    
    local history
    history=$(get_wallpaper_history)
    local current_wallpaper
    current_wallpaper=$(get_current_wallpaper)
    
    # Create weighted list
    local weighted_wallpapers=()
    local never_used=()
    local old_wallpapers=()
    
    for wallpaper in "${wallpapers[@]}"; do
        # Skip current wallpaper
        if [ "$wallpaper" = "$current_wallpaper" ]; then
            continue
        fi
        
        if echo "$history" | grep -q "^$wallpaper$"; then
            # Recently used - add with low weight
            for ((i=0; i<RECENT_WALLPAPER_WEIGHT; i++)); do
                weighted_wallpapers+=("$wallpaper")
            done
        elif [ -n "$history" ] && ! echo "$history" | grep -q "^$wallpaper$"; then
            # Used before but not recently - add with medium weight
            for ((i=0; i<OLD_WALLPAPER_WEIGHT; i++)); do
                weighted_wallpapers+=("$wallpaper")
            done
            old_wallpapers+=("$wallpaper")
        else
            # Never used - add with high weight
            for ((i=0; i<NEVER_USED_WEIGHT; i++)); do
                weighted_wallpapers+=("$wallpaper")
            done
            never_used+=("$wallpaper")
        fi
    done
    
    if [ ${#weighted_wallpapers[@]} -eq 0 ]; then
        # Fallback: use pure random if no weighted options
        local random_index
        random_index=$(secure_random ${#wallpapers[@]})
        echo "${wallpapers[$random_index]}"
        return 0
    fi
    
    # Select random wallpaper from weighted list
    local random_index
    random_index=$(secure_random ${#weighted_wallpapers[@]})
    local selected="${weighted_wallpapers[$random_index]}"
    
    # Log selection info (to stderr to avoid polluting return value)
    local history_count=0
    if [ -n "$history" ]; then
        history_count=$(echo "$history" | wc -l)
    fi
    log "🎯 Selection stats: ${#never_used[@]} never used, ${#old_wallpapers[@]} old, $history_count recent" >&2
    log "🎲 Selected from ${#weighted_wallpapers[@]} weighted options" >&2
    
    echo "$selected"
}

# Function to get pure random wallpaper
get_pure_random_wallpaper() {
    local wallpapers=()
    mapfile -t wallpapers < <(get_valid_wallpapers)
    
    if [ ${#wallpapers[@]} -eq 0 ]; then
        return 1
    fi
    
    local current_wallpaper
    current_wallpaper=$(get_current_wallpaper)
    
    # Remove current wallpaper from options if avoiding duplicates
    if [ "$AVOID_DUPLICATE_WALLPAPERS" = "true" ] && [ -n "$current_wallpaper" ]; then
        local filtered_wallpapers=()
        for wallpaper in "${wallpapers[@]}"; do
            if [ "$wallpaper" != "$current_wallpaper" ]; then
                filtered_wallpapers+=("$wallpaper")
            fi
        done
        wallpapers=("${filtered_wallpapers[@]}")
    fi
    
    if [ ${#wallpapers[@]} -eq 0 ]; then
        log "⚠️ All wallpapers filtered out, using original list" >&2
        mapfile -t wallpapers < <(get_valid_wallpapers)
    fi
    
    # Shuffle array for extra randomness
    shuffle_array wallpapers
    
    # Select random wallpaper
    local random_index
    random_index=$(secure_random ${#wallpapers[@]})
    echo "${wallpapers[$random_index]}"
}

# Function to get random wallpaper (main entry point)
get_random_wallpaper() {
    local wallpaper
    
    case "$RANDOMIZATION_METHOD" in
        "smart")
            wallpaper=$(get_smart_random_wallpaper)
            ;;
        "pure")
            wallpaper=$(get_pure_random_wallpaper)
            ;;
        *)
            log "⚠️ Unknown randomization method: $RANDOMIZATION_METHOD, using smart"
            wallpaper=$(get_smart_random_wallpaper)
            ;;
    esac
    
    if [ -z "$wallpaper" ]; then
        log "❌ Failed to select wallpaper"
        return 1
    fi
    
    echo "$wallpaper"
}

# Function to check if hyprpaper is running
check_hyprpaper() {
    if ! pgrep -x "hyprpaper" > /dev/null; then
        log "❌ hyprpaper is not running! Starting hyprpaper..."
        hyprpaper &
        sleep 2
    fi
}

# Function to change wallpaper using the new reload method
change_wallpaper() {
    local wallpaper="$1"
    local monitor="${2:-all}"
    
    if [ ! -f "$wallpaper" ]; then
        log "❌ Wallpaper file not found: $wallpaper"
        return 1
    fi
    
    local wallpaper_name
    wallpaper_name=$(basename "$wallpaper")
    log "🎨 Changing wallpaper to: $wallpaper_name"
    
    # Add to history before changing
    add_to_history "$wallpaper"
    
    # Use the new reload method which is more efficient
    if [ "$monitor" = "all" ]; then
        log "🖥️ Setting wallpaper on all monitors using reload..."
        if hyprctl hyprpaper reload ",$wallpaper"; then
            log "✅ Wallpaper changed successfully to: $wallpaper_name"
            return 0
        else
            log "❌ Failed to change wallpaper using reload method, trying legacy method..."
            # Fallback to legacy method
            change_wallpaper_legacy "$wallpaper" "$monitor"
            return $?
        fi
    else
        log "🖥️ Setting wallpaper on monitor: $monitor using reload..."
        if hyprctl hyprpaper reload "$monitor,$wallpaper"; then
            log "✅ Wallpaper changed successfully to: $wallpaper_name"
            return 0
        else
            log "❌ Failed to change wallpaper using reload method, trying legacy method..."
            # Fallback to legacy method
            change_wallpaper_legacy "$wallpaper" "$monitor"
            return $?
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
    
    local wallpapers=()
    mapfile -t wallpapers < <(get_valid_wallpapers)
    
    if [ ${#wallpapers[@]} -eq 0 ]; then
        log "❌ No valid wallpapers found"
        return 1
    fi
    
    # Show statistics
    local history
    history=$(get_wallpaper_history)
    local history_count
    history_count=$(echo "$history" | grep -c .)
    local never_used=0
    
    for wallpaper in "${wallpapers[@]}"; do
        if ! echo "$history" | grep -q "^$wallpaper$"; then
            ((never_used++))
        fi
    done
    
    log "📊 Total: ${#wallpapers[@]} wallpapers | Recent: $history_count | Never used: $never_used"
    echo ""
    
    # List wallpapers with status
    local current_wallpaper
    current_wallpaper=$(get_current_wallpaper)
    
    for wallpaper in "${wallpapers[@]}"; do
        local basename_wall
        basename_wall=$(basename "$wallpaper")
        local status=""
        
        if [ "$wallpaper" = "$current_wallpaper" ]; then
            status=" [CURRENT]"
        elif echo "$history" | head -n 5 | grep -q "^$wallpaper$"; then
            status=" [RECENT]"
        elif echo "$history" | grep -q "^$wallpaper$"; then
            status=" [USED]"
        else
            status=" [NEW]"
        fi
        
        echo "$basename_wall$status"
    done
}

# Function to show wallpaper statistics
show_stats() {
    log "📊 Wallpaper Statistics:"
    
    local wallpapers=()
    mapfile -t wallpapers < <(get_valid_wallpapers)
    
    if [ ${#wallpapers[@]} -eq 0 ]; then
        log "❌ No valid wallpapers found"
        return 1
    fi
    
    local history
    history=$(get_wallpaper_history)
    local current_wallpaper
    current_wallpaper=$(get_current_wallpaper)
    
    echo "Total wallpapers: ${#wallpapers[@]}"
    echo "History size: $(echo "$history" | grep -c . 2>/dev/null || echo 0)/${WALLPAPER_HISTORY_SIZE}"
    echo "Current wallpaper: $(basename "$current_wallpaper" 2>/dev/null || echo "Unknown")"
    echo "Randomization method: $RANDOMIZATION_METHOD"
    echo "Cache directory: $CACHE_DIR"
    echo ""
    
    # Count by status
    local never_used=0 recent=0 old_used=0
    
    for wallpaper in "${wallpapers[@]}"; do
        if echo "$history" | head -n 5 | grep -q "^$wallpaper$"; then
            ((recent++))
        elif echo "$history" | grep -q "^$wallpaper$"; then
            ((old_used++))
        else
            ((never_used++))
        fi
    done
    
    echo "Distribution:"
    echo "  Never used: $never_used"
    echo "  Recently used (last 5): $recent"
    echo "  Used before: $old_used"
}

# Function to clear wallpaper history
clear_history() {
    if [ -f "$HISTORY_FILE" ]; then
        rm "$HISTORY_FILE"
        log "🗑️ Wallpaper history cleared"
    else
        log "ℹ️ No history file to clear"
    fi
}

# Function to clear cache
clear_cache() {
    local cache_file="$CACHE_DIR/valid_wallpapers_cache"
    if [ -f "$cache_file" ]; then
        rm "$cache_file"
        log "🗑️ Wallpaper cache cleared"
    else
        log "ℹ️ No cache file to clear"
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
🎨 Enhanced Hyprland Wallpaper Changer

Usage: $0 [OPTIONS] [WALLPAPER_PATH]

OPTIONS:
    -r, --random           Set random wallpaper (default)
    -l, --list             List available wallpapers with status
    -s, --stats            Show wallpaper statistics
    -m, --monitor MONITOR  Set wallpaper for specific monitor (e.g., DP-1, HDMI-A-1)
    --pure-random          Use pure random selection (ignore history)
    --smart-random         Use smart random selection (avoid recent)
    --clear-history        Clear wallpaper history
    --clear-cache          Clear wallpaper cache
    --validate             Validate all wallpapers
    -h, --help             Show this help message

EXAMPLES:
    $0                                    # Set smart random wallpaper on all monitors
    $0 -r                                 # Set smart random wallpaper on all monitors
    $0 --pure-random                      # Set completely random wallpaper
    $0 -m DP-1                           # Set random wallpaper on DP-1 monitor
    $0 ~/Pictures/my_wallpaper.png       # Set specific wallpaper on all monitors
    $0 -m HDMI-A-1 ~/Pictures/wall.jpg  # Set specific wallpaper on HDMI-A-1
    $0 -l                                # List all wallpapers with status
    $0 -s                                # Show detailed statistics

CONFIGURATION:
    Directory: $WALLPAPERS_DIR
    Method: $RANDOMIZATION_METHOD
    History size: $WALLPAPER_HISTORY_SIZE
    Cache: $CACHE_DIR

With $WALLPAPER_HISTORY_SIZE recent wallpapers tracked and smart weighting:
  - Never used wallpapers: ${NEVER_USED_WEIGHT}x weight
  - Old wallpapers: ${OLD_WALLPAPER_WEIGHT}x weight  
  - Recent wallpapers: ${RECENT_WALLPAPER_WEIGHT}x weight
EOF
}

# Main script logic
main() {
    local monitor="all"
    local wallpaper=""
    local action="random"
    local force_method=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--random)
                action="random"
                shift
                ;;
            --pure-random)
                action="random"
                force_method="pure"
                shift
                ;;
            --smart-random)
                action="random"
                force_method="smart"
                shift
                ;;
            -l|--list)
                list_wallpapers
                exit 0
                ;;
            -s|--stats)
                show_stats
                exit 0
                ;;
            --clear-history)
                clear_history
                exit 0
                ;;
            --clear-cache)
                clear_cache
                exit 0
                ;;
            --validate)
                log "🔍 Validating all wallpapers..."
                get_valid_wallpapers > /dev/null
                log "✅ Validation complete"
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
    
    # Override randomization method if specified
    if [ -n "$force_method" ]; then
        RANDOMIZATION_METHOD="$force_method"
    fi
    
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
            log "🎲 Using $RANDOMIZATION_METHOD randomization method"
            wallpaper=$(get_random_wallpaper)
            if [ -z "$wallpaper" ]; then
                log "❌ Failed to get random wallpaper"
                exit 1
            fi
            change_wallpaper "$wallpaper" "$monitor"
            ;;
        "specific")
            if [ -z "$wallpaper" ]; then
                log "❌ No wallpaper specified"
                show_usage
                exit 1
            fi
            
            # Validate the specific wallpaper
            if ! validate_image "$wallpaper"; then
                log "❌ Invalid wallpaper file: $wallpaper"
                exit 1
            fi
            
            change_wallpaper "$wallpaper" "$monitor"
            ;;
    esac
}

# Run main function
main "$@"
