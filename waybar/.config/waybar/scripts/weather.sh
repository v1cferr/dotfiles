#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
# API Keys locations
WEATHERAPI_KEY_FILE="$HOME/dotfiles/waybar/.config/waybar/scripts/api-keys/weatherapi-key"
CLIMATEMPO_KEY_FILE="$HOME/dotfiles/waybar/.config/waybar/scripts/api-keys/climatempo-api-key"
OPENWEATHER_KEY_FILE="$HOME/dotfiles/waybar/.config/waybar/scripts/api-keys/openweather-api-key"

# Locations and IDs
CITY="São Carlos,SP,Brazil"
CITY_COORDS="-21.9977,-47.8827"  # São Carlos/SP
CLIMATEMPO_ID="3477"             # São Carlos/SP

# Cache
CACHE_FILE="/tmp/weather.json"
CACHE_TTL=3600 # 1 hour validity for cache if network is down

# Debug
DEBUG="${DEBUG:-false}"

# ==============================================================================
# HELPERS
# ==============================================================================
log() {
    if [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Function to map weather conditions to Nerd Font icons
# Based on common API return codes or text
get_icon() {
    local condition_text="${1,,}" # Lowercase
    local condition_code="$2"
    local is_day="$3"             # 1 for day, 0 for night (optional)

    # Defaults
    local icon="󰖐" # Default cloud

    # WeatherAPI & General text matching
    if [[ "$condition_text" == *"sunny"* || "$condition_text" == *"clear"* ]]; then
        if [[ "$is_day" == "0" ]]; then icon=""; else icon=""; fi
    elif [[ "$condition_text" == *"partly cloudy"* ]]; then
        if [[ "$is_day" == "0" ]]; then icon=""; else icon=""; fi
    elif [[ "$condition_text" == *"cloud"* || "$condition_text" == *"overcast"* ]]; then
        icon=""
    elif [[ "$condition_text" == *"mist"* || "$condition_text" == *"fog"* ]]; then
        icon=""
    elif [[ "$condition_text" == *"rain"* || "$condition_text" == *"drizzle"* || "$condition_text" == *"shower"* ]]; then
        icon=""
    elif [[ "$condition_text" == *"thunder"* || "$condition_text" == *"storm"* ]]; then
        icon=""
    elif [[ "$condition_text" == *"snow"* || "$condition_text" == *"blizzard"* || "$condition_text" == *"ice"* ]]; then
        icon=""
    fi

    echo "$icon"
}

# Wrapper for curl with timeout
fetch() {
    curl -s --max-time 5 "$@"
}

write_cache() {
    echo "$1" > "$CACHE_FILE"
}

read_cache() {
    if [[ -f "$CACHE_FILE" ]]; then
        # Check if cache is not too old (optional, for now just read it if it exists)
        cat "$CACHE_FILE"
        return 0
    fi
    return 1
}

format_output() {
    local temp="$1"
    local icon="$2"
    local tooltip="$3"
    local class="${4:-weather}"

    echo "{\"text\": \"$icon $temp\", \"tooltip\": \"$tooltip\", \"class\": \"$class\"}"
}

# ==============================================================================
# API PROVIDERS
# ==============================================================================

# 1. WeatherAPI.com
get_weather_weatherapi() {
    log "Trying WeatherAPI..."
    if [[ ! -f "$WEATHERAPI_KEY_FILE" ]]; then log "WeatherAPI key not found"; return 1; fi
    local api_key; api_key=$(cat "$WEATHERAPI_KEY_FILE")
    
    local response
    response=$(fetch "http://api.weatherapi.com/v1/current.json?key=$api_key&q=$CITY_COORDS&lang=pt")
    
    if echo "$response" | jq -e '.error' >/dev/null; then log "WeatherAPI error"; return 1; fi
    if [[ -z "$response" ]]; then log "WeatherAPI empty response"; return 1; fi

    local temp; temp=$(echo "$response" | jq -r '.current.temp_c')
    local condition; condition=$(echo "$response" | jq -r '.current.condition.text')
    local is_day; is_day=$(echo "$response" | jq -r '.current.is_day')
    local humidity; humidity=$(echo "$response" | jq -r '.current.humidity')
    local wind; wind=$(echo "$response" | jq -r '.current.wind_kph')
    
    local icon; icon=$(get_icon "$condition" "" "$is_day")
    local temp_int; temp_int=$(printf "%.0f" "$temp")
    
    local tooltip="<b>São Carlos/SP</b>\n$condition\nUmidade: $humidity%\nVento: $wind km/h\n(WeatherAPI)"
    local json; json=$(format_output "$temp_int°C" "$icon" "$tooltip")
    
    write_cache "$json"
    echo "$json"
    return 0
}

# 2. Climatempo
get_weather_climatempo() {
    log "Trying Climatempo..."
    if [[ ! -f "$CLIMATEMPO_KEY_FILE" ]]; then log "Climatempo key not found"; return 1; fi
    local api_key; api_key=$(cat "$CLIMATEMPO_KEY_FILE")

    local response
    response=$(fetch "http://apiadvisor.climatempo.com.br/api/v1/weather/locale/$CLIMATEMPO_ID/current?token=$api_key")

    if echo "$response" | jq -e '.error' >/dev/null; then log "Climatempo error"; return 1; fi
    if [[ -z "$response" ]]; then log "Climatempo empty response"; return 1; fi

    local temp; temp=$(echo "$response" | jq -r '.data.temperature')
    local condition; condition=$(echo "$response" | jq -r '.data.condition')
    local humidity; humidity=$(echo "$response" | jq -r '.data.humidity')
    local wind; wind=$(echo "$response" | jq -r '.data.wind_velocity')
    local icon_str; icon_str=$(echo "$response" | jq -r '.data.icon') # Climatempo returns icon names
    
    # Simple logic for is_day based on hour (fallback)
    local hour; hour=$(date +%H)
    local is_day=1; [[ "$hour" -lt 6 || "$hour" -gt 18 ]] && is_day=0

    local icon; icon=$(get_icon "$condition" "" "$is_day")
    local tooltip="<b>São Carlos/SP</b>\n$condition\nUmidade: $humidity%\nVento: $wind km/h\n(Climatempo)"
    local json; json=$(format_output "$temp°C" "$icon" "$tooltip")

    write_cache "$json"
    echo "$json"
    return 0
}

# 3. OpenWeatherMap
get_weather_openweather() {
    log "Trying OpenWeatherMap..."
    if [[ ! -f "$OPENWEATHER_KEY_FILE" ]]; then log "OpenWeather key not found"; return 1; fi
    local api_key; api_key=$(cat "$OPENWEATHER_KEY_FILE")

    local response
    response=$(fetch "http://api.openweathermap.org/data/2.5/weather?q=$CITY&appid=$api_key&units=metric&lang=pt_br")

    if echo "$response" | jq -e '.cod != 200' >/dev/null; then log "OpenWeather error"; return 1; fi
    if [[ -z "$response" ]]; then log "OpenWeather empty response"; return 1; fi

    local temp; temp=$(echo "$response" | jq -r '.main.temp')
    local condition; condition=$(echo "$response" | jq -r '.weather[0].description')
    local condition_main; condition_main=$(echo "$response" | jq -r '.weather[0].main')
    local humidity; humidity=$(echo "$response" | jq -r '.main.humidity')
    local wind; wind=$(echo "$response" | jq -r '.wind.speed') # m/s
    local sys_pod; sys_pod=$(echo "$response" | jq -r '.sys.pod') # d or n

    local is_day=1; [[ "$sys_pod" == "n" ]] && is_day=0
    
    local icon; icon=$(get_icon "$condition_main" "" "$is_day")
    local temp_int; temp_int=$(printf "%.0f" "$temp")
    
    local tooltip="<b>São Carlos/SP</b>\n$condition\nUmidade: $humidity%\nVento: ${wind} m/s\n(OpenWeather)"
    local json; json=$(format_output "$temp_int°C" "$icon" "$tooltip")

    write_cache "$json"
    echo "$json"
    return 0
}

# 4. wttr.in (Final Fallback)
get_weather_wttr() {
    log "Trying wttr.in..."
    # format=j1 gives JSON output
    local response
    response=$(fetch "wttr.in/São+Carlos?format=j1&lang=pt")

    if [[ -z "$response" ]]; then log "wttr.in empty response"; return 1; fi

    local temp; temp=$(echo "$response" | jq -r '.current_condition[0].temp_C')
    local condition; condition=$(echo "$response" | jq -r '.current_condition[0].lang_pt[0].value')
    local humidity; humidity=$(echo "$response" | jq -r '.current_condition[0].humidity')
    local wind; wind=$(echo "$response" | jq -r '.current_condition[0].windspeedKmph')
    
    if [[ -z "$temp" || "$temp" == "null" ]]; then log "wttr.in parse error"; return 1; fi

    # Try to determine if it is day/night ? wttr.in doesn't explicitly say in j1 easily without complex parsing of astronomy
    # assume day for icon purposes or rely on time
    local hour; hour=$(date +%H)
    local is_day=1; [[ "$hour" -lt 6 || "$hour" -gt 18 ]] && is_day=0

    local icon; icon=$(get_icon "$condition" "" "$is_day")
    
    local tooltip="<b>São Carlos/SP</b>\n$condition\nUmidade: $humidity%\nVento: $wind km/h\n(wttr.in)"
    local json; json=$(format_output "$temp°C" "$icon" "$tooltip")

    write_cache "$json"
    echo "$json"
    return 0
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

# 1. WeatherAPI
if get_weather_weatherapi; then exit 0; fi

# 2. Climatempo
if get_weather_climatempo; then exit 0; fi

# 3. OpenWeatherMap
if get_weather_openweather; then exit 0; fi

# 4. wttr.in
if get_weather_wttr; then exit 0; fi

# 5. Cache Fallback
log "All APIs failed. Checking cache..."
if read_cache; then exit 0; fi

# 6. Final Error State
log "Cache failed. Returning error."
echo "{\"text\": \" --°C\", \"tooltip\": \"Falha ao obter dados meteorológicos (todas as APIs e cache falharam)\", \"class\": \"weather-error\"}"
exit 1
