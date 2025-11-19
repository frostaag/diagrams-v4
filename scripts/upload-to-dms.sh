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
DMS_REPOSITORY_ID="${DMS_REPOSITORY_ID:-}"

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

# Get OAuth2 token from XSUAA
TOKEN_RESPONSE=$(curl -s -X POST "${DMS_XSUAA_URL}/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${DMS_CLIENT_ID}" \
  -d "client_secret=${DMS_CLIENT_SECRET}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
  echo -e "${RED}❌ Failed to obtain access token${NC}"
  echo "Response: $TOKEN_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✅ Authentication successful${NC}"

# Function to get or create repository
get_or_create_repository() {
  if [[ -n "$DMS_REPOSITORY_ID" ]]; then
    echo -e "${BLUE}ℹ️  Using existing repository ID: ${DMS_REPOSITORY_ID}${NC}"
    echo "$DMS_REPOSITORY_ID"
    return
  fi
  
  echo -e "${BLUE}🔍 Searching for diagrams repository...${NC}"
  
  # List all repositories
  REPOS_RESPONSE=$(curl -s -X GET "${DMS_API_URL}/browser/repositories" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json")
  
  # Try to find existing diagrams repository
  REPO_ID=$(echo "$REPOS_RESPONSE" | jq -r '.repositories[] | select(.displayName == "Diagrams Repository") | .id' | head -n1)
  
  if [[ -n "$REPO_ID" && "$REPO_ID" != "null" ]]; then
    echo -e "${GREEN}✅ Found existing repository: ${REPO_ID}${NC}"
    echo "$REPO_ID"
    return
  fi
  
  echo -e "${YELLOW}⚠️  Repository not found, creating new one...${NC}"
  
  # Create new repository
  CREATE_RESPONSE=$(curl -s -X POST "${DMS_API_URL}/browser/repositories" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "repository": {
        "displayName": "Diagrams Repository",
        "description": "Repository for technical diagrams from GitHub",
        "repositoryType": "internal"
      }
    }')
  
  NEW_REPO_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id')
  
  if [[ -z "$NEW_REPO_ID" || "$NEW_REPO_ID" == "null" ]]; then
    echo -e "${RED}❌ Failed to create repository${NC}"
    echo "Response: $CREATE_RESPONSE"
    exit 1
  fi
  
  echo -e "${GREEN}✅ Created new repository: ${NEW_REPO_ID}${NC}"
  echo -e "${YELLOW}💡 Add this to GitHub Secrets as DMS_REPOSITORY_ID: ${NEW_REPO_ID}${NC}"
  echo "$NEW_REPO_ID"
}

# Get repository ID
REPO_ID=$(get_or_create_repository)

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
  
  # Check if file already exists in DMS
  local existing_file=$(curl -s -X GET "${DMS_API_URL}/browser/repositories/${REPO_ID}/root/children" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json" | \
    jq -r ".objects[] | select(.object.properties[\"cmis:name\"].value == \"${filename}\") | .object.id")
  
  if [[ -n "$existing_file" && "$existing_file" != "null" ]]; then
    echo -e "${YELLOW}⚠️  File already exists, updating...${NC}"
    
    # Update existing file content
    UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT \
      "${DMS_API_URL}/browser/repositories/${REPO_ID}/root/${filename}/content" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: image/svg+xml" \
      -H "cmis:name: ${filename}" \
      --data-binary "@${svg_file}" 2>&1)
    
    HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$UPLOAD_RESPONSE" | head -n-1)
    
    # Debug output
    echo -e "${BLUE}Debug: HTTP Code = '${HTTP_CODE}'${NC}"
    echo -e "${BLUE}Debug: Response Body = '${RESPONSE_BODY}'${NC}"
    
    if [[ "$HTTP_CODE" =~ ^(200|201|204)$ ]]; then
      echo -e "${GREEN}✅ Updated ${filename}${NC}"
      
      # Update metadata
      if [[ -n "$name" ]]; then
        curl -s -X PATCH "${DMS_API_URL}/browser/repositories/${REPO_ID}/root/${filename}" \
          -H "Authorization: Bearer ${ACCESS_TOKEN}" \
          -H "Content-Type: application/json" \
          -d "{
            \"properties\": {
              \"cmis:description\": \"${description}\",
              \"sap:category\": \"${category}\"
            }
          }" > /dev/null
      fi
      
      return 0
    else
      echo -e "${RED}❌ Failed to update ${filename} (HTTP ${HTTP_CODE})${NC}"
      echo "$RESPONSE_BODY"
      return 1
    fi
  else
    # Create new file
    echo -e "${BLUE}Debug: Creating new file at ${DMS_API_URL}/browser/repositories/${REPO_ID}/root${NC}"
    
    UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
      "${DMS_API_URL}/browser/repositories/${REPO_ID}/root" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -F "cmisaction=createDocument" \
      -F "propertyId[0]=cmis:name" \
      -F "propertyValue[0]=${filename}" \
      -F "propertyId[1]=cmis:objectTypeId" \
      -F "propertyValue[1]=cmis:document" \
      -F "propertyId[2]=cmis:description" \
      -F "propertyValue[2]=${description}" \
      -F "filename=${filename}" \
      -F "media=@${svg_file}" \
      -F "_charset_=UTF-8" 2>&1)
    
    HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$UPLOAD_RESPONSE" | head -n-1)
    
    # Debug output
    echo -e "${BLUE}Debug: HTTP Code = '${HTTP_CODE}'${NC}"
    echo -e "${BLUE}Debug: Response Body (first 500 chars) = '${RESPONSE_BODY:0:500}'${NC}"
    
    if [[ "$HTTP_CODE" =~ ^(200|201)$ ]]; then
      echo -e "${GREEN}✅ Uploaded ${filename}${NC}"
      return 0
    else
      echo -e "${RED}❌ Failed to upload ${filename} (HTTP ${HTTP_CODE})${NC}"
      echo "$RESPONSE_BODY"
      return 1
    fi
  fi
}

# Main upload logic
echo -e "${BLUE}📂 Processing SVG files...${NC}"

SUCCESS_COUNT=0
FAIL_COUNT=0

# Check if svg_files directory exists
if [[ ! -d "svg_files" ]]; then
  echo -e "${RED}❌ svg_files directory not found${NC}"
  exit 1
fi

# Find all SVG files
SVG_FILES=$(find svg_files -name "*.svg" -type f)

if [[ -z "$SVG_FILES" ]]; then
  echo -e "${YELLOW}⚠️  No SVG files found to upload${NC}"
  exit 0
fi

# Upload each file
for svg_file in $SVG_FILES; do
  if upload_file "$svg_file"; then
    ((SUCCESS_COUNT++))
  else
    ((FAIL_COUNT++))
  fi
done

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
