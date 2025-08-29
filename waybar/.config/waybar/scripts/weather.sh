#!/usr/bin/env bash

# Script para obter informações do clima de São Carlos/SP
# Usando a API do OpenWeatherMap ou wttr.in

CITY="São Carlos"
COUNTRY="BR"

# Função para usar wttr.in (não requer API key)
get_weather_wttr() {
    local weather_data
    weather_data=$(curl -s "https://wttr.in/São%20Carlos,Brazil?format=%t" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$weather_data" ]; then
        # Extrair apenas a temperatura e formatar com uma casa decimal
        temp=$(echo "$weather_data" | sed 's/+//g' | sed 's/°C//g' | sed 's/°//g' | sed 's/%//g' | tr -d ' ')
        
        # Se a temperatura é um número inteiro, adicionar .0
        if [[ "$temp" =~ ^[0-9-]+$ ]]; then
            temp="${temp}.0"
        fi
        
        echo "${temp}°C"
    else
        echo "N/A"
    fi
}

# Função para usar OpenWeatherMap (requer API key)
get_weather_openweather() {
    # Se você tiver uma API key do OpenWeatherMap, descomente e configure:
    # API_KEY="SUA_API_KEY_AQUI"
    # weather_data=$(curl -s "http://api.openweathermap.org/data/2.5/weather?q=${CITY},${COUNTRY}&appid=${API_KEY}&units=metric&lang=pt")
    # temp=$(echo $weather_data | jq -r '.main.temp' | cut -d'.' -f1)
    # desc=$(echo $weather_data | jq -r '.weather[0].description')
    # echo "🌤️ ${temp}° $desc"
    
    echo "Configure API key"
}

# Tentar wttr.in primeiro (gratuito)
get_weather_wttr
