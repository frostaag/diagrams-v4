#!/bin/bash

# Diagrams-v4 SharePoint Upload Script
# Uploads CHANGELOG.csv to SharePoint and sends Teams notifications
# Non-blocking: failures will be logged but won't stop the workflow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "📤 Starting SharePoint upload and Teams notification..."

# Check if changelog exists (try both svg_files and png_files for backward compatibility)
CHANGELOG_PATH=""
if [[ -f "svg_files/CHANGELOG.csv" ]]; then
  CHANGELOG_PATH="svg_files/CHANGELOG.csv"
elif [[ -f "png_files/CHANGELOG.csv" ]]; then
  CHANGELOG_PATH="png_files/CHANGELOG.csv"
else
  echo "⚠️  CHANGELOG.csv not found in svg_files/ or png_files/"
  echo "ℹ️  Skipping upload and notification"
  exit 0
fi

echo "✅ Found changelog at: $CHANGELOG_PATH"

# Get git information (fallback if not in git repo)
if git rev-parse --git-dir > /dev/null 2>&1; then
  commit_hash=$(git log -1 --format="%h" 2>/dev/null || echo "local")
  commit_full_hash=$(git log -1 --format="%H" 2>/dev/null || echo "local")
  author_name=$(git log -1 --format="%an" 2>/dev/null || echo "$(whoami)")
  commit_message=$(git log -1 --format="%s" 2>/dev/null || echo "Manual processing")
else
  commit_hash="local"
  commit_full_hash="local"
  author_name="$(whoami)"
  commit_message="Manual processing"
fi

# Get latest changelog entry for notification
latest_diagram=""
latest_version=""
if [[ -f "$CHANGELOG_PATH" ]]; then
  latest_entry=$(tail -n 1 "$CHANGELOG_PATH")
  if [[ -n "$latest_entry" ]] && [[ "$latest_entry" != "Date,Time,DiagramID"* ]]; then
    latest_diagram=$(echo "$latest_entry" | cut -d',' -f3-4 | tr -d '"')
    latest_version=$(echo "$latest_entry" | cut -d',' -f6 | tr -d '"')
  fi
fi

# Count total diagrams
total_diagrams=$(jq '.diagrams | length' diagram-registry.json 2>/dev/null || echo "0")

echo "📊 Upload Summary:"
echo "  - Latest diagram: $latest_diagram"
echo "  - Version: $latest_version"
echo "  - Total diagrams: $total_diagrams"
echo "  - Author: $author_name"
echo ""

# SharePoint Upload
echo "📁 Uploading to SharePoint..."

# Check if SharePoint credentials are configured
if [[ -z "${SHAREPOINT_TENANT_ID}" ]] || [[ -z "${SHAREPOINT_CLIENT_ID}" ]] || [[ -z "${SHAREPOINT_CLIENT_SECRET}" ]]; then
  echo "⚠️  SharePoint credentials not configured"
  echo "ℹ️  Set environment variables:"
  echo "   - SHAREPOINT_TENANT_ID"
  echo "   - SHAREPOINT_CLIENT_ID"
  echo "   - SHAREPOINT_CLIENT_SECRET"
  echo "   - SHAREPOINT_URL"
  echo "   - SHAREPOINT_DRIVE_ID (optional)"
  echo ""
else
  # Get access token
  ACCESS_TOKEN=$(curl -s -X POST \
    "https://login.microsoftonline.com/${SHAREPOINT_TENANT_ID}/oauth2/v2.0/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${SHAREPOINT_CLIENT_ID}" \
    -d "client_secret=${SHAREPOINT_CLIENT_SECRET}" \
    -d "scope=https://graph.microsoft.com/.default" \
    -d "grant_type=client_credentials" | \
    jq -r '.access_token')
  
  if [[ "$ACCESS_TOKEN" != "null" ]] && [[ -n "$ACCESS_TOKEN" ]]; then
    echo "✅ Got SharePoint access token"
    
    # Parse SharePoint URL
    sharepoint_url="${SHAREPOINT_URL}"
    
    if [[ "$sharepoint_url" =~ https://([^/]+)/sites/([^/]+) ]]; then
      tenant_domain="${BASH_REMATCH[1]}"
      site_name="${BASH_REMATCH[2]}"
      drive_id="${SHAREPOINT_DRIVE_ID}"
      
      echo "📍 Target: $tenant_domain/sites/$site_name"
      
      # If no drive ID configured, auto-discover
      if [[ -z "$drive_id" ]]; then
        echo "🔍 Auto-discovering drive ID..."
        graph_site_url="${tenant_domain}:/sites/${site_name}:"
        
        drives_response=$(curl -s -X GET \
          "https://graph.microsoft.com/v1.0/sites/${graph_site_url}/drives" \
          -H "Authorization: Bearer $ACCESS_TOKEN")
        
        drive_id=$(echo "$drives_response" | jq -r '.value[0].id' 2>/dev/null || echo "")
        
        if [[ -n "$drive_id" ]] && [[ "$drive_id" != "null" ]]; then
          echo "✅ Found drive ID: $drive_id"
        else
          echo "❌ Could not auto-discover drive ID"
          exit 1
        fi
      fi
      
      # Upload to SharePoint
      graph_site_url="${tenant_domain}:/sites/${site_name}:"
      
      upload_response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X PUT \
        "https://graph.microsoft.com/v1.0/sites/${graph_site_url}/drives/${drive_id}/root:/Diagrams/Diagrams_Changelog.csv:/content" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: text/csv" \
        --data-binary @png_files/CHANGELOG.csv)
      
      http_code=$(echo "$upload_response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
      
      if [[ "$http_code" -eq 200 ]] || [[ "$http_code" -eq 201 ]]; then
        echo "✅ Uploaded changelog to SharePoint"
      else
        echo "⚠️  SharePoint upload failed (HTTP $http_code)"
        echo "ℹ️  This is non-critical, continuing..."
      fi
    else
      echo "⚠️  Invalid SharePoint URL format"
    echo "ℹ️  This is non-critical, continuing..."
    fi
  else
    echo "⚠️  Failed to get SharePoint access token"
    echo "ℹ️  This is non-critical, continuing..."
  fi
fi

echo ""

# Teams Notification
echo "💬 Sending Teams notification..."

teams_webhook="${TEAMS_WEBHOOK_URL}"

if [[ -z "$teams_webhook" ]]; then
  echo "⚠️  Teams webhook not configured"
  echo "ℹ️  Set environment variable: TEAMS_WEBHOOK_URL"
  echo ""
else
  # Determine status and color
  if [[ -n "$latest_diagram" ]]; then
    status="✅ Success"
    color="28a745"
    summary="Diagram processed: $latest_diagram ($latest_version)"
  else
    status="ℹ️ No Changes"
    color="ffc107"
    summary="No new diagrams processed"
  fi
  
  # Escape strings for JSON
  escaped_commit_message=$(echo "$commit_message" | sed 's/"/\\"/g')
  escaped_author_name=$(echo "$author_name" | sed 's/"/\\"/g')
  escaped_latest_diagram=$(echo "$latest_diagram" | sed 's/"/\\"/g')
  
  # Send Teams notification
  teams_response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X POST "$teams_webhook" \
    -H "Content-Type: application/json" \
    -d "{
      \"@type\": \"MessageCard\",
      \"@context\": \"https://schema.org/extensions\",
      \"summary\": \"Diagrams-v4 Processing\",
      \"themeColor\": \"$color\",
      \"title\": \"📊 Diagrams-v4 Processing Complete\",
      \"text\": \"**Status:** $status - $summary\",
      \"sections\": [{
        \"activityTitle\": \"📋 Processing Details\",
        \"facts\": [
          {\"name\": \"👤 Author\", \"value\": \"$escaped_author_name\"},
          {\"name\": \"📝 Commit\", \"value\": \"$commit_hash\"},
          {\"name\": \"💬 Message\", \"value\": \"$escaped_commit_message\"},
          {\"name\": \"📊 Latest Diagram\", \"value\": \"$escaped_latest_diagram\"},
          {\"name\": \"🔢 Version\", \"value\": \"$latest_version\"},
          {\"name\": \"📈 Total Diagrams\", \"value\": \"$total_diagrams\"}
        ]
      }]
    }")
  
  http_code=$(echo "$teams_response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
  
  if [[ "$http_code" -eq 200 ]] || [[ "$http_code" -eq 202 ]]; then
    echo "✅ Teams notification sent"
  else
    echo "⚠️  Teams notification failed (HTTP $http_code)"
    echo "ℹ️  Response: $(echo "$teams_response" | sed 's/HTTPSTATUS.*//')"
    echo "ℹ️  This is non-critical, continuing..."
  fi
fi

echo ""
echo "✅ Upload process complete"
exit 0
