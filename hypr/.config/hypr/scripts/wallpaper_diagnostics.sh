#!/usr/bin/env bash

###########################################
### HYPRLAND WALLPAPER DIAGNOSTICS    ###
###########################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "🔍 Hyprland Wallpaper System Diagnostics"
echo "========================================"

# Check if Hyprland is running
if pgrep -x "Hyprland" >/dev/null; then
    print_status "OK" "Hyprland is running"
else
    print_status "ERROR" "Hyprland is not running"
fi

# Check if hyprpaper is running
if pgrep -x "hyprpaper" >/dev/null; then
    print_status "OK" "hyprpaper is running (PID: $(pgrep -x hyprpaper))"
else
    print_status "ERROR" "hyprpaper is not running"
fi

# Check if hyprctl is available
if command_exists hyprctl; then
    print_status "OK" "hyprctl is available"
else
    print_status "ERROR" "hyprctl is not available"
fi

# Check wallpaper directory
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
if [ -d "$WALLPAPER_DIR" ]; then
    wallpaper_count=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) | wc -l)
    if [ $wallpaper_count -gt 0 ]; then
        print_status "OK" "Wallpaper directory exists with $wallpaper_count images"
    else
        print_status "WARNING" "Wallpaper directory exists but no images found"
    fi
else
    print_status "ERROR" "Wallpaper directory not found: $WALLPAPER_DIR"
fi

# Check configuration files
CONFIG_DIR="$HOME/.config/hypr"
files_to_check=(
    "hyprland.conf:Main Hyprland config"
    "configs/appearance/hyprpaper.conf:Hyprpaper config"
    "configs/appearance/wallpaper-settings.conf:Wallpaper settings"
    "scripts/change_wallpapers.sh:Wallpaper change script"
    "scripts/auto_wallpaper.sh:Auto wallpaper script"
)

for file_info in "${files_to_check[@]}"; do
    IFS=':' read -r file desc <<< "$file_info"
    if [ -f "$CONFIG_DIR/$file" ]; then
        print_status "OK" "$desc exists"
    else
        print_status "ERROR" "$desc missing: $CONFIG_DIR/$file"
    fi
done

# Check if scripts are executable
for script in "change_wallpapers.sh" "auto_wallpaper.sh"; do
    script_path="$CONFIG_DIR/scripts/$script"
    if [ -x "$script_path" ]; then
        print_status "OK" "$script is executable"
    else
        print_status "WARNING" "$script is not executable"
    fi
done

echo ""
echo "🖼️  Current Wallpaper Status"
echo "============================"

# Check current loaded wallpapers
if command_exists hyprctl && pgrep -x "hyprpaper" >/dev/null; then
    echo -e "${BLUE}📥 Loaded wallpapers:${NC}"
    hyprctl hyprpaper listloaded 2>/dev/null || print_status "ERROR" "Failed to get loaded wallpapers"
    
    echo -e "${BLUE}🖥️  Active wallpapers:${NC}"
    hyprctl hyprpaper listactive 2>/dev/null || print_status "ERROR" "Failed to get active wallpapers"
    
    echo -e "${BLUE}🖼️  Monitor information:${NC}"
    hyprctl monitors -j 2>/dev/null | jq -r '.[] | "  \(.name): \(.width)x\(.height) @ \(.refreshRate)Hz"' 2>/dev/null || print_status "WARNING" "Failed to get monitor info (jq might be missing)"
else
    print_status "WARNING" "Cannot check wallpaper status (hyprctl or hyprpaper not available)"
fi

echo ""
echo "🔧 Quick Tests"
echo "=============="

# Test wallpaper script
if [ -x "$CONFIG_DIR/scripts/change_wallpapers.sh" ]; then
    print_status "INFO" "Testing wallpaper script help..."
    if "$CONFIG_DIR/scripts/change_wallpapers.sh" -h >/dev/null 2>&1; then
        print_status "OK" "Wallpaper script help works"
    else
        print_status "ERROR" "Wallpaper script help failed"
    fi
else
    print_status "ERROR" "Wallpaper script not executable"
fi

echo ""
echo "📋 Summary"
echo "=========="
print_status "INFO" "Diagnostics complete"
print_status "INFO" "Check the errors and warnings above to fix any issues"
