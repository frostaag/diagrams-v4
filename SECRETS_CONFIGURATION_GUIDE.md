# GitHub Secrets Configuration Guide

## Problem Identified 🔍
The workflow shows: `⚠️ DMS credentials not configured, skipping upload`

This means the secrets are not accessible to the workflow, even though they exist at the organization level.

## Solution: Configure Repository Access to Organization Secrets

### Option 1: Grant Repository Access to Organization Secrets (Recommended)

1. **Go to Organization Settings**
   - Navigate to: `https://github.com/organizations/frostaag/settings/secrets/actions`

2. **For Each Secret, Update Repository Access**
   - Click on each secret: `DMS_API_URL`, `DMS_CLIENT_ID`, `DMS_CLIENT_SECRET`, `DMS_XSUAA_URL`, `DMS_REPOSITORY_ID`
   - Look for "Repository access" section
   - Change from "Private repositories" to "Selected repositories"
   - Add `diagrams-v4` to the selected repositories list
   - Click "Update selection"

### Option 2: Create Repository-Level Secrets

If you prefer to keep secrets at repository level:

1. **Go to Repository Settings**
   - Navigate to: `https://github.com/frostaag/diagrams-v4/settings/secrets/actions`

2. **Add New Repository Secrets**
   Click "New repository secret" and add:
   
   - Name: `DMS_API_URL`
     Value: `https://api-sdm-di.cfapps.eu10.hana.ondemand.com`
   
   - Name: `DMS_CLIENT_ID`
     Value: `<your-client-id>`
   
   - Name: `DMS_CLIENT_SECRET`
     Value: `<your-client-secret>`
   
   - Name: `DMS_XSUAA_URL`
     Value: `<your-xsuaa-url>`
   
   - Name: `DMS_REPOSITORY_ID` (optional)
     Value: `<repository-id-if-known>`

## How to Verify Configuration

### Check if Secrets Are Accessible

1. Go to your workflow run
2. Look for the "Upload SVGs to SAP DMS" step
3. If properly configured, you'll see:
   ```
   📤 Uploading SVGs to SAP DMS...
   🔐 Authenticating with SAP DMS...
   ```

### Test Locally (Alternative)

If you want to test before fixing GitHub:

```bash
cd /Users/lucasdreger/apps/diagrams-v4

# Set your credentials
export DMS_API_URL="https://api-sdm-di.cfapps.eu10.hana.ondemand.com"
export DMS_CLIENT_ID="your-client-id"
export DMS_CLIENT_SECRET="your-client-secret"
export DMS_XSUAA_URL="your-xsuaa-url"

# Run the upload script
./scripts/upload-to-dms.sh
```

## Common Issues

### Issue: "Organization secrets not accessible"
**Solution:** Use Option 1 above to grant repository access

### Issue: "Bad credentials" 
**Solution:** Verify the secret values are correct

### Issue: "Repository not found"
**Solution:** The script will auto-create the repository on first run

## Next Steps

1. Choose Option 1 or Option 2 above
2. Configure the secrets
3. Trigger a new workflow run by editing any `.drawio` file
4. Verify the "Upload SVGs to SAP DMS" step executes successfully

---
**Note:** GitHub Actions logs will NOT show the actual secret values (they're masked), but you'll see the authentication and upload process.
