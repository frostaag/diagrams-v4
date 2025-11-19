#!/bin/bash
# Deploy Fiori Diagram Viewer to Cloud Foundry

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Deploying Fiori Diagram Viewer to Cloud Foundry${NC}"
echo ""

# Check if logged in to CF
if ! cf target &>/dev/null; then
    echo -e "${RED}❌ Not logged in to Cloud Foundry${NC}"
    echo "Please run: cf login"
    exit 1
fi

echo -e "${GREEN}✅ Logged in to Cloud Foundry${NC}"
cf target

# Check if environment variables are set
if [[ -z "$DMS_CLIENT_ID" || -z "$DMS_CLIENT_SECRET" || -z "$DMS_XSUAA_URL" ]]; then
    echo -e "${YELLOW}⚠️  DMS environment variables not found${NC}"
    echo "The app will run in local mode (without DMS integration)"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Build the app
echo -e "${BLUE}📦 Building production app...${NC}"
npm run build

if [ ! -d "dist" ]; then
    echo -e "${RED}❌ Build failed - dist directory not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful${NC}"

# Deploy to CF
echo -e "${BLUE}🚀 Deploying to Cloud Foundry...${NC}"
cf push

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo -e "${BLUE}📱 Your app is now running on Cloud Foundry${NC}"
echo "Run 'cf app diagrams-viewer' to see details"
echo ""
