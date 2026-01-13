#!/bin/bash

# Configuration
TENANT_ID="common"  # "common" works for both work and personal accounts
CLIENT_ID="4b77eb33-cc0a-4b36-a8bd-39e213948f40"
TOKEN_DIR="/home/johan/ms-outlook-invite/single-user"
TOKEN_FILE="$TOKEN_DIR/token.txt"
REFRESH_FILE="$TOKEN_DIR/refresh_token.txt"
EXPIRY_FILE="$TOKEN_DIR/token_expiry.txt"

# Function: Retrieve token using refresh token
refresh_access_token() {
    echo "=== Refreshing access token with refresh token ==="

    REFRESH_TOKEN=$(cat "$REFRESH_FILE" 2>/dev/null)

    TOKEN_RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=$CLIENT_ID" \
      -d "grant_type=refresh_token" \
      -d "refresh_token=$REFRESH_TOKEN" \
      -d "scope=Calendars.ReadWrite offline_access")

    # Check for errors
    if echo "$TOKEN_RESPONSE" | grep -q '"error"'; then
        echo "Refresh token expired or invalid. Full login required."
        return 1
    fi

    save_tokens "$TOKEN_RESPONSE"
    echo "Token successfully refreshed!"
    return 0
}

# Function: Save tokens
save_tokens() {
    local RESPONSE="$1"

    ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
    REFRESH_TOKEN=$(echo "$RESPONSE" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)
    EXPIRES_IN=$(echo "$RESPONSE" | grep -o '"expires_in":[0-9]*' | cut -d':' -f2)

    if [ -z "$ACCESS_TOKEN" ]; then
        echo "Error: No access token in response"
        echo "$RESPONSE"
        return 1
    fi

    # Calculate expiry timestamp (current time + expires_in - 5 min buffer)
    EXPIRY_TIMESTAMP=$(($(date +%s) + EXPIRES_IN - 300))

    echo "$ACCESS_TOKEN" > "$TOKEN_FILE"
    echo "$EXPIRY_TIMESTAMP" > "$EXPIRY_FILE"

    if [ -n "$REFRESH_TOKEN" ]; then
        echo "$REFRESH_TOKEN" > "$REFRESH_FILE"
        echo "Refresh token saved (valid 90 days)"
    fi

    echo "Access token saved (valid until $(date -d @$EXPIRY_TIMESTAMP '+%Y-%m-%d %H:%M:%S'))"
}

# Function: Full login flow
full_login() {
    echo "=== Step 1: Requesting device code ==="
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
    echo "Go to: $VERIFICATION_URI"
    echo "Enter: $USER_CODE"
    echo "========================================"
    echo ""
    read -p "Press Enter after you have logged in..."

    echo ""
    echo "=== Step 2: Retrieving access token ==="
    TOKEN_RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -d "client_id=$CLIENT_ID" \
      -d "grant_type=urn:ietf:params:oauth:grant-type:device_code" \
      -d "device_code=$DEVICE_CODE")

    save_tokens "$TOKEN_RESPONSE"
}

# Main logic
echo "=== MS Graph Token Manager (Single User) ==="
echo ""

# Check if a valid refresh token exists
if [ -f "$REFRESH_FILE" ] && [ -f "$EXPIRY_FILE" ]; then
    CURRENT_TIME=$(date +%s)
    EXPIRY_TIME=$(cat "$EXPIRY_FILE" 2>/dev/null || echo "0")

    if [ "$CURRENT_TIME" -lt "$EXPIRY_TIME" ]; then
        echo "Access token is still valid."
        echo "Valid until: $(date -d @$EXPIRY_TIME '+%Y-%m-%d %H:%M:%S')"
        read -p "Do you want to retrieve a new token anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Jj]$ ]]; then
            exit 0
        fi
    fi

    echo "Access token expired, attempting to refresh..."
    if refresh_access_token; then
        exit 0
    fi
    echo ""
fi

# No valid refresh token, full login needed
full_login
