#!/bin/bash

# Configuration
TENANT_ID="common"
CLIENT_ID="4b77eb33-cc0a-4b36-a8bd-39e213948f40"
TOKEN_DIR="/home/johan/ms-outlook-invite/single-user"
TOKEN_FILE="$TOKEN_DIR/token.txt"
REFRESH_FILE="$TOKEN_DIR/refresh_token.txt"
EXPIRY_FILE="$TOKEN_DIR/token_expiry.txt"

# Help function
show_help() {
    echo "Usage: ./create-meeting.sh [options]"
    echo ""
    echo "Mandatory options:"
    echo "  -s, --subject      Subject of the meeting"
    echo "  -b, --begin        Start time (format: 2026-01-15T14:00)"
    echo "  -e, --end          End time (format: 2026-01-15T15:00)"
    echo "  -a, --attendees    Attendee list comma separated: colleague1@company.be, colleague2@company.be"
    echo ""
    echo "Optional options:"
    echo "  -d, --description  Description/body of the meeting"
    echo "  -l, --location     Location of the meeting"
    echo "  -t, --timezone     Timezone (default: Europe/Amsterdam)"
    echo "  -h, --help         Show this help"
    echo ""
    echo "Example:"
    echo "  ./create-meeting.sh -s \"Team Standup\" -b 2026-01-15T09:00 -e 2026-01-15T09:30"
    echo ""
    echo "  ./create-meeting.sh --subject \"Sprint Review\" \\"
    echo "                      --begin 2026-01-20T14:00 \\"
    echo "                      --end 2026-01-20T15:30 \\"
    echo "                      --attendees \"colleague1@company.be, colleague2@company.be\" \\"
    echo "                      --description \"Demo of new features\" \\"
    echo "                      --location \"Meeting Room A\""
}

# Default values
SUBJECT=""
START_TIME=""
END_TIME=""
ATTENDEE_LIST=""
DESCRIPTION=""
LOCATION=""
TIMEZONE="Europe/Amsterdam"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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
        -a|--attendees)
            ATTENDEE_LIST="$2";
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
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate mandatory fields
if [ -z "$SUBJECT" ] || [ -z "$START_TIME" ] || [ -z "$END_TIME" ] || [ -z "$ATTENDEE_LIST" ]; then
    echo "ERROR: Subject, begin, end, and attendees are mandatory."
    echo ""
    show_help
    exit 1
fi

# Function: Refresh token using refresh token
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

    echo "Token automatically refreshed"
    return 0
}

# Function: Ensure valid token
ensure_valid_token() {
    CURRENT_TIME=$(date +%s)
    EXPIRY_TIME=$(cat "$EXPIRY_FILE" 2>/dev/null || echo "0")

    if [ "$CURRENT_TIME" -ge "$EXPIRY_TIME" ]; then
        echo "Access token expired, refreshing..."
        if ! refresh_access_token; then
            echo "ERROR: Could not refresh token. Run ./get-token.sh to log in again."
            exit 1
        fi
    fi
}

format_attendees_for_body() {
    if [ -z "$ATTENDEE_LIST" ]; then
        echo "None"
    else
        # Replace commas with ", " for better readability
        echo "$ATTENDEE_LIST" | sed 's/,/, /g'
    fi
}

# Build JSON payload
build_json_payload() {
    # Format the list for the visual body
    DISPLAY_ATTENDEES=$(format_attendees_for_body)

    # 2. Build the main JSON
    # We added responseRequested: false to prevent immediate notification spam
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
  },
  "location": {
    "displayName": "${LOCATION:-No location}"
  },
  "body": {
    "contentType": "HTML",
    "content": "<html><body><div style='font-family:sans-serif;border:1px solid #e1e4e8;border-radius:6px;padding:10px;background-color:#f6f8fa;'><b>📋 Copy Attendees:</b><br><code style='display:block;margin-top:5px;padding:8px;background:#ffffff;border:1px solid #d1d5da;border-radius:3px;color:#24292e;'>$DISPLAY_ATTENDEES</code></div><br><hr><br>${DESCRIPTION:-No description}</body></html>"
  },
  "attendees": [],
  "responseRequested": false
}
EOF
)

    echo "$JSON"
}

# Main logic
echo "=== Creating Meeting ==="
echo "Subject: $SUBJECT"
echo "Start: $START_TIME ($TIMEZONE)"
echo "End: $END_TIME"
echo "Attendees: $ATTENDEE_LIST"
[ -n "$DESCRIPTION" ] && echo "Description: $DESCRIPTION"
[ -n "$LOCATION" ] && echo "Location: $LOCATION"
echo ""

# Check and refresh token if necessary
ensure_valid_token

# Read token
TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "No token found. Run ./get-token.sh first."
    exit 1
fi

# Build JSON
JSON_PAYLOAD=$(build_json_payload)

# Create meeting
RESPONSE=$(curl -s -X POST "https://graph.microsoft.com/v1.0/me/calendar/events" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD")

# Check result
if echo "$RESPONSE" | grep -q '"id"'; then
    echo "Meeting successfully created!"
    RESULT_SUBJECT=$(echo "$RESPONSE" | grep -o '"subject":"[^"]*"' | cut -d'"' -f4)
    WEB_LINK=$(echo "$RESPONSE" | grep -o '"webLink":"[^"]*"' | cut -d'"' -f4)
    echo "Subject: $RESULT_SUBJECT"
    echo "Link: $WEB_LINK"
    exit 0
else
    echo "Error creating meeting:"
    echo "$RESPONSE" | head -c 500
    exit 1
fi