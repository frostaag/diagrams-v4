# Cloud Foundry Deployment Guide

This guide walks you through deploying the Fiori Diagram Viewer to SAP BTP Cloud Foundry.

## Prerequisites

1. **SAP BTP Account** with Cloud Foundry environment
2. **Cloud Foundry CLI** installed
3. **Node.js** (v18+) and npm installed
4. **SAP DMS Service** configured (optional, for DMS mode)

## Step 1: Install Cloud Foundry CLI

### macOS
```bash
brew install cloudfoundry/tap/cf-cli@8
```

### Windows
Download from: https://github.com/cloudfoundry/cli/releases

### Linux
```bash
wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list
sudo apt-get update
sudo apt-get install cf8-cli
```

Verify installation:
```bash
cf --version
```

## Step 2: Log in to Cloud Foundry

```bash
# Log in to your SAP BTP CF environment
cf login -a https://api.cf.eu10.hana.ondemand.com

# Or use SSO
cf login -a https://api.cf.eu10.hana.ondemand.com --sso
```

Enter your credentials when prompted, then select your org and space.

Verify you're logged in:
```bash
cf target
```

## Step 3: Configure Environment (Optional - For DMS Mode)

If you want the app to fetch diagrams from SAP DMS, set environment variables:

```bash
# Export your DMS credentials
export DMS_CLIENT_ID="your-client-id"
export DMS_CLIENT_SECRET="your-client-secret"
export DMS_XSUAA_URL="https://your-subdomain.authentication.eu10.hana.ondemand.com"
```

These will be embedded in the build. For local file mode, skip this step.

## Step 4: Deploy Using the Script

```bash
cd viewer
chmod +x deploy-to-cf.sh
./deploy-to-cf.sh
```

The script will:
1. ✅ Check CF login status
2. ✅ Verify environment variables (optional)
3. 📦 Build the production app (`npm run build`)
4. 🚀 Deploy to Cloud Foundry (`cf push`)

## Step 5: Manual Deployment (Alternative)

If you prefer manual deployment:

```bash
cd viewer

# Install dependencies
npm install

# Build for production
npm run build

# Deploy to CF
cf push
```

## Step 6: Verify Deployment

```bash
# Check app status
cf app diagrams-viewer

# View logs
cf logs diagrams-viewer --recent

# Open in browser
cf app diagrams-viewer
```

The app URL will be shown in the output, something like:
```
https://diagrams-viewer-<random-word>.<region>.hana.ondemand.com
```

## Configuration Files

### `manifest.yml`
Defines the CF app configuration:
- **name**: `diagrams-viewer`
- **buildpack**: `staticfile_buildpack`
- **memory**: 128M
- **instances**: 1

### `Staticfile`
Configures the staticfile buildpack:
- **root**: `dist` (serves files from dist directory)
- **location_include**: `strict` (security)
- **directory**: `visible` (allows directory browsing)

## Deployment Modes

### Mode 1: Local File Mode (Default)
- No environment variables needed
- Fetches diagrams from bundled files
- Works immediately after deployment

### Mode 2: DMS Mode (Production)
- Requires DMS environment variables
- Fetches latest versions from SAP DMS
- Auto-detected when configured

## Updating the App

To deploy updates:

```bash
# Pull latest changes
git pull

# Navigate to viewer
cd viewer

# Deploy
./deploy-to-cf.sh
```

Or manually:
```bash
npm run build
cf push
```

## Scaling the App

```bash
# Scale instances
cf scale diagrams-viewer -i 3

# Scale memory
cf scale diagrams-viewer -m 256M

# Scale disk
cf scale diagrams-viewer -k 512M
```

## Environment Variables (Post-Deployment)

You can also set environment variables after deployment:

```bash
cf set-env diagrams-viewer VITE_DMS_API_URL "https://api-sdm-di.cfapps.eu10.hana.ondemand.com"
cf set-env diagrams-viewer VITE_DMS_CLIENT_ID "your-client-id"
cf set-env diagrams-viewer VITE_DMS_CLIENT_SECRET "your-client-secret"
cf set-env diagrams-viewer VITE_DMS_XSUAA_URL "https://your-subdomain.authentication.eu10.hana.ondemand.com"
cf set-env diagrams-viewer VITE_DMS_REPOSITORY_ID "06b87f25-1e4e-4dfb-8fbb-e5132d74f064"

# Restart app
cf restage diagrams-viewer
```

⚠️ **Note**: Since Vite embeds variables at build time, you'll need to rebuild and redeploy for changes to take effect.

## Troubleshooting

### App Won't Start
```bash
# Check logs
cf logs diagrams-viewer --recent

# Check app status
cf app diagrams-viewer
```

### Out of Memory
```bash
# Increase memory
cf scale diagrams-viewer -m 256M
```

### Wrong API Endpoint
```bash
# Check current endpoint
cf target

# Switch to correct endpoint
cf api https://api.cf.eu10.hana.ondemand.com
cf login
```

### Build Fails
```bash
# Clean install
cd viewer
rm -rf node_modules dist
npm install
npm run build
```

## CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/deploy-cf.yml`:

```yaml
name: Deploy to Cloud Foundry

on:
  push:
    branches: [main]
    paths:
      - 'viewer/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: |
          cd viewer
          npm ci
      
      - name: Build
        env:
          VITE_DMS_API_URL: ${{ secrets.DMS_API_URL }}
          VITE_DMS_CLIENT_ID: ${{ secrets.DMS_CLIENT_ID }}
          VITE_DMS_CLIENT_SECRET: ${{ secrets.DMS_CLIENT_SECRET }}
          VITE_DMS_XSUAA_URL: ${{ secrets.DMS_XSUAA_URL }}
          VITE_DMS_REPOSITORY_ID: ${{ secrets.DMS_REPOSITORY_ID }}
        run: |
          cd viewer
          npm run build
      
      - name: Deploy to CF
        uses: cloud-gov/cg-cli-tools@main
        with:
          cf_api: https://api.cf.eu10.hana.ondemand.com
          cf_username: ${{ secrets.CF_USERNAME }}
          cf_password: ${{ secrets.CF_PASSWORD }}
          cf_org: ${{ secrets.CF_ORG }}
          cf_space: ${{ secrets.CF_SPACE }}
          command: push -f viewer/manifest.yml
```

## Cleanup

To delete the app:

```bash
cf delete diagrams-viewer -f
```

## Support

For issues or questions:
- Check logs: `cf logs diagrams-viewer --recent`
For issues or questions:
- Check logs: `cf logs diagrams-viewer --recent`
- SAP BTP Documentation: https://help.sap.com/docs/BTP
- Cloud Foundry Docs: https://docs.cloudfoundry.org
