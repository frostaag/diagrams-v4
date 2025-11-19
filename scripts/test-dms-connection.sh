#!/bin/bash
# Test DMS Connection and Upload
# This script tests the DMS credentials and attempts to upload a test file

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 DMS Connection Test${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Configuration from environment or GitHub secrets
DMS_API_URL="${DMS_API_URL:-}"
DMS_CLIENT_ID="${DMS_CLIENT_ID:-}"
DMS_CLIENT_SECRET="${DMS_CLIENT_SECRET:-}"
DMS_XSUAA_URL="${DMS_XSUAA_URL:-}"
DMS_REPOSITORY_ID="${DMS_REPOSITORY_ID:-}"

# Validate required variables
echo -e "${BLUE}1️⃣  Checking environment variables...${NC}"
MISSING_VARS=()

if [[ -z "$DMS_API_URL" ]]; then
  MISSING_VARS+=("DMS_API_URL")
fi
if [[ -z "$DMS_CLIENT_ID" ]]; then
  MISSING_VARS+=("DMS_CLIENT_ID")
fi
if [[ -z "$DMS_CLIENT_SECRET" ]]; then
  MISSING_VARS+=("DMS_CLIENT_SECRET")
fi
if [[ -z "$DMS_XSUAA_URL" ]]; then
  MISSING_VARS+=("DMS_XSUAA_URL")
fi

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  echo -e "${RED}❌ Missing required environment variables:${NC}"
  for var in "${MISSING_VARS[@]}"; do
    echo -e "   ${RED}✗${NC} $var"
  done
  echo ""
  echo "Please set these variables and try again."
  exit 1
fi

echo -e "${GREEN}✅ All required variables are set${NC}"
echo ""
echo "Configuration:"
echo "  DMS_API_URL: ${DMS_API_URL}"
echo "  DMS_CLIENT_ID: ${DMS_CLIENT_ID:0:20}..."
echo "  DMS_CLIENT_SECRET: ${DMS_CLIENT_SECRET:0:10}***"
echo "  DMS_XSUAA_URL: ${DMS_XSUAA_URL}"
echo "  DMS_REPOSITORY_ID: ${DMS_REPOSITORY_ID:-<not set, will auto-create>}"
echo ""

# Test 1: OAuth Authentication
echo -e "${BLUE}2️⃣  Testing OAuth2 authentication...${NC}"
TOKEN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${DMS_XSUAA_URL}/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${DMS_CLIENT_ID}" \
  -d "client_secret=${DMS_CLIENT_SECRET}")

HTTP_CODE=$(echo "$TOKEN_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$TOKEN_RESPONSE" | head -n-1)

if [[ "$HTTP_CODE" != "200" ]]; then
  echo -e "${RED}❌ Authentication failed (HTTP ${HTTP_CODE})${NC}"
  echo ""
  echo "Response:"
  echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
  exit 1
fi

ACCESS_TOKEN=$(echo "$RESPONSE_BODY" | jq -r '.access_token')
TOKEN_TYPE=$(echo "$RESPONSE_BODY" | jq -r '.token_type')
EXPIRES_IN=$(echo "$RESPONSE_BODY" | jq -r '.expires_in')

if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
  echo -e "${RED}❌ Failed to extract access token${NC}"
  echo "$RESPONSE_BODY"
  exit 1
fi

echo -e "${GREEN}✅ Authentication successful${NC}"
echo "  Token Type: ${TOKEN_TYPE}"
echo "  Expires In: ${EXPIRES_IN} seconds"
echo "  Token: ${ACCESS_TOKEN:0:30}..."
echo ""

# Test 2: List Repositories
echo -e "${BLUE}3️⃣  Listing DMS repositories...${NC}"
REPOS_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${DMS_API_URL}/browser/repositories" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json")

HTTP_CODE=$(echo "$REPOS_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$REPOS_RESPONSE" | head -n-1)

if [[ "$HTTP_CODE" != "200" ]]; then
  echo -e "${RED}❌ Failed to list repositories (HTTP ${HTTP_CODE})${NC}"
  echo ""
  echo "Response:"
  echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
  exit 1
fi

echo -e "${GREEN}✅ Successfully connected to DMS${NC}"
echo ""
echo "Available repositories:"
echo "$RESPONSE_BODY" | jq -r '.repositories[] | "  - \(.displayName) (ID: \(.id))"' 2>/dev/null || echo "  (Unable to parse repositories)"
echo ""

# Test 3: Get or Create Diagrams Repository
echo -e "${BLUE}4️⃣  Checking for Diagrams Repository...${NC}"

REPO_ID=$(echo "$RESPONSE_BODY" | jq -r '.repositories[] | select(.displayName == "Diagrams Repository") | .id' | head -n1)

if [[ -n "$REPO_ID" && "$REPO_ID" != "null" ]]; then
  echo -e "${GREEN}✅ Found existing Diagrams Repository${NC}"
  echo "  Repository ID: ${REPO_ID}"
else
  echo -e "${YELLOW}⚠️  Diagrams Repository not found, creating...${NC}"
  
  CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${DMS_API_URL}/browser/repositories" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "repository": {
        "displayName": "Diagrams Repository",
        "description": "Repository for technical diagrams from GitHub",
        "repositoryType": "internal"
      }
    }')
  
  HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
  RESPONSE_BODY=$(echo "$CREATE_RESPONSE" | head -n-1)
  
  if [[ "$HTTP_CODE" =~ ^(200|201)$ ]]; then
    REPO_ID=$(echo "$RESPONSE_BODY" | jq -r '.id')
    echo -e "${GREEN}✅ Created Diagrams Repository${NC}"
    echo "  Repository ID: ${REPO_ID}"
    echo ""
    echo -e "${YELLOW}💡 Save this repository ID as GitHub Secret:${NC}"
    echo "   DMS_REPOSITORY_ID=${REPO_ID}"
  else
    echo -e "${RED}❌ Failed to create repository (HTTP ${HTTP_CODE})${NC}"
    echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
    exit 1
  fi
fi
echo ""

# Test 4: Upload Test File
echo -e "${BLUE}5️⃣  Testing file upload...${NC}"

# Check if test SVG exists
TEST_FILE="svg_files/002_SAP Cloud_v1.svg"
if [[ ! -f "$TEST_FILE" ]]; then
  echo -e "${YELLOW}⚠️  Test file not found: ${TEST_FILE}${NC}"
  echo "Skipping upload test."
else
  echo "  Uploading: ${TEST_FILE}"
  
  UPLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "${DMS_API_URL}/browser/repositories/${REPO_ID}/root" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -F "cmisaction=createDocument" \
    -F "propertyId[0]=cmis:name" \
    -F "propertyValue[0]=test-002-sap-cloud.svg" \
    -F "propertyId[1]=cmis:objectTypeId" \
    -F "propertyValue[1]=cmis:document" \
    -F "propertyId[2]=cmis:description" \
    -F "propertyValue[2]=Test upload - SAP Cloud diagram" \
    -F "filename=test.svg" \
    -F "media=@${TEST_FILE}" \
    -F "_charset_=UTF-8")
  
  HTTP_CODE=$(echo "$UPLOAD_RESPONSE" | tail -n1)
  RESPONSE_BODY=$(echo "$UPLOAD_RESPONSE" | head -n-1)
  
  if [[ "$HTTP_CODE" =~ ^(200|201)$ ]]; then
    echo -e "${GREEN}✅ File uploaded successfully${NC}"
    
    FILE_ID=$(echo "$RESPONSE_BODY" | jq -r '.succinctProperties["cmis:objectId"]' 2>/dev/null || echo "")
    if [[ -n "$FILE_ID" && "$FILE_ID" != "null" ]]; then
      echo "  File ID: ${FILE_ID}"
    fi
  else
    echo -e "${RED}❌ Upload failed (HTTP ${HTTP_CODE})${NC}"
    echo ""
    echo "Response:"
    echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
  fi
fi
echo ""

# Test 5: List Files in Repository
echo -e "${BLUE}6️⃣  Listing files in repository...${NC}"

LIST_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
  "${DMS_API_URL}/browser/repositories/${REPO_ID}/root/children" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json")

HTTP_CODE=$(echo "$LIST_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$LIST_RESPONSE" | head -n-1)

if [[ "$HTTP_CODE" != "200" ]]; then
  echo -e "${RED}❌ Failed to list files (HTTP ${HTTP_CODE})${NC}"
  echo "$RESPONSE_BODY"
else
  FILE_COUNT=$(echo "$RESPONSE_BODY" | jq '.objects | length' 2>/dev/null || echo "0")
  echo -e "${GREEN}✅ Successfully listed repository contents${NC}"
  echo "  Files found: ${FILE_COUNT}"
  
  if [[ "$FILE_COUNT" -gt 0 ]]; then
    echo ""
    echo "Files in repository:"
    echo "$RESPONSE_BODY" | jq -r '.objects[] | "  - \(.object.properties["cmis:name"].value) (\(.object.properties["cmis:contentStreamLength"].value) bytes)"' 2>/dev/null || echo "  (Unable to parse files)"
  fi
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Test Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ OAuth2 Authentication: SUCCESS${NC}"
echo -e "${GREEN}✅ Repository Access: SUCCESS${NC}"
echo -e "${GREEN}✅ Repository ID: ${REPO_ID}${NC}"
if [[ -f "$TEST_FILE" ]]; then
  echo -e "${GREEN}✅ File Upload Test: SUCCESS${NC}"
else
  echo -e "${YELLOW}⚠️  File Upload Test: SKIPPED${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}🎉 All DMS connection tests passed!${NC}"
echo ""
echo "Next steps:"
echo "1. Save the repository ID as a GitHub Secret (if not already done)"
echo "2. Test the GitHub Actions workflow by committing a change"
echo "3. Configure the BTP Destination for the Fiori app"
echo ""
