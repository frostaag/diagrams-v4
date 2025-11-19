#!/bin/bash
# Discover CMIS Repository ID for SAP DMS

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 SAP DMS CMIS Repository Discovery Tool${NC}"
echo -e "${BLUE}==========================================${NC}\n"

# Configuration
DMS_API_URL="${DMS_API_URL:-}"
DMS_CLIENT_ID="${DMS_CLIENT_ID:-}"
DMS_CLIENT_SECRET="${DMS_CLIENT_SECRET:-}"
DMS_XSUAA_URL="${DMS_XSUAA_URL:-}"

# Validate required environment variables
if [[ -z "$DMS_API_URL" || -z "$DMS_CLIENT_ID" || -z "$DMS_CLIENT_SECRET" || -z "$DMS_XSUAA_URL" ]]; then
  echo -e "${RED}❌ Error: Missing required DMS configuration${NC}"
  echo ""
  echo "Please set the following environment variables:"
  echo -e "${YELLOW}export DMS_API_URL=\"your-api-url\"${NC}"
  echo -e "${YELLOW}export DMS_CLIENT_ID=\"your-client-id\"${NC}"
  echo -e "${YELLOW}export DMS_CLIENT_SECRET=\"your-client-secret\"${NC}"
  echo -e "${YELLOW}export DMS_XSUAA_URL=\"your-xsuaa-url\"${NC}"
  echo ""
  exit 1
fi

echo -e "${BLUE}📋 Configuration:${NC}"
echo -e "  API URL: ${DMS_API_URL}"
echo -e "  Client ID: ${DMS_CLIENT_ID:0:8}...${DMS_CLIENT_ID: -4}"
echo -e "  XSUAA URL: ${DMS_XSUAA_URL}\n"

echo -e "${BLUE}🔐 Step 1: Authenticating with SAP DMS...${NC}"

# Get OAuth2 token from XSUAA
TOKEN_RESPONSE=$(curl -s -X POST "${DMS_XSUAA_URL}/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=${DMS_CLIENT_ID}" \
  -d "client_secret=${DMS_CLIENT_SECRET}")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
  echo -e "${RED}❌ Failed to obtain access token${NC}"
  echo -e "${YELLOW}Response:${NC}"
  echo "$TOKEN_RESPONSE" | jq '.'
  exit 1
fi

echo -e "${GREEN}✅ Authentication successful${NC}\n"

echo -e "${BLUE}🔍 Step 2: Discovering CMIS Repositories...${NC}"

# List all repositories
REPOS_RESPONSE=$(curl -s -X GET "${DMS_API_URL}/browser/repositories" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json")

# Check if response is valid JSON
if ! echo "$REPOS_RESPONSE" | jq empty 2>/dev/null; then
  echo -e "${RED}❌ Invalid response from DMS API${NC}"
  echo -e "${YELLOW}Response:${NC}"
  echo "$REPOS_RESPONSE"
  exit 1
fi

# Count repositories
REPO_COUNT=$(echo "$REPOS_RESPONSE" | jq '.repositories | length')

if [[ "$REPO_COUNT" -eq 0 ]]; then
  echo -e "${YELLOW}⚠️  No repositories found${NC}"
  echo ""
  echo -e "${BLUE}💡 Recommendation:${NC}"
  echo "  Leave DMS_REPOSITORY_ID empty in GitHub variables"
  echo "  The upload script will automatically create a repository"
  exit 0
fi

echo -e "${GREEN}✅ Found ${REPO_COUNT} repository/repositories${NC}\n"

echo -e "${BLUE}📋 Available CMIS Repositories:${NC}"
echo -e "${BLUE}================================${NC}\n"

# Display all repositories with details
echo "$REPOS_RESPONSE" | jq -r '.repositories[] | 
  "Repository: \(.displayName // .repositoryName // "Unnamed")\n" +
  "  CMIS ID: \(.id)\n" +
  "  Type: \(.repositoryType // "unknown")\n" +
  "  Description: \(.description // "No description")\n"'

echo -e "${BLUE}================================${NC}\n"

# Try to find the diagrams repository
DIAGRAMS_REPO_ID=$(echo "$REPOS_RESPONSE" | jq -r '.repositories[] | select(.displayName == "Diagrams Repository") | .id')

if [[ -n "$DIAGRAMS_REPO_ID" && "$DIAGRAMS_REPO_ID" != "null" ]]; then
  echo -e "${GREEN}✅ Found existing 'Diagrams Repository'${NC}"
  echo -e "${YELLOW}📌 Recommended CMIS Repository ID:${NC}"
  echo -e "${GREEN}   ${DIAGRAMS_REPO_ID}${NC}\n"
  echo -e "${BLUE}💡 Action Required:${NC}"
  echo "  Set this in your GitHub organization variables as:"
  echo -e "  ${YELLOW}DMS_REPOSITORY_ID = ${DIAGRAMS_REPO_ID}${NC}\n"
else
  echo -e "${YELLOW}⚠️  No 'Diagrams Repository' found${NC}\n"
  echo -e "${BLUE}💡 Recommendations:${NC}"
  echo "  Option 1: Leave DMS_REPOSITORY_ID empty - script will auto-create"
  echo "  Option 2: Use one of the repository IDs shown above"
  echo "  Option 3: Create repository manually and set the CMIS ID\n"
fi

echo -e "${BLUE}🔍 Testing Repository Access...${NC}"

# Test accessing the first repository
FIRST_REPO_ID=$(echo "$REPOS_RESPONSE" | jq -r '.repositories[0].id')

if [[ -n "$FIRST_REPO_ID" && "$FIRST_REPO_ID" != "null" ]]; then
  echo -e "Testing repository: ${FIRST_REPO_ID}"
  
  ROOT_TEST=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X GET \
    "${DMS_API_URL}/browser/repositories/${FIRST_REPO_ID}/root" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Accept: application/json")
  
  HTTP_CODE=$(echo "$ROOT_TEST" | grep "HTTP_CODE:" | cut -d: -f2)
  RESPONSE_BODY=$(echo "$ROOT_TEST" | sed '/HTTP_CODE:/d')
  
  if [[ "$HTTP_CODE" == "200" ]]; then
    echo -e "${GREEN}✅ Repository access successful (HTTP ${HTTP_CODE})${NC}\n"
  else
    echo -e "${RED}❌ Repository access failed (HTTP ${HTTP_CODE})${NC}"
    echo -e "${YELLOW}Response:${NC}"
    echo "$RESPONSE_BODY" | jq '.'
    echo ""
  fi
fi

echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}✅ Discovery Complete${NC}"
echo -e "${BLUE}================================${NC}"
