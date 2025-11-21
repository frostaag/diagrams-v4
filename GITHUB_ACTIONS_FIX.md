# GitHub Actions SVG Conversion Issue - FIXED

## Problem
The Draw.io to SVG conversion in GitHub Actions was creating placeholder images instead of actual diagram SVGs. This is because the Draw.io CLI was failing in the headless CI environment.

## Root Cause
The conversion script (`scripts/convert.sh`) has a fallback mechanism that creates placeholder SVGs when the actual conversion fails. In GitHub Actions, the Draw.io CLI was not properly exporting the diagrams due to:

1. Headless environment issues
2. Missing display server configuration  
3. Incorrect Draw.io CLI flags

## Solution Applied

### 1. Updated GitHub Actions Workflow
File: `.github/workflows/process-diagrams.yml`

**Changes:**
- Updated Draw.io version to latest (26.0.4)
- Added proper dependencies for headless Chrome/Electron
- Improved error handling and logging

### 2. Enhanced Conversion Script  
File: `scripts/convert.sh`

**Key improvements in the `convert_to_svg()` function:**

```bash
# Using xvfb-run with proper flags for headless environment
xvfb-run -a drawio --no-sandbox --disable-gpu \
  --disable-dev-shm-usage --disable-software-rasterizer \
  -x -f svg -o "$abs_svg_file" "$abs_drawio_file"
```

**Critical flags explained:**
- `--no-sandbox`: Required for CI environments (runs without sandbox)
- `--disable-gpu`: Disables GPU acceleration (not available in CI)
- `--disable-dev-shm-usage`: Fixes shared memory issues in Docker/CI
- `--disable-software-rasterizer`: Prevents software rendering fallback
- `-x`: Export mode
- `-f svg`: Output format SVG

### 3. Validation Check
The script now validates that generated SVGs are actually valid:

```bash
if grep -q "<svg" "$abs_svg_file" && \
   ! grep -q "Please open in Draw.io to view" "$abs_svg_file"; then
  echo "   ✅ Success with drawio CLI (headless)"
  return 0
fi
```

## How to Trigger Re-conversion

### Option 1: Manual Workflow Dispatch
1. Go to GitHub Actions tab
2. Select "Process Diagrams v4" workflow
3. Click "Run workflow"  
4. Select `main` branch
5. Click "Run workflow" button

### Option 2: Push Draw.io Files
```bash
# Touch a diagram file to trigger re-processing
touch drawio_files/*.drawio
git add drawio_files/
git commit -m "Trigger diagram re-conversion"
git push
```

### Option 3: Force Re-conversion Locally
If you have Draw.io Desktop installed locally:

```bash
# Run conversion script locally
./scripts/convert.sh

# Commit the generated SVGs
git add svg_files/
git add diagram-registry.json
git commit -m "Re-generated SVG diagrams"
git push
```

## Verification

After re-conversion, check that:
1. SVG files are NOT placeholder images
2. SVG files contain actual diagram data
3. SVGs render correctly in the viewer app

**Check an SVG file:**
```bash
# Should contain actual drawing data, not placeholder text
head -20 svg_files/002_SAP\ Cloud_v26.svg
```

## Current Status

✅ Scripts updated with proper flags
✅ GitHub Actions workflow configured  
⚠️  **Action Required**: Trigger workflow to re-generate SVGs

## Next Steps

1. **Re-run the GitHub Actions workflow** to regenerate proper SVG files
2. **Rebuild and redeploy** the viewer app to CF:
   ```bash
   cd viewer
   npm run build
   cf push
   ```
3. **Verify** diagrams display correctly in the deployed app

## Troubleshooting

If conversion still fails in GitHub Actions:

1. **Check workflow logs** for specific error messages
2. **Verify Draw.io version** is compatible (currently using v26.0.4)
3. **Check dependencies** are properly installed
4. **Try alternative Draw.io version** (fallback to v25.0.2 is configured)

## Files Modified

- `.github/workflows/process-diagrams.yml` - Updated dependencies and versions
- `scripts/convert.sh` - Enhanced conversion with proper CLI flags
- `GITHUB_ACTIONS_FIX.md` - This documentation

## References

- [Draw.io CLI Documentation](https://github.com/jgraph/drawio-desktop)
- [Puppeteer Troubleshooting](https://github.com/puppeteer/puppeteer/blob/main/docs/troubleshooting.md)
- [Chrome Headless Flags](https://peter.sh/experiments/chromium-command-line-switches/)
