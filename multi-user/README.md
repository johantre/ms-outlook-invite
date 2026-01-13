# Multi-User: Outlook Calendar via Graph API

This version supports **multiple users**, where each user can create meetings in their own Outlook calendar. Tokens are stored per user.

> **Note**: The attendees-as-copyable-list feature from single-user has not yet been added to this version. See `../single-user/` for reference.

## When to use this version?

- Central server/service acting on behalf of multiple users
- Jira/Power Automate integration where different users create meetings
- Tokens need to be managed centrally

## Usage

### 1. Register user (once per person)

```bash
./get-token.sh --user anna@company.com
```

The user must:
1. Go to the displayed URL
2. Enter the code
3. Log in with **the specified email address**
4. Grant permission

Tokens are stored in `tokens/anna@company.com/`.

### 2. Create meeting

```bash
./create-meeting.sh --user anna@company.com \
  -s "Team Standup" \
  -b 2026-01-15T09:00 \
  -e 2026-01-15T09:30
```

The meeting is created in the specified user's calendar.

### 3. View registered users

```bash
./list-users.sh
```

Shows all registered users and their token status.

## All options

### get-token.sh

| Option | Long | Description |
|--------|------|-------------|
| `-u` | `--user` | Email address (required) |
| `-h` | `--help` | Show help |

### create-meeting.sh

| Option | Long | Required | Description |
|--------|------|----------|-------------|
| `-u` | `--user` | Yes | Email address of the user |
| `-s` | `--subject` | Yes | Subject |
| `-b` | `--begin` | Yes | Start time (2026-01-15T14:00) |
| `-e` | `--end` | Yes | End time |
| `-d` | `--description` | No | Description |
| `-l` | `--location` | No | Location |
| `-t` | `--timezone` | No | Timezone (default: Europe/Amsterdam) |
| `-h` | `--help` | - | Show help |

#### Full example

```bash
./create-meeting.sh \
  --user bob@company.com \
  --subject "Sprint Review" \
  --begin 2026-01-20T14:00 \
  --end 2026-01-20T15:30 \
  --description "Demo of new features" \
  --location "Meeting Room A"
```

## Files

```
multi-user/
├── get-token.sh      # Register user / refresh token
├── create-meeting.sh # Create meeting for specific user
├── list-users.sh     # Show registered users
├── tokens/           # Tokens per user
│   ├── anna@company.com/
│   │   ├── token.txt
│   │   ├── refresh_token.txt
│   │   └── token_expiry.txt
│   └── bob@company.com/
│       └── ...
└── README.md
```

## Token lifecycle

| Token | Validity | Auto-refresh? |
|-------|----------|---------------|
| Access token | 60-90 min | Yes, via refresh token |
| Refresh token | 90 days | Yes, on each refresh |

## Security considerations

Tokens are stored as plain text. For production consider:

- Restrict file permissions (`chmod 600`)
- Linux keyring (`secret-tool`)
- Azure Key Vault
- Encrypted storage

## Flow for Jira/Power Automate integration

```
┌─────────────────────────────────────┐
│ Jira Automation                     │
│ Sends webhook with:                 │
│ - user: anna@company.com            │
│ - subject, begin, end, etc.         │
└─────────────────┬───────────────────┘
                  ↓
┌─────────────────────────────────────┐
│ Power Automate / Central Server     │
│ Calls create-meeting.sh             │
│ with --user anna@company.com        │
└─────────────────┬───────────────────┘
                  ↓
┌─────────────────────────────────────┐
│ Meeting in Anna's calendar          │
└─────────────────────────────────────┘
```

## Requirements

- Each user must have an **Exchange Online** mailbox
- Each user must register once (grant consent)
- Bash + curl

See `../single-user/` for a simpler version for one user.
