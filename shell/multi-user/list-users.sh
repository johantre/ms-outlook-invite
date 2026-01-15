#!/bin/bash

# Configuratie
TOKENS_DIR="/home/johan/ms-outlook-invite/multi-user/tokens"

echo "=== Geregistreerde gebruikers ==="
echo ""

if [ ! -d "$TOKENS_DIR" ] || [ -z "$(ls -A "$TOKENS_DIR" 2>/dev/null)" ]; then
    echo "Geen gebruikers geregistreerd."
    echo ""
    echo "Registreer een gebruiker met:"
    echo "  ./get-token.sh --user email@example.com"
    exit 0
fi

for USER_DIR in "$TOKENS_DIR"/*/; do
    USER_EMAIL=$(basename "$USER_DIR")
    EXPIRY_FILE="$USER_DIR/token_expiry.txt"
    REFRESH_FILE="$USER_DIR/refresh_token.txt"

    if [ -f "$EXPIRY_FILE" ]; then
        EXPIRY_TIME=$(cat "$EXPIRY_FILE")
        CURRENT_TIME=$(date +%s)
        EXPIRY_DATE=$(date -d @$EXPIRY_TIME '+%Y-%m-%d %H:%M')

        if [ "$CURRENT_TIME" -lt "$EXPIRY_TIME" ]; then
            STATUS="✓ Actief"
        elif [ -f "$REFRESH_FILE" ]; then
            STATUS="↻ Token verlopen (refresh beschikbaar)"
        else
            STATUS="✗ Vernieuwen nodig"
        fi
    else
        STATUS="? Onbekend"
    fi

    printf "%-40s %s\n" "$USER_EMAIL" "$STATUS"
done

echo ""
