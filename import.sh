#!/bin/bash

# ─────────────────────────────────────────────
# GitHub Issue Importer from CSV
# Usage: ./import_issues.sh
# ─────────────────────────────────────────────

# ── Config ────────────────────────────────────
GITHUB_TOKEN=""         # Your GitHub personal access token
REPO_OWNER=""           # Your GitHub username
REPO_NAME=""            # Your repository name
CSV_FILE="adsb_tracker_issues.csv"
# ─────────────────────────────────────────────

# ── Validation ────────────────────────────────
if [[ -z "$GITHUB_TOKEN" || -z "$REPO_OWNER" || -z "$REPO_NAME" ]]; then
  echo "❌ Error: Please fill in GITHUB_TOKEN, REPO_OWNER, and REPO_NAME at the top of the script."
  exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
  echo "❌ Error: CSV file '$CSV_FILE' not found. Make sure it's in the same directory as this script."
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "❌ Error: 'jq' is required but not installed. Install it with: sudo apt install jq"
  exit 1
fi

API_BASE="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"

# ── Helper: Create label if it doesn't exist ──
create_label_if_missing() {
  local label="$1"
  local color="$2"

  existing=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "${API_BASE}/labels/$(python3 -c "import urllib.parse; print(urllib.parse.quote('${label}'))")")

  if [[ "$existing" == "404" ]]; then
    curl -s -o /dev/null \
      -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "${API_BASE}/labels" \
      -d "{\"name\": \"${label}\", \"color\": \"${color}\"}"
    echo "  🏷️  Created label: ${label}"
  fi
}

# ── Helper: Create milestone if it doesn't exist ──
declare -A MILESTONE_IDS

create_milestone_if_missing() {
  local milestone="$1"

  if [[ -n "${MILESTONE_IDS[$milestone]}" ]]; then
    return
  fi

  existing=$(curl -s \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "${API_BASE}/milestones" | jq -r ".[] | select(.title == \"${milestone}\") | .number")

  if [[ -n "$existing" ]]; then
    MILESTONE_IDS[$milestone]=$existing
  else
    response=$(curl -s \
      -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "${API_BASE}/milestones" \
      -d "{\"title\": \"${milestone}\"}")
    MILESTONE_IDS[$milestone]=$(echo "$response" | jq -r '.number')
    echo "  🪨  Created milestone: ${milestone} (#${MILESTONE_IDS[$milestone]})"
  fi
}

# ── Create labels ──────────────────────────────
echo ""
echo "🏷️  Setting up labels..."
create_label_if_missing "hardware-interface" "0075ca"
create_label_if_missing "signal-processing"  "e4e669"
create_label_if_missing "packet-decoding"    "d93f0b"
create_label_if_missing "map-renderer"       "0e8a16"
create_label_if_missing "stretch-goals"      "6f42c1"
create_label_if_missing "setup"              "cfd3d7"

# ── Parse CSV and create issues ───────────────
echo ""
echo "📋 Importing issues from ${CSV_FILE}..."
echo ""

SUCCESS=0
FAILED=0
ROW=0

while IFS= read -r line || [[ -n "$line" ]]; do
  ROW=$((ROW + 1))

  # Skip header row
  if [[ $ROW -eq 1 ]]; then
    continue
  fi

  # Parse CSV columns using python3 for reliable quoted field handling
  TITLE=$(echo "$line" | python3 -c "
import sys, csv
row = next(csv.reader([sys.stdin.read().strip()]))
print(row[0] if len(row) > 0 else '')
")
  BODY=$(echo "$line" | python3 -c "
import sys, csv
row = next(csv.reader([sys.stdin.read().strip()]))
print(row[1] if len(row) > 1 else '')
")
  LABELS_RAW=$(echo "$line" | python3 -c "
import sys, csv
row = next(csv.reader([sys.stdin.read().strip()]))
print(row[2] if len(row) > 2 else '')
")
  MILESTONE=$(echo "$line" | python3 -c "
import sys, csv
row = next(csv.reader([sys.stdin.read().strip()]))
print(row[3] if len(row) > 3 else '')
")

  # Skip empty rows
  if [[ -z "$TITLE" ]]; then
    continue
  fi

  # Build labels JSON array
  LABELS_JSON=$(echo "$LABELS_RAW" | python3 -c "
import sys, json
raw = sys.stdin.read().strip()
labels = [l.strip() for l in raw.split(',') if l.strip()]
print(json.dumps(labels))
")

  # Create milestone if needed and get its number
  create_milestone_if_missing "$MILESTONE"
  MILESTONE_NUMBER="${MILESTONE_IDS[$MILESTONE]}"

  # Build request payload
  PAYLOAD=$(jq -n \
    --arg title "$TITLE" \
    --arg body "$BODY" \
    --argjson labels "$LABELS_JSON" \
    --argjson milestone "$MILESTONE_NUMBER" \
    '{title: $title, body: $body, labels: $labels, milestone: $milestone}')

  # POST the issue
  RESPONSE=$(curl -s \
    -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "${API_BASE}/issues" \
    -d "$PAYLOAD")

  ISSUE_NUMBER=$(echo "$RESPONSE" | jq -r '.number // empty')
  ISSUE_URL=$(echo "$RESPONSE" | jq -r '.html_url // empty')

  if [[ -n "$ISSUE_NUMBER" ]]; then
    echo "  ✅ #${ISSUE_NUMBER} — ${TITLE}"
    echo "     ${ISSUE_URL}"
    SUCCESS=$((SUCCESS + 1))
  else
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // "Unknown error"')
    echo "  ❌ FAILED — ${TITLE}"
    echo "     Reason: ${ERROR_MSG}"
    FAILED=$((FAILED + 1))
  fi

  # Respect GitHub API rate limit (10 req/s for authenticated)
  sleep 0.5

done < "$CSV_FILE"

# ── Summary ───────────────────────────────────
echo ""
echo "─────────────────────────────────────────────"
echo "✅ Created:  ${SUCCESS} issues"
if [[ $FAILED -gt 0 ]]; then
  echo "❌ Failed:   ${FAILED} issues"
fi
echo "🔗 View your board: https://github.com/${REPO_OWNER}/${REPO_NAME}/issues"
echo "─────────────────────────────────────────────"
echo ""