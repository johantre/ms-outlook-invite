#!/bin/bash

# Configuratie
TENANT_ID="common"
CLIENT_ID="4b77eb33-cc0a-4b36-a8bd-39e213948f40"
BASE_DIR="/home/johan/ms-outlook-invite/multi-user"
TOKENS_DIR="$BASE_DIR/tokens"

# Hulp functie
show_help() {
    echo "Gebruik: ./get-token.sh --user <email>"
    echo ""
    echo "Opties:"
    echo "  -u, --user    Email adres van de gebruiker (verplicht)"
    echo "  -h, --help    Toon deze hulp"
    echo ""
    echo "Voorbeeld:"
    echo "  ./get-token.sh --user anna@bedrijf.com"
    echo ""
    echo "De gebruiker moet eenmalig inloggen via de browser."
    echo "Daarna zijn de tokens 90 dagen geldig."
}

# Parse argumenten
USER_EMAIL=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            USER_EMAIL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Onbekende optie: $1"
            show_help
            exit 1
            ;;
    esac
done

# Valideer
if [ -z "$USER_EMAIL" ]; then
    echo "FOUT: --user is verplicht"
    echo ""
    show_help
    exit 1
fi

# Directories per gebruiker
USER_DIR="$TOKENS_DIR/$USER_EMAIL"
TOKEN_FILE="$USER_DIR/token.txt"
REFRESH_FILE="$USER_DIR/refresh_token.txt"
EXPIRY_FILE="$USER_DIR/token_expiry.txt"

# Maak directory aan indien nodig
mkdir -p "$USER_DIR"

# Functie: Token ophalen met refresh token
refresh_access_token() {
    echo "=== Access token vernieuwen met refresh token ==="

    REFRESH_TOKEN=$(cat "$REFRESH_FILE" 2>/dev/null)

    TOKEN_RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=$CLIENT_ID" \
      -d "grant_type=refresh_token" \
      -d "refresh_token=$REFRESH_TOKEN" \
      -d "scope=Calendars.ReadWrite offline_access")

    # Check voor errors
    if echo "$TOKEN_RESPONSE" | grep -q '"error"'; then
        echo "Refresh token verlopen of ongeldig. Opnieuw inloggen nodig."
        return 1
    fi

    save_tokens "$TOKEN_RESPONSE"
    echo "Token succesvol vernieuwd!"
    return 0
}

# Functie: Tokens opslaan
save_tokens() {
    local RESPONSE="$1"

    ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    REFRESH_TOKEN=$(echo "$RESPONSE" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)
    EXPIRES_IN=$(echo "$RESPONSE" | grep -o '"expires_in":[0-9]*' | cut -d':' -f2)

    if [ -z "$ACCESS_TOKEN" ]; then
        echo "Fout: Geen access token in response"
        echo "$RESPONSE"
        return 1
    fi

    # Bereken expiry timestamp (huidige tijd + expires_in - 5 min buffer)
    EXPIRY_TIMESTAMP=$(($(date +%s) + EXPIRES_IN - 300))

    echo "$ACCESS_TOKEN" > "$TOKEN_FILE"
    echo "$EXPIRY_TIMESTAMP" > "$EXPIRY_FILE"

    if [ -n "$REFRESH_TOKEN" ]; then
        echo "$REFRESH_TOKEN" > "$REFRESH_FILE"
        echo "Refresh token opgeslagen (geldig 90 dagen)"
    fi

    echo "Access token opgeslagen (geldig tot $(date -d @$EXPIRY_TIMESTAMP '+%Y-%m-%d %H:%M:%S'))"
}

# Functie: Volledige login flow
full_login() {
    echo "=== Stap 1: Device code aanvragen ==="
    RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/devicecode" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=$CLIENT_ID" \
      -d "scope=Calendars.ReadWrite offline_access")

    # Parse response
    USER_CODE=$(echo "$RESPONSE" | grep -o '"user_code":"[^"]*"' | cut -d'"' -f4)
    DEVICE_CODE=$(echo "$RESPONSE" | grep -o '"device_code":"[^"]*"' | cut -d'"' -f4)
    VERIFICATION_URI=$(echo "$RESPONSE" | grep -o '"verification_uri":"[^"]*"' | cut -d'"' -f4)

    echo ""
    echo "========================================"
    echo "Gebruiker: $USER_EMAIL"
    echo ""
    echo "Ga naar: $VERIFICATION_URI"
    echo "Voer in: $USER_CODE"
    echo ""
    echo "BELANGRIJK: Log in met $USER_EMAIL"
    echo "========================================"
    echo ""
    read -p "Druk op Enter nadat je bent ingelogd..."

    echo ""
    echo "=== Stap 2: Access token ophalen ==="
    TOKEN_RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=$CLIENT_ID" \
      -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
      -d "device_code=$DEVICE_CODE")

    save_tokens "$TOKEN_RESPONSE"
}

# Hoofdlogica
echo "=== MS Graph Token Manager ==="
echo "Gebruiker: $USER_EMAIL"
echo ""

# Check of er een geldig refresh token is
if [ -f "$REFRESH_FILE" ] && [ -f "$EXPIRY_FILE" ]; then
    CURRENT_TIME=$(date +%s)
    EXPIRY_TIME=$(cat "$EXPIRY_FILE" 2>/dev/null || echo "0")

    if [ "$CURRENT_TIME" -lt "$EXPIRY_TIME" ]; then
        echo "Access token is nog geldig."
        echo "Geldig tot: $(date -d @$EXPIRY_TIME '+%Y-%m-%d %H:%M:%S')"
        read -p "Wil je toch een nieuw token ophalen? (j/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Jj]$ ]]; then
            exit 0
        fi
    fi

    echo "Access token verlopen, probeer te vernieuwen..."
    if refresh_access_token; then
        exit 0
    fi
    echo ""
fi

# Geen geldig refresh token, volledige login nodig
full_login
