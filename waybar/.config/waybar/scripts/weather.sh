#!/bin/bash

# Script para obter temperatura de São Carlos/SP
CITY="São Carlos,SP,Brazil"
CITY_COORDS="-21.9977,-47.8827"  # Coordenadas específicas de São Carlos/SP
WEATHERAPI_KEY_FILE="$HOME/.config/waybar/weatherapi-key"
OPENWEATHER_KEY_FILE="$HOME/.config/waybar/openweather-api-key"

# Função para obter temperatura usando WeatherAPI.com (PRINCIPAL - 1M calls/mês gratuitas)
get_weather_weatherapi() {
    if [[ ! -f "$WEATHERAPI_KEY_FILE" ]]; then
        echo "{\"text\":\"API\", \"tooltip\":\"Configure sua API key do WeatherAPI.com em $WEATHERAPI_KEY_FILE\\nRegistre-se em: https://www.weatherapi.com/\", \"class\":\"weather-error\"}"
        return 1
    fi
    
    local api_key
    api_key=$(cat "$WEATHERAPI_KEY_FILE")
    
    local weather_data
    weather_data=$(curl -s "http://api.weatherapi.com/v1/current.json?key=$api_key&q=$CITY_COORDS&lang=pt" 2>/dev/null)
    
    if [[ -n "$weather_data" ]]; then
        local temp
        local condition
        local humidity
        local wind_kph
        
        temp=$(echo "$weather_data" | jq -r '.current.temp_c // empty' 2>/dev/null)
        condition=$(echo "$weather_data" | jq -r '.current.condition.text // empty' 2>/dev/null)
        humidity=$(echo "$weather_data" | jq -r '.current.humidity // empty' 2>/dev/null)
        wind_kph=$(echo "$weather_data" | jq -r '.current.wind_kph // empty' 2>/dev/null)
        
        if [[ -n "$temp" && "$temp" != "null" ]]; then
            temp_int=$(echo "$temp" | cut -d'.' -f1)  # Pega apenas a parte inteira
            tooltip="São Carlos/SP: $temp_int°C\\n$condition"
            [[ -n "$humidity" && "$humidity" != "null" ]] && tooltip+="\\nUmidade: $humidity%"
            [[ -n "$wind_kph" && "$wind_kph" != "null" ]] && tooltip+="\\nVento: $wind_kph km/h"
            
            echo "{\"text\":\"$temp_int°C\", \"tooltip\":\"$tooltip\", \"class\":\"weather\"}"
            return 0
        fi
    fi
    return 1
}

# Função para obter temperatura usando wttr.in (FALLBACK FINAL - sem necessidade de API key)
get_weather_wttr() {
    local temp_data
    temp_data=$(curl -s "wttr.in/São+Carlos?format=%t" 2>/dev/null | tr -d '+')
    
    if [[ -n "$temp_data" && "$temp_data" != *"Unknown"* ]]; then
        # Remove o símbolo de graus se presente e adiciona °C
        temp_clean=$(echo "$temp_data" | sed 's/°C//g' | sed 's/°//g')
        echo "{\"text\":\"$temp_clean°C\", \"tooltip\":\"São Carlos/SP: $temp_clean°C (wttr.in)\", \"class\":\"weather\"}"
        return 0
    else
        echo "{\"text\":\"--°C\", \"tooltip\":\"Erro ao obter temperatura\", \"class\":\"weather-error\"}"
        return 1
    fi
}

# Função para obter temperatura usando OpenWeatherMap (BACKUP - 1000 calls/dia)
get_weather_openweather() {
    if [[ ! -f "$OPENWEATHER_KEY_FILE" ]]; then
        return 1
    fi
    
    local api_key
    api_key=$(cat "$OPENWEATHER_KEY_FILE")
    
    local weather_data
    weather_data=$(curl -s "http://api.openweathermap.org/data/2.5/weather?q=$CITY&appid=$api_key&units=metric&lang=pt_br" 2>/dev/null)
    
    if [[ -n "$weather_data" ]]; then
        local temp
        local desc
        temp=$(echo "$weather_data" | jq -r '.main.temp // empty' 2>/dev/null)
        desc=$(echo "$weather_data" | jq -r '.weather[0].description // empty' 2>/dev/null)
        
        if [[ -n "$temp" && "$temp" != "null" ]]; then
            temp_int=$(printf "%.0f" "$temp")
            echo "{\"text\":\"$temp_int°C\", \"tooltip\":\"São Carlos/SP: $temp_int°C\\n$desc (OpenWeatherMap)\", \"class\":\"weather\"}"
            return 0
        fi
    fi
    return 1
}

# Sistema de fallback: WeatherAPI.com → OpenWeatherMap → wttr.in
if ! get_weather_weatherapi; then
    if ! get_weather_openweather; then
        get_weather_wttr
    fi
fi
