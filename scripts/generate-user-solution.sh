#!/bin/bash
#
# generate-user-solution.sh
#
# Generates a user-specific Power Automate solution with:
# - Unique GUID for the workflow (prevents duplicate key error on import)
# - Username in solution name (for identification)
#
# Usage: ./generate-user-solution.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "=========================================="
echo "  Power Automate Solution Generator"
echo "  for ms-outlook-invite-office365"
echo "=========================================="
echo ""

# Ask for username
read -p "Enter the username (e.g. johan.tre or test.user; 1st part mail before @): " USERNAME

if [[ -z "$USERNAME" ]]; then
    echo -e "${RED}Error: Username is required.${NC}"
    exit 1
fi

# Sanitize username for filenames (replace . and @ with _)
USERNAME_SAFE=$(echo "$USERNAME" | sed 's/[.@]/_/g' | tr '[:upper:]' '[:lower:]')

echo ""
echo -e "${YELLOW}Username:  ${NC}$USERNAME"
echo -e "${YELLOW}Safe name: ${NC}$USERNAME_SAFE"

# Find the most recent solution version (directories only, no zips or copies)
LATEST_SOLUTION_DIR=""
for dir in "$REPO_ROOT"/msoutlookinviteoffice365_*/; do
    if [[ -d "$dir" ]] && [[ ! "$dir" =~ \( ]]; then
        LATEST_SOLUTION_DIR="$dir"
    fi
done

# Remove trailing slash
LATEST_SOLUTION_DIR="${LATEST_SOLUTION_DIR%/}"

if [[ -z "$LATEST_SOLUTION_DIR" ]] || [[ ! -d "$LATEST_SOLUTION_DIR" ]]; then
    echo -e "${RED}Error: No solution directory found in $REPO_ROOT${NC}"
    exit 1
fi

# Extract version from directory name
VERSION=$(basename "$LATEST_SOLUTION_DIR" | sed 's/msoutlookinviteoffice365_//' | tr '_' '.')
echo -e "${YELLOW}Source solution: ${NC}$(basename "$LATEST_SOLUTION_DIR") (version $VERSION)"

# Define output directory and zip
OUTPUT_DIR="$REPO_ROOT/output/${USERNAME_SAFE}"
OUTPUT_ZIP="$REPO_ROOT/output/msoutlookinviteoffice365_${USERNAME_SAFE}_${VERSION//./_}.zip"

# Create output directory
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"/*

echo ""
echo "Copying solution files..."
cp -r "$LATEST_SOLUTION_DIR"/* "$OUTPUT_DIR/"

# Generate new GUID
NEW_GUID=$(cat /proc/sys/kernel/random/uuid)
NEW_GUID_UPPER=$(echo "$NEW_GUID" | tr '[:lower:]' '[:upper:]')
NEW_GUID_LOWER=$(echo "$NEW_GUID" | tr '[:upper:]' '[:lower:]')

echo -e "${GREEN}New workflow GUID: ${NC}$NEW_GUID_LOWER"

# Find the current workflow GUID from solution.xml
OLD_GUID_LOWER=$(grep -oP 'id="\{[a-f0-9-]+\}"' "$OUTPUT_DIR/solution.xml" | head -1 | sed 's/id="{\([^}]*\)}"/\1/')
OLD_GUID_UPPER=$(echo "$OLD_GUID_LOWER" | tr '[:lower:]' '[:upper:]')

if [[ -z "$OLD_GUID_LOWER" ]]; then
    echo -e "${RED}Error: Could not find workflow GUID in solution.xml${NC}"
    exit 1
fi

echo -e "${YELLOW}Old workflow GUID: ${NC}$OLD_GUID_LOWER"

# Find the old workflow JSON file
OLD_WORKFLOW_FILE=$(find "$OUTPUT_DIR/Workflows" -name "*.json" | head -1)
OLD_WORKFLOW_BASENAME=$(basename "$OLD_WORKFLOW_FILE")

if [[ -z "$OLD_WORKFLOW_FILE" ]]; then
    echo -e "${RED}Error: No workflow JSON found in $OUTPUT_DIR/Workflows${NC}"
    exit 1
fi

# Determine the new workflow filename
# Format: ms-outlook-invite-office365-flow-importable-{GUID}.json
FLOW_NAME_BASE=$(echo "$OLD_WORKFLOW_BASENAME" | sed "s/-$OLD_GUID_UPPER\.json//")
NEW_WORKFLOW_BASENAME="${FLOW_NAME_BASE}-${NEW_GUID_UPPER}.json"
NEW_WORKFLOW_FILE="$OUTPUT_DIR/Workflows/$NEW_WORKFLOW_BASENAME"

echo ""
echo "Replacing GUIDs and names in files..."

# 1. Replace in solution.xml
# - RootComponent id
# - Solution UniqueName
# - Solution LocalizedName (display name)
sed -i "s/$OLD_GUID_LOWER/$NEW_GUID_LOWER/gi" "$OUTPUT_DIR/solution.xml"
sed -i "s/<UniqueName>msoutlookinviteoffice365<\/UniqueName>/<UniqueName>msoutlookinviteoffice365_${USERNAME_SAFE}<\/UniqueName>/" "$OUTPUT_DIR/solution.xml"
sed -i "s/description=\"ms-outlook-invite-office365\"/description=\"ms-outlook-invite-office365 (${USERNAME})\"/" "$OUTPUT_DIR/solution.xml"

echo "  - solution.xml: GUID and names updated"

# 2. Replace in customizations.xml
# - WorkflowId (lowercase with braces)
# - JsonFileName (uppercase in filename)
# First WorkflowId (lowercase)
sed -i "s/WorkflowId=\"{$OLD_GUID_LOWER}\"/WorkflowId=\"{$NEW_GUID_LOWER}\"/gi" "$OUTPUT_DIR/customizations.xml"
# Then JsonFileName (uppercase)
sed -i "s/$OLD_GUID_UPPER/$NEW_GUID_UPPER/g" "$OUTPUT_DIR/customizations.xml"

echo "  - customizations.xml: GUID updated"

# 3. Rename workflow JSON file
mv "$OLD_WORKFLOW_FILE" "$NEW_WORKFLOW_FILE"

echo "  - Workflow file renamed to: $NEW_WORKFLOW_BASENAME"

# 4. Create the zip
echo ""
echo "Creating solution package (.zip)..."

# Remove old zip if it exists
rm -f "$OUTPUT_ZIP"

# Create zip from output directory
cd "$OUTPUT_DIR"
zip -r "$OUTPUT_ZIP" . -x "*.DS_Store"
cd "$REPO_ROOT"

echo ""
echo -e "${GREEN}=========================================="
echo -e "  DONE!"
echo -e "==========================================${NC}"
echo ""
echo -e "Solution package created:"
echo -e "  ${GREEN}$OUTPUT_ZIP${NC}"
echo ""
echo -e "Details:"
echo -e "  User:          $USERNAME"
echo -e "  Solution name: msoutlookinviteoffice365_${USERNAME_SAFE}"
echo -e "  Display name:  ms-outlook-invite-office365 (${USERNAME})"
echo -e "  Workflow GUID: $NEW_GUID_LOWER"
echo -e "  Version:       $VERSION"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Go to https://make.powerautomate.com"
echo -e "  2. Log in as $USERNAME"
echo -e "  3. Go to Solutions > Import solution"
echo -e "  4. Upload: $(basename "$OUTPUT_ZIP")"
echo -e "  5. Connect your own Office 365 connection"
echo ""
