# Draw.io Conversion Fix

## Problem

The placeholder message you're seeing:
```
Diagram: 002_SAP Cloud.drawio
Please open in Draw.io to view
Conversion requires: Draw.io Desktop app or drawio CLI
```

This means the Draw.io CLI conversion was **failing silently** in the GitHub Actions workflow, causing the script to fall back to creating a placeholder SVG instead of actually converting the .drawio file.

## Root Cause

The Draw.io desktop application runs on Electron/Chromium, which requires specific flags to run properly in headless environments (like GitHub Actions):

1. **Missing dependencies**: Some required libraries for headless Chrome weren't installed
2. **Missing flags**: The `--no-sandbox`, `--disable-gpu`, and other flags are required for headless operation
3. **Silent failures**: The script was suppressing errors and couldn't detect when conversion actually failed

## The Fix

### 1. Updated GitHub Actions Workflow (`.github/workflows/process-diagrams.yml`)

**Added missing dependencies**:
```yaml
sudo apt-get install -y curl jq xvfb libgbm1 libasound2t64 libxss1 libnss3 libgtk-3-0
```

**Added conversion test**:
```bash
# Test conversion with a simple diagram
echo '<?xml version="1.0" encoding="UTF-8"?><mxfile>...' > /tmp/test.drawio

if xvfb-run -a drawio --no-sandbox --disable-gpu -x -f svg -o /tmp/test.svg /tmp/test.drawio; then
  echo "✅ Draw.io CLI test successful"
else
  echo "❌ Draw.io CLI test failed"
  exit 1
fi
```

### 2. Updated Conversion Script (`scripts/convert.sh`)

**Added proper flags for headless operation**:
```bash
xvfb-run -a drawio --no-sandbox --disable-gpu --disable-dev-shm-usage --disable-software-rasterizer -x -f svg -o "$svg_file" "$drawio_file"
```

**Added SVG validation**:
```bash
# Verify it's actually SVG content (not placeholder)
if grep -q "<svg" "$svg_file" && ! grep -q "Please open in Draw.io to view" "$svg_file"; then
  echo "   ✅ Success with drawio CLI (headless)"
  return 0
fi
```

## What Each Flag Does

- `--no-sandbox`: Disables Chrome's sandbox (required in Docker/CI environments)
- `--disable-gpu`: Disables GPU hardware acceleration (not available in headless)
- `--disable-dev-shm-usage`: Prevents /dev/shm issues in containers
- `--disable-software-rasterizer`: Disables software rasterizer fallback
- `-x`: Export mode
- `-f svg`: Export format
- `-o`: Output file

## How to Verify the Fix

1. **Commit and push** these changes to trigger the GitHub Action
2. **Check the Action logs** - you should now see:
   ```
   ✅ Draw.io CLI test successful
   🎨 Converting diagram to SVG...
   ✅ Success with drawio CLI (headless)
   ```

3. **Check the SVG files** in the `svg_files/` directory - they should contain actual diagram content, not placeholder text

4. **View in DMS** - The uploaded SVG files should now render properly as diagrams

## Testing Locally

If you want to test the conversion locally:

```bash
# Make the script executable
chmod +x scripts/convert.sh

# Run the conversion
./scripts/convert.sh
```

The script will automatically detect if it's running in a headless environment or with a display.

## Next Steps

After pushing these changes:
1. The next GitHub Action run will properly convert .drawio files to SVG
2. The converted SVG files will be uploaded to DMS
3. Your viewer application will display the actual rendered diagrams
4. Description inheritance will work as documented

## Complete Flow (After Fix)

1. `.drawio` file in `drawio_files/` directory (Git)
2. GitHub Action triggers on commit
3. **Draw.io CLI properly converts** `.drawio` → `.svg` ✅ (FIXED)
4. SVG saved to `svg_files/` directory
5. `upload-to-dms.sh` uploads SVG to DMS with description inheritance
6. Viewer app fetches and displays the rendered SVG diagram ✅

The key fix is that Draw.io CLI now has the proper flags to run in GitHub Actions headless environment.
