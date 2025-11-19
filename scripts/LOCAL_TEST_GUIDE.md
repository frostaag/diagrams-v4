# Local DMS Testing Guide

## Overview

The DMS connection test script requires environment variables that are configured in GitHub as organization-wide secrets. To test locally, you need to temporarily set these variables in your terminal.

## ⚠️ Security Warning

**NEVER commit DMS credentials to Git!** These values should only be:
- Set as GitHub organization secrets (✅ already done)
- Used temporarily in local terminal for testing
- Cleared from your terminal history after testing

## Local Testing Steps

### Option 1: Quick Test (Recommended)

Create a temporary file with your credentials (this file is gitignored):

```bash
cd diagrams-v4

# Create credentials file (will be gitignored)
cat > .env.dms.local << 'EOF'
export DMS_API_URL="https://api-sdm-di.cfapps.eu10.hana.ondemand.com"
export DMS_CLIENT_ID="your-client-id-here"
export DMS_CLIENT_SECRET="your-client-secret-here"
export DMS_XSUAA_URL="your-xsuaa-token-url-here"
export DMS_REPOSITORY_ID=""  # Optional, will auto-create
EOF

# Load credentials
source .env.dms.local

# Run test
./scripts/test-dms-connection.sh

# Clear credentials from environment
unset DMS_API_URL DMS_CLIENT_ID DMS_CLIENT_SECRET DMS_XSUAA_URL DMS_REPOSITORY_ID

# Delete credentials file
rm .env.dms.local
```

### Option 2: Export Directly

```bash
export DMS_API_URL="https://api-sdm-di.cfapps.eu10.hana.ondemand.com"
export DMS_CLIENT_ID="your-client-id"
export DMS_CLIENT_SECRET="your-client-secret"
export DMS_XSUAA_URL="your-xsuaa-url"
export DMS_REPOSITORY_ID=""  # Optional

# Run test
cd diagrams-v4
./scripts/test-dms-connection.sh

# Clear after testing
unset DMS_API_URL DMS_CLIENT_ID DMS_CLIENT_SECRET DMS_XSUAA_URL DMS_REPOSITORY_ID
```

## What the Test Does

The test script performs 6 comprehensive checks:

1. **✓ Environment Variables Check**
   - Validates all required credentials are set
   - Shows masked values for security

2. **✓ OAuth2 Authentication**
   - Obtains access token from XSUAA
   - Verifies token validity
   - Shows token expiration time

3. **✓ Repository Listing**
   - Lists all available DMS repositories
   - Tests basic API connectivity
   - Shows repository names and IDs

4. **✓ Diagrams Repository Check**
   - Searches for "Diagrams Repository"
   - Creates it if it doesn't exist
   - Returns the repository ID

5. **✓ File Upload Test**
   - Uploads `002_SAP Cloud_v1.svg` as a test
   - Verifies file upload functionality
   - Shows file ID after successful upload

6. **✓ Repository Contents Listing**
   - Lists all files in the repository
   - Shows file names and sizes
   - Confirms upload was successful

## Expected Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧪 DMS Connection Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣  Checking environment variables...
✅ All required variables are set

2️⃣  Testing OAuth2 authentication...
✅ Authentication successful

3️⃣  Listing DMS repositories...
✅ Successfully connected to DMS

4️⃣  Checking for Diagrams Repository...
✅ Found existing Diagrams Repository
  Repository ID: abc123...

5️⃣  Testing file upload...
✅ File uploaded successfully

6️⃣  Listing files in repository...
✅ Successfully listed repository contents
  Files found: 1

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Test Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ OAuth2 Authentication: SUCCESS
✅ Repository Access: SUCCESS
✅ Repository ID: abc123...
✅ File Upload Test: SUCCESS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎉 All DMS connection tests passed!
```

## Testing in GitHub Actions

The credentials are already configured as organization-wide secrets, so the test will work automatically in GitHub Actions without any additional setup.

To trigger the test in GitHub Actions:

```bash
cd diagrams-v4

# Make a small change to trigger the workflow
echo "# Test trigger" >> README.md

# Commit and push
git add README.md
git commit -m "Test: Verify DMS upload functionality"
git push origin main
```

Then check the GitHub Actions logs to see:
1. Diagram conversion (already working)
2. DMS upload (new step)
3. SharePoint upload
4. Teams notification

## Troubleshooting

### Issue: "Missing required environment variables"
**Solution**: Make sure you've exported all required variables before running the script

### Issue: "Authentication failed"
**Solution**: Verify your credentials are correct and match the GitHub organization secrets

### Issue: "Failed to list repositories"
**Solution**: Check that the DMS API URL is correct and accessible from your network

### Issue: "Upload failed"
**Solution**: Ensure the repository ID is correct and you have write permissions

## Cleanup

After testing, always clean up:

```bash
# Clear environment variables
unset DMS_API_URL DMS_CLIENT_ID DMS_CLIENT_SECRET DMS_XSUAA_URL DMS_REPOSITORY_ID

# Remove any temporary credential files
rm -f .env.dms.local

# Clear terminal history (optional but recommended)
history -c  # Bash/Zsh
```

## Next Steps After Successful Test

1. ✅ Credentials are working
2. ✅ Can authenticate with DMS
3. ✅ Can create/access repository
4. ✅ Can upload files

Now you can:
- Test the GitHub Actions workflow by making a commit
- Configure the BTP Destination for the Fiori app
- Deploy the Fiori application
- Use the complete end-to-end workflow

## Security Reminders

- ✅ GitHub org-wide secrets are properly configured
- ✅ Credentials are not in Git repository
- ✅ Local testing uses temporary environment variables
- ⚠️ Always clear credentials after local testing
- ⚠️ Never commit `.env.*` files to Git
