#!/bin/bash

# Script para obter temperatura de São Carlos/SP
CITY="São Carlos,BR"
API_KEY_FILE="$HOME/.config/waybar/openweather-api-key"

# Função para obter temperatura usando wttr.in (sem necessidade de API key)
get_weather_wttr() {
    local temp_data
    temp_data=$(curl -s "wttr.in/São+Carlos?format=%t" 2>/dev/null | tr -d '+')
    
    if [[ -n "$temp_data" && "$temp_data" != *"Unknown"* ]]; then
        # Remove o símbolo de graus se presente e adiciona °C
        temp_clean=$(echo "$temp_data" | sed 's/°C//g' | sed 's/°//g')
        echo "{\"text\":\"$temp_clean°C\", \"tooltip\":\"São Carlos/SP: $temp_clean°C\", \"class\":\"weather\"}"
    else
        echo "{\"text\":\"--°C\", \"tooltip\":\"Erro ao obter temperatura\", \"class\":\"weather-error\"}"
    fi
}

# Função para obter temperatura usando OpenWeatherMap (requer API key)
get_weather_openweather() {
    if [[ ! -f "$API_KEY_FILE" ]]; then
        echo "{\"text\":\"API\", \"tooltip\":\"Configure sua API key do OpenWeatherMap em $API_KEY_FILE\", \"class\":\"weather-error\"}"
        return
    fi
    
    local api_key
    api_key=$(cat "$API_KEY_FILE")
    
    local weather_data
    weather_data=$(curl -s "http://api.openweathermap.org/data/2.5/weather?q=$CITY&appid=$api_key&units=metric&lang=pt_br" 2>/dev/null)
    
    if [[ -n "$weather_data" ]]; then
        local temp
        local desc
        temp=$(echo "$weather_data" | jq -r '.main.temp // empty' 2>/dev/null)
        desc=$(echo "$weather_data" | jq -r '.weather[0].description // empty' 2>/dev/null)
        
        if [[ -n "$temp" && "$temp" != "null" ]]; then
            temp_int=$(printf "%.0f" "$temp")
            echo "{\"text\":\"$temp_int°C\", \"tooltip\":\"São Carlos/SP: $temp_int°C\\n$desc\", \"class\":\"weather\"}"
        else
            get_weather_wttr
        fi
    else
        get_weather_wttr
    fi
}

# Tenta OpenWeatherMap primeiro, depois wttr.in como fallback
if [[ -f "$API_KEY_FILE" ]]; then
    get_weather_openweather
else
    get_weather_wttr
fi
