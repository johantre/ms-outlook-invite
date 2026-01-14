import json
import re
import sys
import os

def generate_pa_body(template_path):
    if not os.path.exists(template_path):
        print(f"Error: Template not found at {template_path}")
        return None

    with open(template_path, 'r', encoding='utf-8') as f:
        html = f.read()

    # 1. Minify: remove newlines and extra whitespaces
    html = re.sub(r'\s+', ' ', html).strip()

    # 2. Escape quotes for JSON
    html = html.replace('"', '\\"')

    # 3. Replace Jinja placeholders with Power Automate Concat parts
    # The quotes and commas are critical for the @concat expression
    html = html.replace('{{ ATTENDEES }}', "', body('Parse_JSON')?['attendees'], '")
    html = html.replace('{{ SUMMARY }}', "', body('Parse_JSON')?['subject'], '")
    html = html.replace('{{ DESCRIPTION }}', "', replace(body('Parse_JSON')?['description'], decodeUriComponent('%0A'), '<br>'), '")

    # 4. Wrap the whole thing in the Power Automate concat function
    full_body = f"<p class=\"editor-paragraph\">@{{concat('{html}')}}</p>"
    return full_body

def update_solution_json(json_path, new_body):
    if not os.path.exists(json_path):
        print(f"Error: JSON not found at {json_path}")
        return

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    try:
        # Targeting 'Create_event_(V4)' based on your provided JSON
        data['properties']['definition']['actions']['Create_event_(V4)']['inputs']['parameters']['item/Body'] = new_body

        # Save to a NEW file for safety during testing
        output_path = json_path.replace(".json", "_updated.json")
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        print(f"Success! Updated JSON saved to: {output_path}")
    except KeyError as e:
        print(f"Error: Could not find the path in JSON: {e}")
        # Print keys at the failure level to help debugging if it fails again
        print("Available actions in your JSON are:", data['properties']['definition']['actions'].keys())

if __name__ == "__main__":
    # Get brand name from CLI argument, default to 'bmw'
    brand = sys.argv[1] if len(sys.argv) > 1 else 'bmw'

    template_file = f"templates/mail/{brand}.html.j2"
    workflow_file = "solution/Workflows/ms-outlook-invite-office365-flow-6659800E-7EF1-F011-8406-00224885F6FF.json"

    body_content = generate_pa_body(template_file)
    if body_content:
        update_solution_json(workflow_file, body_content)
