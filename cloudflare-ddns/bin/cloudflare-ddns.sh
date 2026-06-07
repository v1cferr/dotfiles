#!/bin/bash

#############################################
# Cloudflare Dynamic DNS updater
# Atualiza automaticamente o registro DNS A
# quando o IP público muda
#############################################

# Set the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${PROJECT_DIR}/../.env"   # .env centralizado no root dos dotfiles
LOG_FILE="${PROJECT_DIR}/logs/ddns.log"
IP_CACHE_FILE="${PROJECT_DIR}/logs/.current_ip"

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log messages
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    echo -e "${RED}[${level}]${NC} ${message}" >&2
}

# Function for success logging
log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [SUCCESS] $@" >> "$LOG_FILE"
    echo -e "${GREEN}[SUCCESS]${NC} $@" >&2
}

# Function for info logging
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [INFO] $@" >> "$LOG_FILE"
    echo -e "${YELLOW}[INFO]${NC} $@" >&2
}

# Validate that .env file exists
if [[ ! -f "$ENV_FILE" ]]; then
    log "ERROR" ".env file not found at $ENV_FILE"
    echo "Please create a .env file with the following content:"
    echo "API_TOKEN=your_cloudflare_api_token"
    echo "ZONE_ID=your_zone_id"
    echo "RECORD_ID=your_record_id"
    echo "RECORD_NAME=your.domain.com"
    exit 1
fi

# Source the .env file
source "$ENV_FILE"

# Validate required variables
for var in API_TOKEN ZONE_ID RECORD_ID RECORD_NAME; do
    if [[ -z "${!var}" ]]; then
        log "ERROR" "Missing required variable: $var in .env file"
        exit 1
    fi
done

# Get current public IP
log_info "Fetching current public IP..."
CURRENT_IP=$(curl -s --max-time 5 https://api.ipify.org)

if [[ -z "$CURRENT_IP" ]]; then
    log "ERROR" "Failed to fetch public IP"
    exit 1
fi

log_info "Current IP detected: $CURRENT_IP"

# Check if IP has changed
if [[ -f "$IP_CACHE_FILE" ]]; then
    PREVIOUS_IP=$(cat "$IP_CACHE_FILE")
    if [[ "$CURRENT_IP" == "$PREVIOUS_IP" ]]; then
        log_success "IP hasn't changed ($CURRENT_IP). No update needed."
        exit 0
    fi
    log_info "IP changed from $PREVIOUS_IP to $CURRENT_IP. Updating Cloudflare..."
else
    log_info "No previous IP cache found. First run or cache was cleared."
fi

# Update Cloudflare DNS record
log_info "Updating Cloudflare DNS record..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
        \"type\":\"A\",
        \"name\":\"$RECORD_NAME\",
        \"content\":\"$CURRENT_IP\",
        \"ttl\":120,
        \"proxied\":false
    }")

# Extract HTTP status code
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Check response
if [[ "$HTTP_CODE" == "200" ]]; then
    # Verify success in response
    if echo "$BODY" | jq -e '.success' > /dev/null 2>&1; then
        log_success "DNS record updated successfully! IP: $CURRENT_IP"
        echo "$CURRENT_IP" > "$IP_CACHE_FILE"
        exit 0
    else
        ERROR_MSG=$(echo "$BODY" | jq -r '.errors[0].message // "Unknown error"' 2>/dev/null)
        log "ERROR" "Cloudflare API error: $ERROR_MSG"
        log "ERROR" "Response: $BODY"
        exit 1
    fi
else
    log "ERROR" "HTTP $HTTP_CODE - Failed to update DNS record"
    log "ERROR" "Response: $BODY"
    exit 1
fi
