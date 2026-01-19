import json
import re
import sys
import os
from glob import glob

def generate_pa_body(template_path):
    if not os.path.exists(template_path):
        print(f"❌ Error: Template not found at {template_path}")
        sys.exit(1)

    with open(template_path, 'r', encoding='utf-8') as f:
        html = f.read()

    # 1. Minify: remove newlines and extra whitespaces
    html = re.sub(r'\s+', ' ', html).strip()

    # 2. Escape single quotes for Power Automate concat expression (json.dump handles double quotes)
    html = html.replace("'", "''")

    # 3. Replace Jinja placeholders with Power Automate Concat parts
    # The quotes and commas are critical for the @concat expression
    html = html.replace('{{ ATTENDEES }}', "', body('Parse_JSON')?['attendees'], '")
    html = html.replace('{{ SUMMARY }}', "', body('Parse_JSON')?['subject'], '")
    html = html.replace('{{ DESCRIPTION }}', "', replace(body('Parse_JSON')?['description'], decodeUriComponent('%0A'), '<br>'), '")
    html = html.replace('{{ URL }}', "', concat({body('Parse_JSON')?['host']}, '/jira/software/c/projects/', {body('Parse_JSON')?['projectKey']}, '/boards/', {variables('foundBoardId')}, '/backlog?epics=visible&issueParent=', {body('Parse_JSON')?['issueId']}, '&selectedIssue=', {body('Parse_JSON')?['issueKey']}), '")

    # 4. Wrap the whole thing in the Power Automate concat function
    return f"<p class=\"editor-paragraph\">@{{concat('{html}')}}</p>"

def find_single_workflow_json(workflows_dir):
    files = glob(os.path.join(workflows_dir, "*.json"))

    if len(files) == 0:
        print(f"❌ Error: No workflow JSON found in {workflows_dir}")
        sys.exit(1)

    if len(files) > 1:
        print(f"❌ Error: Multiple workflow JSON files found in {workflows_dir}:")
        for f in files:
            print(f"  - {f}")
        sys.exit(1)

    return files[0]

def find_create_event_action(actions: dict):
    matches = [k for k in actions.keys() if re.match(r'^Create_event_.*', k)]

    if len(matches) == 0:
        print("❌ Error: No action matching 'Create_event_*' found.")
        print("Available actions:", actions.keys())
        sys.exit(1)

    if len(matches) > 1:
        print("❌ Error: Multiple actions matching 'Create_event_*' found:")
        for m in matches:
            print(f"  - {m}")
        sys.exit(1)

    return matches[0]

def update_solution_json(workflows_dir, new_body):
    json_path = find_single_workflow_json(workflows_dir)

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    actions = data['properties']['definition']['actions']
    create_event_action = find_create_event_action(actions)

    actions[create_event_action]['inputs']['parameters']['item/body'] = new_body

    output_path = json_path.replace(".json", "_updated.json")

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

    os.replace(output_path, json_path)

    print(f"✅ Updated workflow '{os.path.basename(json_path)}'")
    print(f"✅ Updated action: {create_event_action}")

if __name__ == "__main__":
    # Get brand name from CLI argument, default to 'bmw'
    brand = sys.argv[1] if len(sys.argv) > 1 else 'bmw'

    template_file = f"templates/mail/{brand}.html"
    workflows_dir = "solution/Workflows"

    body_content = generate_pa_body(template_file)
    update_solution_json(workflows_dir, body_content)

