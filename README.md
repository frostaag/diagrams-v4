# Diagrams v4

A modern, automated diagram management system with SAP Fiori-style viewer. Automatically converts Draw.io diagrams to PNG with versioning, changelog tracking, SharePoint integration, and Teams notifications.

## 🌟 Features

- **Automatic PNG Conversion**: Convert .drawio files to PNG automatically using diagrams.net API
- **Smart ID Assignment**: Automatically assigns unique 3-digit IDs to new diagrams
- **Version Management**: Tracks all versions with smart version increment (v1, v2, v3...)
- **Comprehensive Changelog**: Detailed CSV changelog with date, time, author, commit info, file size, and paths
- **SharePoint Integration**: Automatic upload of changelog to SharePoint
- **Teams Notifications**: Real-time notifications on processing completion or failures
- **SAP Fiori Viewer**: Modern, responsive web interface to browse and view diagrams
- **File Watcher**: Auto-convert on save during local development
- **GitHub Actions**: Automated CI/CD pipeline

## 📁 Project Structure

```
diagrams-v4/
├── drawio_files/              # Source .drawio files
├── png_files/                 # Generated PNG exports (with version suffixes)
│   └── CHANGELOG.csv          # Version history
├── scripts/
│   ├── convert.sh             # PNG conversion script
│   ├── watch.sh               # File watcher for local dev
│   └── upload.sh              # SharePoint/Teams integration
├── viewer/                    # SAP Fiori-style React app
│   ├── src/
│   │   ├── components/        # React components
│   │   ├── services/          # API services
│   │   └── types/             # TypeScript types
│   └── public/
├── .github/workflows/
│   └── process-diagrams.yml   # GitHub Actions workflow
├── diagram-registry.json      # Master ID registry
└── README.md
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ and npm
- jq (for JSON processing)
- Git
- Optional: fswatch (macOS) or inotify-tools (Linux) for file watching

### Installation

1. **Clone the repository**
   ```bash
   cd /path/to/your/workspace
   git clone <your-repo-url> diagrams-v4
   cd diagrams-v4
   ```

2. **Install viewer dependencies**
   ```bash
   cd viewer
   npm install
   cd ..
   ```

3. **Make scripts executable**
   ```bash
   chmod +x scripts/*.sh
   ```

### Local Development

#### Method 1: File Watcher (Recommended)

Start the file watcher to automatically convert diagrams on save:

```bash
./scripts/watch.sh
```

Then add or edit .drawio files in the `drawio_files/` folder. The watcher will automatically:
- Assign IDs to new files
- Convert to PNG with version suffix
- Update the changelog
- Update the registry

#### Method 2: Manual Conversion

Run the conversion script manually:

```bash
./scripts/convert.sh
```

### View Diagrams Locally

Start the development server:

```bash
cd viewer
npm run dev
```

Open http://localhost:5173 in your browser.

## 📝 Usage Guide

### Adding a New Diagram

1. Create your diagram in Draw.io
2. Save it to `drawio_files/` with a descriptive name (e.g., `SAP BTP Architecture.drawio`)
3. The system will automatically:
   - Assign an ID (e.g., `001_SAP BTP Architecture.drawio`)
   - Generate PNG with version (e.g., `001_SAP BTP Architecture_v1.png`)
   - Add entry to changelog
   - Update the registry

### Updating an Existing Diagram

1. Edit the .drawio file in `drawio_files/`
2. Save the file
3. The system will automatically:
   - Increment the version (e.g., v1 → v2)
   - Generate new PNG (e.g., `001_SAP BTP Architecture_v2.png`)
   - Keep all previous versions
   - Update changelog with new entry
   - Update registry with current version

## 📊 File Naming Convention

### DrawIO Files
```
{ID}_{NAME}.drawio
Example: 001_SAP BTP Architecture.drawio
```
- **ID**: 3-digit zero-padded number (001-999)
- **Never changes** once assigned

### PNG Files
```
{ID}_{NAME}_v{VERSION}.png
Example: 001_SAP BTP Architecture_v1.png
         001_SAP BTP Architecture_v2.png
```
- **ID**: Same as DrawIO file
- **VERSION**: Incremental (v1, v2, v3...)
- **All versions are kept**

## 📋 Changelog Format

The `png_files/CHANGELOG.csv` file contains:

```csv
Date,Time,DiagramID,DiagramName,Action,Version,Commit,Author,CommitMessage,FileSize,PngPath
18.11.2025,12:00:00,"001","SAP BTP Architecture","Converted","v1","abc123","John Doe","Initial diagram","245KB","001_SAP BTP Architecture_v1.png"
```

## 🔧 Configuration

### SharePoint Integration

Set the following environment variables or GitHub secrets/variables:

```bash
# Required for SharePoint upload
export SHAREPOINT_TENANT_ID="your-tenant-id"
export SHAREPOINT_CLIENT_ID="your-client-id"
export SHAREPOINT_CLIENT_SECRET="your-client-secret"
export SHAREPOINT_URL="https://company.sharepoint.com/sites/SiteName"

# Optional - auto-discovered if not provided
export SHAREPOINT_DRIVE_ID="your-drive-id"
```

### Teams Notifications

Set the Teams webhook URL:

```bash
export TEAMS_WEBHOOK_URL="https://company.webhook.office.com/webhookb2/..."
```

### GitHub Actions

Configure in repository settings under **Settings > Secrets and variables > Actions**:

**Variables:**
- `DIAGRAMS_SHAREPOINT_TENANT_ID`
- `DIAGRAMS_SHAREPOINT_CLIENT_ID`
- `DIAGRAMS_SHAREPOINT_URL`
- `DIAGRAMS_SHAREPOINT_DRIVE_ID` (optional)
- `DIAGRAMS_TEAMS_NOTIFICATION_WEBHOOK`

**Secrets:**
- `DIAGRAMS_SHAREPOINT_CLIENTSECRET`

## 🤖 GitHub Actions Workflow

The workflow automatically runs when:
- .drawio files are pushed to the `main` branch
- Manually triggered via workflow dispatch

It will:
1. Process all diagrams
2. Commit changes back to the repository
3. Upload changelog to SharePoint
4. Send Teams notification

## 🎨 SAP Fiori Viewer

The web viewer displays:
- **Latest version only** of each diagram
- Diagrams grouped by category
- Search functionality
- Full-size modal view
- Version information in details
- Download and open in new tab options

### Build for Production

```bash
cd viewer
npm run build
```

The built files will be in `viewer/dist/`.

## 📦 Diagram Registry

The `diagram-registry.json` file tracks:

```json
{
  "nextId": 12,
  "version": "2.0",
  "created": "2025-11-18T12:00:00Z",
  "lastUpdated": "2025-11-18T12:00:00Z",
  "diagrams": {
    "001": {
      "id": "001",
      "name": "SAP BTP Architecture",
      "originalName": "SAP BTP Architecture.drawio",
      "drawioFile": "001_SAP BTP Architecture.drawio",
      "currentVersion": "v2",
      "currentPngFile": "001_SAP BTP Architecture_v2.png",
      "category": "SAP",
      "created": "2025-01-15T10:00:00Z",
      "lastModified": "2025-11-18T12:00:00Z",
      "versions": ["v1", "v2"],
      "status": "active"
    }
  }
}
```

## 🛠️ Troubleshooting

### Conversion Fails

1. Check if diagrams.net API is accessible
2. Verify .drawio file is valid (try opening in Draw.io)
3. Check the console output for specific errors

### File Watcher Not Working

**macOS:**
```bash
brew install fswatch
```

**Linux:**
```bash
apt-get install inotify-tools
```

The watcher will fall back to polling mode if neither is available.

### SharePoint Upload Fails

1. Verify all environment variables are set correctly
2. Check that the service principal has write permissions
3. Verify the SharePoint URL format is correct

### Teams Notifications Not Sending

1. Verify the webhook URL is correct
2. Test the webhook using curl:
   ```bash
   curl -X POST "$TEAMS_WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -d '{"text": "Test message"}'
   ```

## 🔄 Migration from v3

If migrating from diagrams-v3:

1. IDs will be preserved if they match the format (001, 002, etc.)
2. Run the conversion script once to establish version v1 for all existing diagrams
3. Commit the updated registry and changelog
4. Future updates will increment from v1

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📞 Support

For issues or questions:
- Open an issue on GitHub
- Contact the IT department
- Check the troubleshooting section above

---

**Built with ❤️ for efficient diagram management**
