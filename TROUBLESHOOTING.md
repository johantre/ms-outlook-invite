# Troubleshooting

Common issues and solutions for the MS Outlook Auto-Invite solution.

## Jira Automation "some errors"
Check error in automation logs:
- Mail problem?
    - mail recepient correct?
- Web request problem?
    - API token expired? 
    - Correct end point URL?
Try 
- re-importing automation (guaranteed working)
- re-create API token
More info [JIRA-AUTOMATION.md](./JIRA-AUTOMATION.md)

## Power Automate Flow Not Triggering

### Email not being processed
- Verify the email subject contains `[AUTO-INVITE]`
- Check that the email reached the AUTO-INVITE folder
- Ensure the flow is **turned on** in Power Automate
- Check flow run history for error messages

### Folder ID mismatch
Each Outlook folder has an internal ID. If you renamed, removed, or recreated the `AUTO-INVITE` folder, the automation will fail because it references the old folder ID.

The folder ID is stored in the [Workflow JSON](solution/Workflows/ms-outlook-invite-office365-flow-6659800E-7EF1-F011-8406-00224885F6FF.json) at these paths:
- `triggers > action name > metadata > Id:`
- `triggers > action name > inputs > parameters > folderPath:`

**Solution**: Re-import the Power Automate solution and reconfigure the trigger to point to the new folder.

## Invalid JSON Error

The email body must contain valid JSON. Common issues:

- **Line breaks**: Ensure no unexpected line breaks in the email body
- **Missing commas**: Check for missing commas between fields
- **Unescaped quotes**: Use `\"` for quotes inside string values
- **Trailing commas**: Remove commas after the last field

**Validate your JSON** using [jsonlint.com](https://jsonlint.com) before sending.

### Example of valid JSON
Check for valid JSON [JIRA-AUTOMATION.md](./JIRA-AUTOMATION.md)

## Calendar Event Not Created

- Verify your Outlook connection in Power Automate is still valid
- Check that you have calendar write permissions
- Review the flow run history for detailed error messages
- Ensure the Parse JSON step succeeded (check its output)

## Attendees Not Formatted Correctly

- Use semicolons (`;`) or commas (`,`) to separate email addresses
- Ensure all email addresses are valid
- Avoid spaces before/after separators

**Correct**: `john@company.com; jane@company.com`

**Incorrect**: `john@company.com ; jane@company.com` (space before semicolon)

## Description Shows Raw Markup

If you see wiki markup like `||header||` or `*bullet*` instead of formatted text:

- In Jira Automation, use `{{issue.description.html.jsonEncode}}` instead of `{{issue.description}}`
- The `.html` converts wiki markup to HTML
- The `.jsonEncode` escapes it for JSON transport

## Description is Empty

If the description field is empty in your calendar invite:

1. **Check the source**: Verify the Jira issue actually has a description
2. **Check the email**: Look at the raw email body - is the description field populated?
3. **Check Power Automate**: Look at the Parse JSON step output
4. **Smart value issue**: Some Jira smart values return empty for certain field types. Try:
   - `{{issue.description}}` - raw text
   - `{{issue.description.html}}` - as HTML
   - `{{issue.description.html.jsonEncode}}` - HTML escaped for JSON

## Testing & Debugging

### Testing without Jira
You can test the Power Automate flow by manually sending an email:
1. Send an email to yourself
2. Subject: `[AUTO-INVITE] Test Meeting`
3. Body: Valid JSON (plain text, NOT HTML formatted)

### Checking logs
- **Power Automate**: Go to flow run history to see each step's input/output
- **Jira Automation**: Check the automation audit log for sent emails

### Expected timing
- Jira automations: Usually instant
- Email delivery: Usually instant
- Power Automate trigger: A few seconds (not 5 minutes)

If Power Automate takes too long, check if the flow is in a "Suspended" state.

## Known Limitations

- **Manual coordination required**: Attendees are not auto-invited; you must find time slots manually
- **Outlook/Exchange only**: Power Automate's calendar connector only works with Microsoft 365
- **Plain text email body**: The JSON must be in plain text, not HTML formatted email
- **No attachments**: The automation only reads the email body, not attachments
- **Default 1-hour duration**: Meeting duration is hardcoded to 1 hour

## Still Having Issues?

- **GitHub Issues**: [Report a bug](../../issues)
- **GitHub Discussions**: [Ask a question](../../discussions)
