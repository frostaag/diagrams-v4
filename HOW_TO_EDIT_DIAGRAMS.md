# How to Edit Diagrams - Complete Guide

## ⚠️ IMPORTANT: Always Keep the Same Filename!

When editing an existing diagram, **you MUST save it with the same filename including its ID prefix**. The system tracks versions automatically.

## ✅ Correct Workflow

### Editing an Existing Diagram

1. **Open the diagram** with its full filename:
   ```
   drawio_files/001_SAP_Cloud.drawio
   ```

2. **Make your changes** in Draw.io

3. **Save with the SAME filename**:
   ```
   File > Save As > drawio_files/001_SAP_Cloud.drawio
   ```
   ⚠️ **Do NOT remove the ID prefix (001_)**

4. **Run the conversion script**:
   ```bash
   cd /path/to/diagrams-v4
   ./scripts/convert.sh
   ```

5. **Result**: The system will:
   - Detect it's diagram 001
   - Increment the version (v1 → v2 → v3, etc.)
   - Generate: `001_SAP_Cloud_v2.png`
   - Keep all previous versions in the changelog

### Creating a New Diagram

1. **Create your diagram** in Draw.io

2. **Save WITHOUT an ID prefix**:
   ```
   drawio_files/My_New_Diagram.drawio
   ```

3. **Run the conversion script**:
   ```bash
   ./scripts/convert.sh
   ```

4. **Result**: The system will:
   - Automatically assign the next ID (e.g., 002)
   - Rename file to: `002_My_New_Diagram.drawio`
   - Create version v1
   - Generate: `002_My_New_Diagram_v1.png`

## ❌ Common Mistakes

### Mistake 1: Removing the ID Prefix

**WRONG**:
```
Open:  drawio_files/001_SAP_Cloud.drawio
Save:  drawio_files/SAP_Cloud.drawio     ❌ ID removed!
```

**Result**: System treats it as a NEW diagram and assigns a new ID (002)

**CORRECT**:
```
Open:  drawio_files/001_SAP_Cloud.drawio
Save:  drawio_files/001_SAP_Cloud.drawio ✅ Same filename!
```

### Mistake 2: Changing the Filename

**WRONG**:
```
Open:  drawio_files/001_SAP_Cloud.drawio
Save:  drawio_files/001_SAP_Cloud_Updated.drawio  ❌ Name changed!
```

**Result**: System treats it as a NEW diagram

**CORRECT**:
```
Open:  drawio_files/001_SAP_Cloud.drawio
Save:  drawio_files/001_SAP_Cloud.drawio          ✅ Same filename!
```

### Mistake 3: Saving in the Wrong Location

**WRONG**:
```
Save:  ~/Desktop/001_SAP_Cloud.drawio  ❌ Wrong location!
```

**CORRECT**:
```
Save:  drawio_files/001_SAP_Cloud.drawio  ✅ Correct location!
```

## 📁 File Structure

```
diagrams-v4/
├── drawio_files/
│   ├── 001_SAP_Cloud.drawio          ← Original files (keep these!)
│   ├── 002_Azure_Setup.drawio
│   └── 003_User_Provisioning.drawio
│
├── png_files/
│   ├── 001_SAP_Cloud_v1.png          ← Version 1
│   ├── 001_SAP_Cloud_v2.png          ← Version 2 (after edit)
│   ├── 001_SAP_Cloud_v3.png          ← Version 3 (after another edit)
│   ├── 002_Azure_Setup_v1.png
│   ├── 003_User_Provisioning_v1.png
│   └── CHANGELOG.csv                  ← All changes tracked here
│
└── diagram-registry.json               ← Metadata about all diagrams
```

## 🔄 How Versioning Works

1. **First Creation**:
   - File: `001_SAP_Cloud.drawio`
   - PNG: `001_SAP_Cloud_v1.png`

2. **First Edit** (same filename):
   - File: `001_SAP_Cloud.drawio` (updated content)
   - PNG: `001_SAP_Cloud_v2.png` (new version)
   - Previous PNG: `001_SAP_Cloud_v1.png` (still exists)

3. **Second Edit** (same filename):
   - File: `001_SAP_Cloud.drawio` (updated content)
   - PNG: `001_SAP_Cloud_v3.png` (new version)
   - Previous PNGs: v1 and v2 still exist

## 📊 Checking Your Changes

### View the Changelog
```bash
cat png_files/CHANGELOG.csv
```

Look for your diagram ID to see all versions:
```csv
Date,Time,DiagramID,DiagramName,Action,Version,Commit,Author
19.11.2025,08:00:00,"001","SAP_Cloud","Converted","v1","a1b2c3","John"
19.11.2025,09:00:00,"001","SAP_Cloud","Converted","v2","d4e5f6","John"
19.11.2025,10:00:00,"001","SAP_Cloud","Converted","v3","g7h8i9","John"
```

### View the Registry
```bash
cat diagram-registry.json | jq '.diagrams["001"]'
```

Output shows:
```json
{
  "id": "001",
  "name": "SAP_Cloud",
  "drawioFile": "001_SAP_Cloud.drawio",
  "currentVersion": "v3",
  "currentPngFile": "001_SAP_Cloud_v3.png",
  "versions": ["v1", "v2", "v3"],
  "lastModified": "2025-11-19T08:30:00Z"
}
```

## 🔧 Conversion Methods

The script tries multiple methods to convert diagrams:

1. **Draw.io CLI** (if installed)
2. **Draw.io Desktop App** (if installed at `/Applications/draw.io.app`)
3. **Kroki API** (online service)
4. **Placeholder Image** (with ImageMagick, if all else fails)

### Installing Draw.io for Best Results

**macOS**:
```bash
# Download from: https://www.diagrams.net/
# Or install via Homebrew:
brew install --cask drawio
```

**After installation**, the script will automatically use it.

## 🚨 Troubleshooting

### Problem: "Assigned ID 002 but I edited diagram 001"

**Cause**: You saved the file without the ID prefix

**Solution**: 
1. Delete the wrongly created file: `rm drawio_files/002_*.drawio`
2. Re-edit the original: `drawio_files/001_*.drawio`
3. Save with the same filename
4. Run conversion again

### Problem: "Conversion failed"

**Cause**: No conversion tool is available

**Solution**: Install Draw.io Desktop:
```bash
# macOS
brew install --cask drawio

# Or download from: https://www.diagrams.net/
```

### Problem: "File not found after running script"

**Cause**: File was in wrong location or renamed

**Solution**: Check that:
1. File is in `drawio_files/` directory
2. Filename includes the ID prefix
3. You ran script from project root

## 📝 Quick Reference

| Action | Command | Result |
|--------|---------|--------|
| Edit existing | Save as `001_Name.drawio` | Creates v2, v3, etc. |
| Create new | Save as `Name.drawio` | Gets next ID (002, 003, etc.) |
| Convert all | `./scripts/convert.sh` | Processes all diagrams |
| View changes | `cat png_files/CHANGELOG.csv` | See all versions |
| Check registry | `cat diagram-registry.json` | See all metadata |

## ✅ Best Practices

1. **Always use Draw.io Desktop** for best conversion quality
2. **Never manually rename** files with ID prefixes
3. **Run validation** before committing:
   ```bash
   ./validate-diagram-files.sh
   ```
4. **Commit regularly** to track changes in git
5. **Keep old PNG versions** - they're tracked in the changelog

## 🎯 Summary

**The Golden Rule**: When editing a diagram, save it with the **exact same filename** including the ID prefix. The system handles versioning automatically!

```
✅ GOOD:  Edit 001_Name.drawio → Save as 001_Name.drawio
❌ BAD:   Edit 001_Name.drawio → Save as Name.drawio
❌ BAD:   Edit 001_Name.drawio → Save as 001_Name_v2.drawio
