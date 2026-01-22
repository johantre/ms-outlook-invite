# Jira Automation Setup

This guide explains how to configure the Jira Automation that triggers the MS Outlook Auto-Invite workflow.

## Prerequisites

### Service User (Recommended)

Create a dedicated user account for automation purposes:

1. Create a regular Atlassian account (e.g., `jira-automation@yourcompany.com`)
   - Use a shared mailbox or distribution list you can access
   - This is NOT an Atlassian "Service Account" (those don't support Basic Auth)

2. Generate an API token:
   - Login as the service user
   - Go to [id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens)
   - Click **Create API token**
   - Save the token securely

3. Grant minimal permissions:
   - Add user to Jira with **Browse Projects** permission
   - Add user to required projects as **Viewer** or **Member**

### Base64 Credentials
Encode the credentials for the Authorization header. 2 options:
#### Bash
```bash
echo -n "service-user@yourcompany.com:YOUR-API-TOKEN" | base64
```
> **Important**: Use `-n` flag to avoid newline in the encoding!

#### Interactive
- Go to https://www.base64encode.org/ 
- Copy paste your service-user@yourcompany.com:YOUR-API-TOKEN
- Click Encode & save it somewhere safe

#### The result format

 `c2VydmljZS11c2VyQHlvdXJjb21wYW55LmNvbTpZT1VSLUFQSS1UT0tFTg==`

## Automation Rule Setup

### Import the Rule in Jira 

1. Download [Jira Automation Rule](assets/resources/automation-rule-019bd135-ab05-72e4-a336-a81a4bec2dfb-202601201212.json) from this repo
2. With an authorized(!) user 
   - Go to Jira admin settings (not through Space settings!)
   - Global automations
   - "..." button next to blue "Create rule" button
   - Import rules
   - Import your downloaded .json
   - Select your rule to import
   - Leave "Import rule owners" unchecked
   - Click Next 
3. Go to the imported rule > Edit
   - Check the rule Actor and owner, adapt if needed
   - Go to "Send web request", change the authorization header from 
     - {{YOUR base64 encoded jira-automation@yourcompany.com:API key}} to your base encoded key.   
     - The field value should look similar like: Basic c2VydmljZS11c2VyQHlvdXJjb21wYW55LmNvbTpZT1VSLUFQSS1UT0tFTg==
   - Click Update and enable the rule (pill switch next to Update button)

### Create the Rule manually

1. Go to **Project Settings** → **Automation** (or global automation)
2. Click **Create rule**
3. Select trigger: **Manually triggered** (or your preferred trigger)

#### Add Web Request Action (Optional - for board lookup)

If you need to dynamically get board IDs:

1. Add action: **Send web request**
2. Configure:
   - **URL**: `{{baseUrl}}/rest/agile/1.0/board?projectKeyOrId={{project.key}}`
   - **Method**: GET
   - **Headers**:
     - Name: `Authorization`
     - Value: `Basic YOUR-BASE64-ENCODED-CREDENTIALS`
     - ☑️ **Hidden** (check this box!)
   - **Response**: Save as `webhookResponse`

#### Add Send Email Action

1. Add action: **Send email**
2. Configure:
   - **To**: Your email address (the one monitored by Power Automate)
   - **Subject**: `[AUTO-INVITE] {{issue.summary}}`
   - **Body**:

```json
{
    "subject": "{{issue.summary}}",
    "attendees": "{{issue.Involved People.emailAddress}}",
    "location": "Board room",
    "description": "{{issue.description.html.jsonEncode}}",
    "host": "{{baseUrl}}",
    "projectKey": "{{project.key}}",
    "issueId": "{{issue.id}}",
    "issueKey": "{{issue.key}}",
    "boardNames": "{{#webhookResponse.body.values}}{{name}}{{^last}}|||{{/}}{{/}}",
    "boardIds": "{{#webhookResponse.body.values}}{{id}}{{^last}}|||{{/}}{{/}}",
    "boardName": "{{userInputs.boardName}}"
}
```
📸 [Screenshots](https://johantre.github.io/ms-outlook-invite/at.html) for Rule usage & creation example.

## Automation Rule Explained

### JSON Payload Fields

| Field | Required | Description | Example |
|-------|----------|-------------|---------|
| `subject` | Yes | Meeting title | `{{issue.summary}}` |
| `attendees` | Yes | Email addresses (semicolon separated) | `{{issue.Involved People.emailAddress}}` |
| `location` | Yes | Meeting location | `Board room` |
| `description` | Yes | Meeting description (HTML supported) | `{{issue.description.html.jsonEncode}}` |
| `host` | Yes | Jira instance URL | `{{baseUrl}}` |
| `projectKey` | Yes | Project key | `{{project.key}}` |
| `issueId` | Yes | Issue ID | `{{issue.id}}` |
| `issueKey` | Yes | Issue key | `{{issue.key}}` |
| `boardNames` | Yes | All board names (for URL construction) | See template above |
| `boardIds` | Yes | All board IDs | See template above |
| `boardName` | No | Selected board name | `{{userInputs.boardName}}` |

### Smart Values Reference

#### Description Formatting

| Smart Value | Output |
|-------------|--------|
| `{{issue.description}}` | Raw wiki markup |
| `{{issue.description.html}}` | Rendered HTML |
| `{{issue.description.html.jsonEncode}}` | HTML escaped for JSON ✅ |

#### Attendees Field

The `Involved People` field (or your custom multi-user field):
- `{{issue.Involved People.emailAddress}}` returns semicolon-separated emails

#### Board Lookup Response

The web request returns boards in `webhookResponse.body.values[]`:
- `{{#webhookResponse.body.values}}{{name}}{{^last}}|||{{/}}{{/}}` - All names with `|||` delimiter
- `{{#webhookResponse.body.values}}{{id}}{{^last}}|||{{/}}{{/}}` - All IDs with `|||` delimiter

### Security Best Practices

1. **Hide sensitive headers**: Always check the **Hidden** checkbox for Authorization headers
2. **Use dedicated service user**: Don't use personal accounts for automation
3. **Minimal permissions**: Grant only Browse Projects permission
4. **Rotate tokens**: Regenerate API tokens periodically (Atlassian requires yearly rotation since 2025)

### Troubleshooting

#### 401 Authentication Error

- Verify email matches the account that generated the token
- Check base64 encoding (use `echo -n` to avoid newlines)
- Ensure format is `Basic <base64>` with space after "Basic"
- API token must be from id.atlassian.com, not admin.atlassian.com

#### Empty Description

- Use `{{issue.description.html.jsonEncode}}` for proper formatting
- Check if the issue actually has a description

#### Web Request Fails

- Verify the service user has project access
- Check the URL format matches your Jira instance type

### Example: Complete Automation Rule

```
TRIGGER: Manually triggered
  ↓
ACTION: Send web request
  URL: {{baseUrl}}/rest/agile/1.0/board?projectKeyOrId={{project.key}}
  Headers: Authorization: Basic [hidden]
  ↓
ACTION: Send email
  To: your-email@company.com
  Subject: [AUTO-INVITE] {{issue.summary}}
  Body: { JSON payload }
```

### Related Documentation

- [YOURTEMPLATE.md](./YOURTEMPLATE.md) - Create custom email templates
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Common issues and solutions
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Technical details
