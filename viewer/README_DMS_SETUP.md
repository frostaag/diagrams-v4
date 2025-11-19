# Fiori Diagram Viewer - SAP DMS Integration Setup

This guide explains how to configure the Fiori diagram viewer to fetch diagrams from SAP Document Management Service (DMS) instead of local files.

## Overview

The diagram viewer supports two modes:
1. **Local Mode**: Fetches diagrams from local `svg_files` directory (default)
2. **DMS Mode**: Fetches diagrams from SAP Document Management Service (when configured)

When DMS is configured, the app automatically uses DMS mode and displays **only the latest version** of each diagram.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Fiori Diagram Viewer                      │
│                                                               │
│  ┌────────────────┐         ┌──────────────────┐            │
│  │   App.tsx      │────────▶│  isDMSConfigured │            │
│  └────────────────┘         └──────────────────┘            │
│         │                            │                       │
│         │ DMS Config Found?          │                       │
│         ▼                            ▼                       │
│  ┌────────────────┐         ┌──────────────────┐            │
│  │ getDiagramsFromDMS│       │  getDiagrams     │            │
│  │   (dmsService)   │       │(diagramService)  │            │
│  └────────────────┘         └──────────────────┘            │
│         │                            │                       │
│         ▼                            ▼                       │
│  ┌────────────────┐         ┌──────────────────┐            │
│  │   SAP DMS      │         │  Local Files     │            │
│  │  (Cloud)       │         │  (svg_files/)    │            │
│  └────────────────┘         └──────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **SAP BTP Account** with Document Management Service enabled
2. **Service Key** for your DMS instance
3. **Node.js** (v18 or later) and npm installed
4. **Vite** project setup (already configured)

## Configuration Steps

### 1. Get SAP DMS Service Key

From your SAP BTP cockpit:

```bash
# Navigate to your SAP BTP space
cf space <YOUR_SPACE>

# Create a service key for your DMS instance
cf create-service-key <DMS_SERVICE_INSTANCE> <KEY_NAME>

# Retrieve the service key
cf service-key <DMS_SERVICE_INSTANCE> <KEY_NAME>
```

The service key will contain:
```json
{
  "endpoints": {
    "ecmservice": {
      "url": "https://api-sdm-di.cfapps.eu10.hana.ondemand.com"
    }
  },
  "uaa": {
    "clientid": "your-client-id",
    "clientsecret": "your-client-secret",
    "url": "https://your-subdomain.authentication.eu10.hana.ondemand.com"
  },
  "repo": {
    "id": "06b87f25-1e4e-4dfb-8fbb-e5132d74f064"
  }
}
```

### 2. Create Environment File

Create a `.env` file in the `viewer` directory:

```bash
cd viewer
touch .env
```

Add the following environment variables:

```env
# SAP DMS Configuration
VITE_DMS_API_URL=https://api-sdm-di.cfapps.eu10.hana.ondemand.com
VITE_DMS_CLIENT_ID=your-client-id
VITE_DMS_CLIENT_SECRET=your-client-secret
VITE_DMS_XSUAA_URL=https://your-subdomain.authentication.eu10.hana.ondemand.com
VITE_DMS_REPOSITORY_ID=06b87f25-1e4e-4dfb-8fbb-e5132d74f064
```

**Important**: 
- Replace the values with your actual service key credentials
- Never commit the `.env` file to version control
- The `.env` file is already in `.gitignore`

### 3. Install Dependencies

```bash
cd viewer
npm install
```

### 4. Run the Application

#### Development Mode
```bash
npm run dev
```

The app will be available at `http://localhost:5173`

#### Production Build
```bash
npm run build
npm run preview
```

## How It Works

### Automatic DMS Detection

The app automatically detects if DMS is configured:

```typescript
const useDMS = isDMSConfigured();

const { data: diagrams } = useQuery({
  queryKey: ['diagrams', useDMS ? 'dms' : 'local'],
  queryFn: useDMS ? getDiagramsFromDMS : getDiagrams,
});
```

### Only Latest Versions

The app ensures only the latest version of each diagram is displayed:

1. **GitHub Actions Upload**: The upload script (`scripts/upload-to-dms.sh`) reads `diagram-registry.json` and only uploads files listed in `currentPngFile`
2. **DMS Service**: The `dmsService.ts` fetches all SVG files from DMS
3. **Filename Parsing**: Each filename (e.g., `002_SAP Cloud_v19.svg`) is parsed to extract ID, name, and version
4. **Display**: The Fiori app displays these diagrams with proper metadata

### Token Caching

OAuth2 tokens are automatically cached with a 5-minute buffer:

```typescript
let cachedToken: string | null = null;
let tokenExpiry: number = 0;

// Token is reused until 5 minutes before expiry
if (cachedToken && Date.now() < tokenExpiry - 300000) {
  return cachedToken;
}
```

## Deployment Options

### Option 1: Deploy to SAP BTP (Cloud Foundry)

1. **Build the app**:
```bash
npm run build
```

2. **Create `manifest.yml`**:
```yaml
applications:
  - name: diagram-viewer
    path: dist
    buildpacks:
      - staticfile_buildpack
    memory: 64M
    env:
      VITE_DMS_API_URL: https://api-sdm-di.cfapps.eu10.hana.ondemand.com
      VITE_DMS_CLIENT_ID: ((client-id))
      VITE_DMS_CLIENT_SECRET: ((client-secret))
      VITE_DMS_XSUAA_URL: ((xsuaa-url))
      VITE_DMS_REPOSITORY_ID: ((repository-id))
```

3. **Deploy**:
```bash
cf push
```

### Option 2: Deploy to Static Hosting

Build and deploy the `dist` folder to any static hosting service:
- Netlify
- Vercel
- AWS S3 + CloudFront
- Azure Static Web Apps

**Note**: Set environment variables in your hosting provider's dashboard.

## Troubleshooting

### App Shows "No diagrams found"

1. **Check DMS Configuration**:
```bash
# Open browser console
console.log('DMS Configured:', isDMSConfigured());
```

2. **Verify Environment Variables**:
- Ensure all `VITE_DMS_*` variables are set
- Restart dev server after changing `.env`

3. **Check Network Tab**:
- Look for requests to `/oauth/token` (authentication)
- Look for requests to `/browser/...` (document listing)
- Check for 401/403 errors (permissions issue)

### Authentication Errors (401/403)

1. **Verify Service Key**:
- Check client ID and secret are correct
- Ensure XSUAA URL includes the full domain
- Confirm repository ID is correct

2. **Check Permissions**:
```bash
# Test authentication manually
curl -X POST "https://your-subdomain.authentication.eu10.hana.ondemand.com/oauth/token" \
  -u "client-id:client-secret" \
  -d "grant_type=client_credentials"
```

### CORS Errors

If running locally, you may encounter CORS errors. Solutions:

1. **Use Vite Proxy** (add to `vite.config.ts`):
```typescript
export default defineConfig({
  server: {
    proxy: {
      '/api': {
        target: 'https://api-sdm-di.cfapps.eu10.hana.ondemand.com',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
});
```

2. **Deploy to SAP BTP**: CORS issues typically don't occur in production

## Security Best Practices

1. **Never Commit Secrets**:
   - Keep `.env` in `.gitignore`
   - Use environment variables in CI/CD
   - Rotate credentials regularly

2. **Token Security**:
   - Tokens are cached in memory only
   - Tokens expire automatically
   - Never log tokens in console

3. **Access Control**:
   - Use appropriate SAP DMS permissions
   - Implement authentication in your app if needed
   - Consider using SAP AppRouter for production

## Further Reading

- [SAP Document Management Service Documentation](https://help.sap.com/docs/DOCUMENT_MANAGEMENT_SERVICE)
- [CMIS Browser Binding Specification](http://docs.oasis-open.org/cmis/CMIS/v1.1/CMIS-v1.1.html)
- [Vite Environment Variables](https://vitejs.dev/guide/env-and-mode.html)
- [SAP BTP Cloud Foundry](https://help.sap.com/docs/BTP/65de2977205c403bbc107264b8eccf4b/9c7092c7b7ae4d49bc8ae35fdd0e0b18.html)
