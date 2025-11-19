#!/bin/bash
# Upload SVG files to SAP Document Management Service (DMS)

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DMS_API_URL="${DMS_API_URL:-}"
DMS_CLIENT_ID="${DMS_CLIENT_ID:-}"
DMS_CLIENT_SECRET="${DMS_CLIENT_SECRET:-}"
DMS_XSUAA_URL="${DMS_XSUAA_URL:-}"
DMS_REPOSITORY_ID="${DMS_REPOSITORY_ID:-06b87f25-1e4e-4dfb-8fbb-e5132d74f064}"

# Validate required environment variables
if [[ -z "$DMS_API_URL" || -z "$DMS_CLIENT_ID" || -z "$DMS_CLIENT_SECRET" || -z "$DMS_XSUAA_URL" ]]; then
  echo -e "${RED}❌ Error: Missing required DMS configuration${NC}"
  echo "Required environment variables:"
  echo "  DMS_API_URL"
  echo "  DMS_CLIENT_ID"
  echo "  DMS_CLIENT_SECRET"
  echo "  DMS_XSUAA_URL"
  echo "  DMS_REPOSITORY_ID (optional, will auto-create if missing)"
  exit 1
fi

echo -e "${BLUE}🔐 Authenticating with SAP DMS...${NC}"

# Get OAuth2 token from XSUAA using Basic Auth (recommended approach)
TOKEN_RESPONSE=$(curl -s -X POST "${DMS_XSUAA_URL}/oauth/token" \
  -u "${DMS_CLIENT_ID}:${DMS_CLIENT_SECRET}" \
  -d "grant_type=client_credentials")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
  echo -e "${RED}❌ Failed to obtain access token${NC}"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✅ Authentication successful${NC}"

# Validate repository ID is provided
if [[ -z "$DMS_REPOSITORY_ID" ]]; then
  echo -e "${RED}❌ Error: DMS_REPOSITORY_ID is required${NC}"
  echo "Please set the DMS_REPOSITORY_ID variable with your CMIS repository ID"
  echo "You can find this in your SAP BTP DMS service key or by using the discovery script"
  exit 1
fi

echo -e "${BLUE}ℹ️  Using repository ID: ${DMS_REPOSITORY_ID}${NC}"
REPO_ID="$DMS_REPOSITORY_ID"

# Troubleshooting: Test repository connection using repositoryInfo endpoint
echo -e "${BLUE}🔍 Testing repository connection...${NC}"
REPO_TEST=$(curl -s -w "\n%{http_code}" -X GET \
  "${DMS_API_URL}/${REPO_ID}/root?cmisselector=object" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json" 2>&1)

REPO_HTTP_CODE=$(echo "$REPO_TEST" | tail -n1)
REPO_RESPONSE=$(echo "$REPO_TEST" | head -n-1)

echo -e "${BLUE}🔍 Repository test HTTP code: ${REPO_HTTP_CODE}${NC}"

if [[ "$REPO_HTTP_CODE" =~ ^(200|201)$ ]]; then
  echo -e "${GREEN}✅ Repository accessible${NC}"
  echo -e "${BLUE}🔍 Repository info:${NC}"
  echo "$REPO_RESPONSE" | jq -r 'if .properties then "  Name: \(.properties."cmis:name".value // "N/A")\n  Path: \(.properties."cmis:path".value // "N/A")\n  Type: \(.properties."cmis:objectTypeId".value // "N/A")" else . end' 2>/dev/null || echo "$REPO_RESPONSE"
elif [[ "$REPO_HTTP_CODE" == "404" ]]; then
  echo -e "${YELLOW}⚠️  Root folder not found via standard path${NC}"
  echo -e "${BLUE}Response: ${REPO_RESPONSE}${NC}"
  echo -e "${YELLOW}⚠️  This may be expected - will attempt upload anyway${NC}"
elif [[ "$REPO_HTTP_CODE" == "401" || "$REPO_HTTP_CODE" == "403" ]]; then
  echo -e "${RED}❌ Authentication/Authorization error (${REPO_HTTP_CODE})${NC}"
  echo -e "${YELLOW}⚠️  Token may not have permissions to access this repository${NC}"
  echo -e "${BLUE}Response: ${REPO_RESPONSE}${NC}"
  exit 1
else
  echo -e "${YELLOW}⚠️  Unexpected response code: ${REPO_HTTP_CODE}${NC}"
  echo -e "${BLUE}Response: ${REPO_RESPONSE}${NC}"
  echo -e "${YELLOW}⚠️  Continuing with upload attempt...${NC}"
fi

# Troubleshooting: List repository info
echo -e "${BLUE}🔍 DMS Configuration:${NC}"
echo -e "  API URL: ${DMS_API_URL}"
echo -e "  Repository ID: ${REPO_ID}"
echo -e "  Upload endpoint: ${DMS_API_URL}/browser/${REPO_ID}/root"
echo -e "  Token length: ${#ACCESS_TOKEN} characters"
echo -e "  Token starts with: ${ACCESS_TOKEN:0:20}..."

# Function to upload file to DMS
upload_file() {
  local svg_file="$1"
  local filename=$(basename "$svg_file")
  local diagram_id="${filename%.svg}"
  
  echo -e "${BLUE}📤 Uploading ${filename}...${NC}"
  
  # Get metadata from diagram registry
  local metadata=$(jq -c ".diagrams[] | select(.id==\"$diagram_id\")" diagram-registry.json 2>/dev/null || echo "{}")
  local name=$(echo "$metadata" | jq -r '.name // ""')
  local description=$(echo "$metadata" | jq -r '.description // ""')
  local category=$(echo "$metadata" | jq -r '.category // "General"')
  
  # Create new file using CMIS Browser Binding API
  # Using the exact format recommended by SAP for createDocument
  echo -e "${BLUE}📤 Uploading to: ${DMS_API_URL}/browser/${REPO_ID}/root${NC}" >&2
  echo -e "${BLUE}🔍 File details:${NC}" >&2
  echo -e "  File path: ${svg_file}" >&2
  echo -e "  File exists: $(if [[ -f "${svg_file}" ]]; then echo "YES"; else echo "NO"; fi)" >&2
  echo -e "  Size: $(stat -f%z "${svg_file}" 2>/dev/null || stat -c%s "${svg_file}" 2>/dev/null || echo "unknown") bytes" >&2
  echo -e "  Filename to upload: ${filename}" >&2
  
  # Verify file exists before attempting upload
  if [[ ! -f "${svg_file}" ]]; then
    echo -e "${RED}❌ Error: File not found: ${svg_file}${NC}" >&2
    return 1
  fi
  
  # Capture curl output properly - redirect stderr to a temp file to avoid contamination
  TEMP_ERR=$(mktemp)
  UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${DMS_API_URL}/browser/${REPO_ID}/root" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" \
    -F "cmisaction=createDocument" \
    -F "propertyId[0]=cmis:name" \
    -F "propertyValue[0]=${filename}" \
    -F "propertyId[1]=cmis:objectTypeId" \
    -F "propertyValue[1]=cmis:document" \
    -F "filename=${filename}" \
    -F "_charset=UTF-8" \
    -F "succinct=true" \
    -F "includeAllowableActions=true" \
    -F "media=@${svg_file};type=image/svg+xml" 2>"$TEMP_ERR")
  CURL_STDERR=$(cat "$TEMP_ERR")
  rm -f "$TEMP_ERR"
  
  HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
  RESPONSE_BODY=$(echo "$UPLOAD_RESPONSE" | head -n-1)
  
  # Enhanced debug output
  echo -e "${BLUE}🔍 Upload Response Details:${NC}" >&2
  echo -e "${BLUE}  HTTP Code: '${HTTP_CODE}'${NC}" >&2
  echo -e "${BLUE}  Response length: ${#RESPONSE_BODY} characters${NC}" >&2
  
  # Show curl stderr if present
  if [[ -n "$CURL_STDERR" ]]; then
    echo -e "${YELLOW}  Curl stderr: ${CURL_STDERR}${NC}" >&2
  fi
  
  if [[ -n "$RESPONSE_BODY" ]]; then
    echo -e "${BLUE}  Full Response Body:${NC}" >&2
    echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY" >&2
    
    # Try to parse error details if present
    ERROR_MSG=$(echo "$RESPONSE_BODY" | jq -r '.message // .error // .exception // empty' 2>/dev/null)
    if [[ -n "$ERROR_MSG" ]]; then
      echo -e "${RED}  Error Message: ${ERROR_MSG}${NC}" >&2
    fi
  fi
  
  if [[ "$HTTP_CODE" =~ ^(200|201)$ ]]; then
    echo -e "${GREEN}✅ Uploaded ${filename}${NC}" >&2
    # Show document ID if available
    DOC_ID=$(echo "$RESPONSE_BODY" | jq -r '.succinctProperties."cmis:objectId" // .properties."cmis:objectId".value // empty' 2>/dev/null)
    if [[ -n "$DOC_ID" ]]; then
      echo -e "${GREEN}  Document ID: ${DOC_ID}${NC}" >&2
    fi
    return 0
  else
    echo -e "${RED}❌ Failed to upload ${filename} (HTTP ${HTTP_CODE})${NC}" >&2
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${RED}Troubleshooting Information:${NC}" >&2
    
    case $HTTP_CODE in
      400)
        echo -e "${RED}  Error: Bad Request (400)${NC}" >&2
        echo -e "${YELLOW}  Possible causes:${NC}" >&2
        echo -e "${YELLOW}  - Invalid CMIS parameters${NC}" >&2
        echo -e "${YELLOW}  - Malformed request${NC}" >&2
        echo -e "${YELLOW}  - Invalid file format${NC}" >&2
        ;;
      401)
        echo -e "${RED}  Error: Unauthorized (401)${NC}" >&2
        echo -e "${YELLOW}  Possible causes:${NC}" >&2
        echo -e "${YELLOW}  - Access token expired${NC}" >&2
        echo -e "${YELLOW}  - Invalid authentication${NC}" >&2
        ;;
      403)
        echo -e "${RED}  Error: Forbidden (403)${NC}" >&2
        echo -e "${YELLOW}  Possible causes:${NC}" >&2
        echo -e "${YELLOW}  - Insufficient permissions to create documents${NC}" >&2
        echo -e "${YELLOW}  - Repository access denied${NC}" >&2
        ;;
      404)
        echo -e "${RED}  Error: Not Found (404)${NC}" >&2
        echo -e "${YELLOW}  Possible causes:${NC}" >&2
        echo -e "${YELLOW}  - Repository ID incorrect${NC}" >&2
        echo -e "${YELLOW}  - Invalid API endpoint${NC}" >&2
        ;;
      409)
        echo -e "${RED}  Error: Conflict (409)${NC}" >&2
        echo -e "${YELLOW}  Possible causes:${NC}" >&2
        echo -e "${YELLOW}  - Document with same name already exists${NC}" >&2
        ;;
      500)
        echo -e "${RED}  Error: Internal Server Error (500)${NC}" >&2
        echo -e "${YELLOW}  Possible causes:${NC}" >&2
        echo -e "${YELLOW}  - SAP DMS service issue${NC}" >&2
        echo -e "${YELLOW}  - Backend error${NC}" >&2
        ;;
      "")
        echo -e "${RED}  Error: Empty HTTP code${NC}" >&2
        echo -e "${YELLOW}  Possible causes:${NC}" >&2
        echo -e "${YELLOW}  - Curl command failed${NC}" >&2
        echo -e "${YELLOW}  - Network connectivity issue${NC}" >&2
        echo -e "${YELLOW}  - Invalid URL or endpoint${NC}" >&2
        if [[ -n "$CURL_STDERR" ]]; then
          echo -e "${RED}  Curl error: ${CURL_STDERR}${NC}" >&2
        fi
        ;;
      *)
        echo -e "${RED}  Error: Unexpected HTTP code '${HTTP_CODE}'${NC}" >&2
        ;;
    esac
    
    if [[ -n "$RESPONSE_BODY" ]]; then
      echo -e "${RED}  Full Error Response:${NC}" >&2
      echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY" >&2
    fi
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    return 1
  fi
}

# Main upload logic
echo -e "${BLUE}📤 Processing SVG files...${NC}"

SUCCESS_COUNT=0
FAIL_COUNT=0

# Check if svg_files directory exists
if [[ ! -d "svg_files" ]]; then
  echo -e "${YELLOW}⚠️  svg_files directory not found${NC}"
  echo -e "${YELLOW}ℹ️  This is expected if no diagrams have been converted yet${NC}"
  echo -e "${GREEN}✅ Skipping DMS upload (no files to upload)${NC}"
  exit 0
fi

# Find all SVG files
SVG_FILES=$(find svg_files -name "*.svg" -type f 2>/dev/null || true)

if [[ -z "$SVG_FILES" ]]; then
  echo -e "${YELLOW}⚠️  No SVG files found in svg_files directory${NC}"
  echo -e "${YELLOW}ℹ️  This is expected if no diagrams have been converted yet${NC}"
  echo -e "${GREEN}✅ Skipping DMS upload (no files to upload)${NC}"
  exit 0
fi

echo -e "${BLUE}ℹ️  Found $(echo "$SVG_FILES" | wc -l | tr -d ' ') SVG files to upload${NC}"

# Upload each file
while IFS= read -r svg_file; do
  if upload_file "$svg_file"; then
    ((SUCCESS_COUNT++))
  else
    ((FAIL_COUNT++))
  fi
done <<< "$SVG_FILES"

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Upload Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Successful: ${SUCCESS_COUNT}${NC}"
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo -e "${RED}❌ Failed: ${FAIL_COUNT}${NC}"
fi
echo -e "${BLUE}📍 Repository ID: ${REPO_ID}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi

echo -e "${GREEN}✅ All files uploaded successfully to SAP DMS${NC}"
