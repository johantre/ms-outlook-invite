# Single-User: Outlook Calendar via Graph API

Create meetings in your own Outlook calendar via CLI, **without sending invitations**.

## How it works

1. Meeting is created in your calendar as a draft
2. Attendees are shown as a **copyable list** in the meeting body
3. No invitations are sent automatically
4. You can check attendee availability and send manually when ready

## Usage

### 1. Login (once)

```bash
./get-token.sh
```

1. Follow instructions (go to URL, enter code)
2. Log in with your Microsoft account
3. Grant permission
4. Tokens are stored locally (valid 90 days)

### 2. Create meeting

```bash
./create-meeting.sh \
  --subject "Sprint Review" \
  --begin 2026-01-20T14:00 \
  --end 2026-01-20T15:30 \
  --attendees "colleague1@company.be, colleague2@company.be" \
  --description "Demo of new features" \
  --location "Meeting Room A"
```

### All options

| Option | Long | Required | Description |
|--------|------|----------|-------------|
| `-s` | `--subject` | Yes | Subject |
| `-b` | `--begin` | Yes | Start time (2026-01-15T14:00) |
| `-e` | `--end` | Yes | End time |
| `-a` | `--attendees` | Yes | Attendees, comma separated |
| `-d` | `--description` | No | Description |
| `-l` | `--location` | No | Location |
| `-t` | `--timezone` | No | Timezone (default: Europe/Amsterdam) |
| `-h` | `--help` | - | Show help |

## What happens with attendees?

The attendees are **NOT** added to the meeting's attendee field (which would trigger invitations). Instead:

- Attendees appear in the meeting body as a formatted, copyable list
- You can use this list to check their calendars
- When you're ready, manually add them and send the invitation

This is a workaround because Microsoft Graph API automatically sends invitations when attendees are added to a meeting.

## Files

```
single-user/
├── get-token.sh      # Login / refresh token
├── create-meeting.sh # Create meeting
├── token.txt         # Access token (60-90 min)
├── refresh_token.txt # Refresh token (90 days)
├── token_expiry.txt  # Expiry timestamp
└── README.md
```

## Token lifecycle

| Token | Validity | Auto-refresh? |
|-------|----------|---------------|
| Access token | 60-90 min | Yes, via refresh token |
| Refresh token | 90 days | Yes, on each refresh |

## Requirements

- Microsoft account with **Exchange Online** mailbox
- Bash + curl

## When to use this version?

- You are the only user
- You want to create meetings in your own calendar
- You run the script locally on your own machine
- No central server or multi-user setup needed

See `../multi-user/` for a version supporting multiple users.
