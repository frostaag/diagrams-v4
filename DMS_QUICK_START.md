# SAP DMS Integration - Quick Start Guide

## Overview
This guide helps you quickly set up and test the SAP Document Management Service (DMS) integration for uploading diagrams.

## Prerequisites
- SAP BTP account with DMS service enabled
- DMS service key with credentials
- GitHub repository with Actions enabled

## Step 1: Configure GitHub Secrets

⚠️ **IMPORTANT**: All DMS credentials must be added as **Secrets** (NOT Variables) in GitHub:

| Secret Name | Example Value | Source |
|-------------|---------------|--------|
| `DMS_API_URL` | `https://api-sdm-di.cfapps.eu10.hana.ondemand.com` | Service Key → `ecmservice.url` |
| `DMS_CLIENT_ID` | `sb-123abc...` | Service Key → `uaa.clientid` |
| `DMS_CLIENT_SECRET` | `xyz789...` | Service Key → `uaa.clientsecret` |
| `DMS_XSUAA_URL` | `https://frosta-apps-dev.authentication.eu10.hana.ondemand.com` | Service Key → `uaa.url` |
| `DMS_REPOSITORY_ID` | `06b87f25-1e4e-4dfb-8fbb-e5132d74f064` | (Optional - uses default if not set) |

### How to Add Secrets
1. Go to GitHub repository → **Settings** → **Secrets and variables** → **Actions**
2. Click on the **Secrets** tab (not Variables)
3. Click **New repository secret** (or use organization secrets)
4. Add each secret name and value
5. Click **Add secret**

**Note**: Make sure you're adding these as **Secrets**, not as **Variables**. The workflow has been updated to use `${{ secrets.SECRET_NAME }}` for all DMS credentials.

## Step 2: Verify Service Key Format

Your DMS service key JSON should look like this:

```json
{
  "ecmservice": {
    "url": "https://api-sdm-di.cfapps.eu10.hana.ondemand.com/"
  },
  "uaa": {
    "url": "https://frosta-apps-dev.authentication.eu10.hana.ondemand.com",
    "clientid": "sb-abc123...",
    "clientsecret": "xyz789...",
    "identityzone": "frosta-apps-dev",
    "tenantid": "...",
    "tenantmode": "dedicated"
  },
  "uri": "https://api-sdm-di.cfapps.eu10.hana.ondemand.com"
}
```

## Step 3: Test Locally (Optional)

If you want to test before pushing to GitHub:

```bash
# Navigate to the project
cd /path/to/diagrams-v4

# Set environment variables
export DMS_API_URL="https://api-sdm-di.cfapps.eu10.hana.ondemand.com"
export DMS_CLIENT_ID="your-client-id"
export DMS_CLIENT_SECRET="your-client-secret"
export DMS_XSUAA_URL="https://frosta-apps-dev.authentication.eu10.hana.ondemand.com"
export DMS_REPOSITORY_ID="06b87f25-1e4e-4dfb-8fbb-e5132d74f064"

# Run the test script
./scripts/test-dms-connection.sh
```

Expected output:
```
🧪 DMS Connection Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1️⃣  Checking environment variables...
✅ All required variables are set

2️⃣  Testing OAuth2 authentication...
✅ Authentication successful

3️⃣  Listing DMS repositories...
✅ Successfully connected to DMS

4️⃣  Using specified repository ID...
✅ Using repository ID: 06b87f25-1e4e-4dfb-8fbb-e5132d74f064

5️⃣  Testing file upload...
✅ File uploaded successfully

6️⃣  Listing files in repository...
✅ Successfully listed repository contents

🎉 All DMS connection tests passed!
```

## Step 4: Test GitHub Actions

### Option 1: Manual Trigger
1. Go to **Actions** tab in GitHub
2. Select **Process Diagrams v4** workflow
3. Click **Run workflow** button
4. Select branch (usually `main`)
5. Click **Run workflow**

### Option 2: Automatic Trigger
1. Edit any `.drawio` file in `drawio_files/` directory
2. Commit and push the change
3. Workflow will automatically run

## Step 5: Monitor the Workflow

1. Go to **Actions** tab
2. Click on the running workflow
3. Watch the steps:
   - ✅ Setup Dependencies
   - ✅ Convert diagrams
   - ✅ Upload to DMS ← This is the new step

## Step 6: Verify in SAP DMS

1. Log in to SAP BTP Cockpit
2. Navigate to your DMS service instance
3. Open the repository (ID: `06b87f25-1e4e-4dfb-8fbb-e5132d74f064`)
4. Check for uploaded SVG files in the `/root` folder

## Understanding the Upload Process

The upload process follows SAP's recommended flow:

```
1. Get OAuth Token
   ↓
2. Authenticate with XSUAA
   ↓
3. For each SVG file:
   - Create CMIS document
   - Upload file content
   - Set properties (name, type)
   ↓
4. Verify upload success
```

## Troubleshooting

### Authentication Errors (401)
- **Check**: Client ID and Secret are correct
- **Check**: XSUAA URL is accessible
- **Fix**: Regenerate service key if needed

### Repository Not Found (404)
- **Check**: Repository ID is correct
- **Check**: Repository exists in DMS
- **Fix**: Use `scripts/discover-cmis-repository.sh` to list repositories

### Upload Fails (500)
- **Check**: File size is within limits
- **Check**: DMS service is running
- **Fix**: Check SAP BTP service status

### No Files Uploaded
- **Check**: `svg_files/` directory exists
- **Check**: Directory contains `.svg` files
- **Fix**: Run conversion step first

## Advanced Usage

### Upload to a Subfolder

Edit `scripts/upload-to-dms.sh` and change the upload path:

```bash
# Instead of /root, use /root/diagrams
"${DMS_API_URL}/browser/${REPO_ID}/root/diagrams"
```

### Add Custom Metadata

Add more CMIS properties to the upload:

```bash
-F "propertyId[2]=cmis:description" \
-F "propertyValue[2]=Your description here" \
```

### Handle Duplicate Files

The current implementation will create new versions. To overwrite:
1. Check if file exists first
2. Delete old version
3. Upload new version

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `test-dms-connection.sh` | Test DMS connectivity and credentials |
| `upload-to-dms.sh` | Upload SVG files to DMS (used in workflow) |
| `discover-cmis-repository.sh` | List available CMIS repositories |

## Next Steps

After successful DMS upload:
1. Configure BTP Destination for Fiori app
2. Update Fiori app to read from DMS
3. Test end-to-end flow

## Support

For issues or questions:
1. Check `DMS_INTEGRATION_STATUS.md` for detailed status
2. Review workflow logs in GitHub Actions
3. Check SAP BTP service logs
4. Review CMIS specification for advanced features

## Security Notes

⚠️ **Important**:
- Never commit credentials to Git
- Rotate secrets regularly
- Use organization-level secrets when possible
- Limit access to DMS service keys
- Monitor DMS access logs

---
**Quick Reference**  
Repository ID: `06b87f25-1e4e-4dfb-8fbb-e5132d74f064`  
Test Script: `./scripts/test-dms-connection.sh`  
Upload Script: `./scripts/upload-to-dms.sh`
