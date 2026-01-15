# MS Outlook Calendar Integration via Graph API

CLI tools to create meetings in Outlook calendars via the Microsoft Graph API, **without sending invitations**.

## Key Feature

Meetings are created as drafts with attendees shown as a copyable list in the meeting body. This allows you to:
1. Check attendee availability first
2. Send invitations manually when ready

This is a workaround because Microsoft Graph API automatically sends invitations when attendees are added to a meeting.

## Versions

| Version | Folder | Use case |
|---------|--------|----------|
| **Single-user** | `single-user/` | One user, own machine |
| **Multi-user** | `multi-user/` | Multiple users, central server |

### Single-user

For personal use. Log in once and create meetings in your own calendar.

```bash
cd single-user
./get-token.sh
./create-meeting.sh \
  -s "Meeting" \
  -b 2026-01-15T14:00 \
  -e 2026-01-15T15:00 \
  -a "colleague1@company.com, colleague2@company.com"
```

→ See `single-user/README.md` for details.

### Multi-user

For central server/integration where multiple users need to create meetings.

```bash
cd multi-user
./get-token.sh --user anna@company.com
./create-meeting.sh --user anna@company.com \
  -s "Meeting" \
  -b 2026-01-15T14:00 \
  -e 2026-01-15T15:00
```

→ See `multi-user/README.md` for details.

## Azure App Registration

Both versions use the same App Registration:

| Parameter | Value |
|-----------|-------|
| App name | ms-outlook-invite |
| Client ID | `4b77eb33-cc0a-4b36-a8bd-39e213948f40` |
| Tenant | `common` (work + personal accounts) |

### Azure Portal Settings

**Authentication:**
- Supported account types: `Accounts in any organizational directory and personal Microsoft accounts`
- Allow public client flows: `Yes`

**API Permissions:**
- `Calendars.ReadWrite` (Delegated)

**Manifest:**
```json
"signInAudience": "AzureADandPersonalMicrosoftAccount",
"api": {
    "requestedAccessTokenVersion": 2
}
```

## User Requirements

Users must have an **Exchange Online** mailbox:

| Account type | Works? |
|--------------|--------|
| Microsoft 365 Business Basic/Standard/Premium | Yes |
| Exchange Online (standalone) | Yes |
| Outlook.com / Hotmail.com (personal) | Yes |
| Microsoft 365 Apps for Business (without Exchange) | No |
| On-premise Exchange | No |

## Token Lifecycle

| Token | Validity |
|-------|----------|
| Access token | 60-90 minutes (auto-refresh) |
| Refresh token | 90 days |

## Roadmap

- [ ] PowerShell version (for Windows machines)
- [ ] Secure token storage (keyring/vault)
- [ ] Power Automate flow template
- [ ] Jira webhook configuration guide

## Troubleshooting

### "MailboxNotEnabledForRESTAPI"
User does not have an Exchange Online mailbox.

### "InvalidAuthenticationToken"
Token expired → run `./get-token.sh`.

### "You can't sign in here with a personal account"
Manifest settings incorrect:
- `signInAudience` must be `AzureADandPersonalMicrosoftAccount`
- `requestedAccessTokenVersion` must be `2`

---

*Last updated: 2026-01-09*
