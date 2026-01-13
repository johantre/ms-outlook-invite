#!/bin/bash

# Configuratie
TENANT_ID="common"
CLIENT_ID="4b77eb33-cc0a-4b36-a8bd-39e213948f40"
BASE_DIR="/home/johan/ms-outlook-invite/multi-user"
TOKENS_DIR="$BASE_DIR/tokens"

# Hulp functie
show_help() {
    echo "Gebruik: ./create-meeting.sh --user <email> [opties]"
    echo ""
    echo "Verplichte opties:"
    echo "  -u, --user         Email adres van de gebruiker"
    echo "  -s, --subject      Onderwerp van de meeting"
    echo "  -b, --begin        Starttijd (formaat: 2026-01-15T14:00)"
    echo "  -e, --end          Eindtijd (formaat: 2026-01-15T15:00)"
    echo ""
    echo "Optionele opties:"
    echo "  -d, --description  Beschrijving/body van de meeting"
    echo "  -l, --location     Locatie van de meeting"
    echo "  -t, --timezone     Tijdzone (default: Europe/Amsterdam)"
    echo "  -h, --help         Toon deze hulp"
    echo ""
    echo "Voorbeeld:"
    echo "  ./create-meeting.sh --user anna@bedrijf.com -s \"Team Standup\" -b 2026-01-15T09:00 -e 2026-01-15T09:30"
}

# Standaard waarden
USER_EMAIL=""
SUBJECT=""
START_TIME=""
END_TIME=""
DESCRIPTION=""
LOCATION=""
TIMEZONE="Europe/Amsterdam"

# Parse argumenten
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            USER_EMAIL="$2"
            shift 2
            ;;
        -s|--subject)
            SUBJECT="$2"
            shift 2
            ;;
        -b|--begin)
            START_TIME="$2"
            shift 2
            ;;
        -e|--end)
            END_TIME="$2"
            shift 2
            ;;
        -d|--description)
            DESCRIPTION="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -t|--timezone)
            TIMEZONE="$2"
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

# Valideer verplichte velden
if [ -z "$USER_EMAIL" ]; then
    echo "FOUT: --user is verplicht"
    echo ""
    show_help
    exit 1
fi

if [ -z "$SUBJECT" ] || [ -z "$START_TIME" ] || [ -z "$END_TIME" ]; then
    echo "FOUT: --subject, --begin en --end zijn verplicht."
    echo ""
    show_help
    exit 1
fi

# Directories per gebruiker
USER_DIR="$TOKENS_DIR/$USER_EMAIL"
TOKEN_FILE="$USER_DIR/token.txt"
REFRESH_FILE="$USER_DIR/refresh_token.txt"
EXPIRY_FILE="$USER_DIR/token_expiry.txt"

# Check of gebruiker bestaat
if [ ! -d "$USER_DIR" ]; then
    echo "FOUT: Geen tokens gevonden voor $USER_EMAIL"
    echo "Voer eerst uit: ./get-token.sh --user $USER_EMAIL"
    exit 1
fi

# Functie: Token vernieuwen met refresh token
refresh_access_token() {
    REFRESH_TOKEN=$(cat "$REFRESH_FILE" 2>/dev/null)

    if [ -z "$REFRESH_TOKEN" ]; then
        return 1
    fi

    TOKEN_RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=$CLIENT_ID" \
      -d "grant_type=refresh_token" \
      -d "refresh_token=$REFRESH_TOKEN" \
      -d "scope=Calendars.ReadWrite offline_access")

    if echo "$TOKEN_RESPONSE" | grep -q '"error"'; then
        return 1
    fi

    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    NEW_REFRESH=$(echo "$TOKEN_RESPONSE" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)
    EXPIRES_IN=$(echo "$TOKEN_RESPONSE" | grep -o '"expires_in":[0-9]*' | cut -d':' -f2)

    if [ -z "$ACCESS_TOKEN" ]; then
        return 1
    fi

    EXPIRY_TIMESTAMP=$(($(date +%s) + EXPIRES_IN - 300))
    echo "$ACCESS_TOKEN" > "$TOKEN_FILE"
    echo "$EXPIRY_TIMESTAMP" > "$EXPIRY_FILE"
    [ -n "$NEW_REFRESH" ] && echo "$NEW_REFRESH" > "$REFRESH_FILE"

    echo "Token automatisch vernieuwd voor $USER_EMAIL"
    return 0
}

# Functie: Zorg voor geldig token
ensure_valid_token() {
    CURRENT_TIME=$(date +%s)
    EXPIRY_TIME=$(cat "$EXPIRY_FILE" 2>/dev/null || echo "0")

    if [ "$CURRENT_TIME" -ge "$EXPIRY_TIME" ]; then
        echo "Access token verlopen, vernieuwen..."
        if ! refresh_access_token; then
            echo "FOUT: Kon token niet vernieuwen voor $USER_EMAIL"
            echo "Voer uit: ./get-token.sh --user $USER_EMAIL"
            exit 1
        fi
    fi
}

# Bouw JSON payload
build_json_payload() {
    # Start met basis JSON
    JSON=$(cat <<EOF
{
  "subject": "$SUBJECT",
  "start": {
    "dateTime": "$START_TIME",
    "timeZone": "$TIMEZONE"
  },
  "end": {
    "dateTime": "$END_TIME",
    "timeZone": "$TIMEZONE"
  }
EOF
)

    # Voeg optionele description toe
    if [ -n "$DESCRIPTION" ]; then
        JSON="$JSON,
  \"body\": {
    \"contentType\": \"text\",
    \"content\": \"$DESCRIPTION\"
  }"
    fi

    # Voeg optionele location toe
    if [ -n "$LOCATION" ]; then
        JSON="$JSON,
  \"location\": {
    \"displayName\": \"$LOCATION\"
  }"
    fi

    # Sluit JSON af
    JSON="$JSON
}"

    echo "$JSON"
}

# Hoofdlogica
echo "=== Meeting aanmaken ==="
echo "Gebruiker: $USER_EMAIL"
echo "Onderwerp: $SUBJECT"
echo "Start: $START_TIME ($TIMEZONE)"
echo "Eind: $END_TIME"
[ -n "$DESCRIPTION" ] && echo "Beschrijving: $DESCRIPTION"
[ -n "$LOCATION" ] && echo "Locatie: $LOCATION"
echo ""

# Check en vernieuw token indien nodig
ensure_valid_token

# Lees token
TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "Geen token gevonden. Voer eerst ./get-token.sh --user $USER_EMAIL uit."
    exit 1
fi

# Bouw JSON
JSON_PAYLOAD=$(build_json_payload)

# Maak meeting aan
RESPONSE=$(curl -s -X POST "https://graph.microsoft.com/v1.0/me/calendar/events" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD")

# Check resultaat
if echo "$RESPONSE" | grep -q '"id"'; then
    echo "Meeting succesvol aangemaakt!"
    RESULT_SUBJECT=$(echo "$RESPONSE" | grep -o '"subject":"[^"]*"' | cut -d'"' -f4)
    WEB_LINK=$(echo "$RESPONSE" | grep -o '"webLink":"[^"]*"' | cut -d'"' -f4)
    echo "Onderwerp: $RESULT_SUBJECT"
    echo "Link: $WEB_LINK"
    exit 0
else
    echo "Fout bij aanmaken meeting:"
    echo "$RESPONSE" | head -c 500
    exit 1
fi
