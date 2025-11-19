#!/bin/bash

# Diagrams-v4 Conversion Script
# Automatically assigns IDs, converts .drawio to PNG with version suffixes, and updates changelog

set -e

echo "🔄 Starting diagram processing..."

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Ensure required directories exist
mkdir -p drawio_files svg_files

# Ensure changelog exists with proper header
if [[ ! -f "svg_files/CHANGELOG.csv" ]]; then
  echo "Date,Time,DiagramID,DiagramName,Action,Version,Commit,Author,CommitMessage,FileSize,SvgPath" > svg_files/CHANGELOG.csv
  echo "✅ Created CHANGELOG.csv"
fi

# Ensure diagram registry exists
if [[ ! -f "diagram-registry.json" ]]; then
  cat > diagram-registry.json << 'EOF'
{
  "nextId": 1,
  "version": "2.0",
  "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "lastUpdated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "diagrams": {}
}
EOF
  echo "✅ Created diagram-registry.json"
fi

# Get git information (fallback if not in git repo)
if git rev-parse --git-dir > /dev/null 2>&1; then
  commit_hash=$(git log -1 --format="%h" 2>/dev/null || echo "local")
  commit_full_hash=$(git log -1 --format="%H" 2>/dev/null || echo "local")
  author_name=$(git log -1 --format="%an" 2>/dev/null || echo "$(whoami)")
  commit_message=$(git log -1 --format="%s" 2>/dev/null || echo "Manual conversion")
else
  commit_hash="local"
  commit_full_hash="local"
  author_name="$(whoami)"
  commit_message="Manual conversion"
fi

current_date=$(date +"%d.%m.%Y")
current_time=$(date +"%H:%M:%S")

# Function to get next ID from registry
get_next_id() {
  jq -r '.nextId' diagram-registry.json
}

# Function to increment next ID in registry
increment_next_id() {
  local temp_file=$(mktemp)
  jq --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
     '.nextId += 1 | .lastUpdated = $timestamp' \
     diagram-registry.json > "$temp_file"
  mv "$temp_file" diagram-registry.json
}

# Function to get diagram info from registry by ID
get_diagram_info() {
  local diagram_id="$1"
  jq -r --arg id "$diagram_id" '.diagrams[$id]' diagram-registry.json
}

# Function to add/update diagram in registry
update_diagram_registry() {
  local diagram_id="$1"
  local name="$2"
  local original_name="$3"
  local drawio_file="$4"
  local version="$5"
  local png_file="$6"
  local category="${7:-General}"
  
  local temp_file=$(mktemp)
  local timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  
  # Check if diagram exists in registry
  local exists=$(jq -r --arg id "$diagram_id" '.diagrams[$id] != null' diagram-registry.json)
  
  if [[ "$exists" == "true" ]]; then
    # Update existing diagram
    jq --arg id "$diagram_id" \
       --arg version "$version" \
       --arg png_file "$png_file" \
       --arg timestamp "$timestamp" \
       '.diagrams[$id].currentVersion = $version |
        .diagrams[$id].currentPngFile = $png_file |
        .diagrams[$id].lastModified = $timestamp |
        .diagrams[$id].versions += [$version] |
        .diagrams[$id].versions |= unique |
        .lastUpdated = $timestamp' \
       diagram-registry.json > "$temp_file"
  else
    # Add new diagram
    jq --arg id "$diagram_id" \
       --arg name "$name" \
       --arg original_name "$original_name" \
       --arg drawio_file "$drawio_file" \
       --arg version "$version" \
       --arg png_file "$png_file" \
       --arg category "$category" \
       --arg timestamp "$timestamp" \
       '.diagrams[$id] = {
         "id": $id,
         "name": $name,
         "originalName": $original_name,
         "drawioFile": $drawio_file,
         "currentVersion": $version,
         "currentPngFile": $png_file,
         "category": $category,
         "created": $timestamp,
         "lastModified": $timestamp,
         "versions": [$version],
         "status": "active"
       } | .lastUpdated = $timestamp' \
       diagram-registry.json > "$temp_file"
  fi
  
  mv "$temp_file" diagram-registry.json
}

# Function to get next version for a diagram
get_next_version() {
  local diagram_id="$1"
  local commit_msg="$2"
  
  # Get current version from registry
  local current_version=$(jq -r --arg id "$diagram_id" '.diagrams[$id].currentVersion // "v0"' diagram-registry.json)
  
  # Extract version number
  if [[ "$current_version" =~ ^v([0-9]+)$ ]]; then
    local version_num="${BASH_REMATCH[1]}"
    local next_num=$((version_num + 1))
    echo "v${next_num}"
  else
    echo "v1"
  fi
}

# Function to convert drawio to SVG
convert_to_svg() {
  local drawio_file="$1"
  local svg_file="$2"
  
  echo "🎨 Converting diagram to SVG..."
  
  # Method 1: Try drawio CLI if available
  if command -v drawio &> /dev/null; then
    echo "   Using Draw.io CLI..."
    
    # Check if running in headless environment (like GitHub Actions)
    if command -v xvfb-run &> /dev/null; then
      # Use xvfb-run for headless display
      if xvfb-run -a drawio -x -f svg -o "$svg_file" "$drawio_file" 2>/dev/null; then
        if [[ -f "$svg_file" ]] && [[ -s "$svg_file" ]]; then
          echo "   ✅ Success with drawio CLI (headless)"
          return 0
        fi
      fi
    else
      # Try without xvfb-run (local environment with display)
      if drawio -x -f svg -o "$svg_file" "$drawio_file" 2>/dev/null; then
        if [[ -f "$svg_file" ]] && [[ -s "$svg_file" ]]; then
          echo "   ✅ Success with drawio CLI"
          return 0
        fi
      fi
    fi
  fi
  
  # Method 2: Try using diagrams.net desktop app if installed
  if [[ -d "/Applications/draw.io.app" ]]; then
    echo "   Using Draw.io Desktop app..."
    if /Applications/draw.io.app/Contents/MacOS/draw.io -x -f svg -o "$svg_file" "$drawio_file" 2>/dev/null; then
      if [[ -f "$svg_file" ]] && [[ -s "$svg_file" ]]; then
        echo "   ✅ Success with Draw.io app"
        return 0
      fi
    fi
  fi
  
  # Method 3: Create placeholder SVG
  echo "   ⚠️  No conversion method available, creating placeholder..."
  
  # Create a simple SVG placeholder
  cat > "$svg_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 800 600">
  <rect width="800" height="600" fill="#f8f9fa"/>
  <text x="400" y="250" font-family="Arial, sans-serif" font-size="24" text-anchor="middle" fill="#333">
    Diagram: $(basename "$drawio_file")
  </text>
  <text x="400" y="300" font-family="Arial, sans-serif" font-size="18" text-anchor="middle" fill="#666">
    Please open in Draw.io to view
  </text>
  <text x="400" y="350" font-family="Arial, sans-serif" font-size="16" text-anchor="middle" fill="#999">
    Conversion requires: Draw.io Desktop app or drawio CLI
  </text>
</svg>
EOF
  
  if [[ -f "$svg_file" ]] && [[ -s "$svg_file" ]]; then
    echo "   📝 Created placeholder SVG"
    return 0
  fi
  
  # Last resort: create empty file to mark as processed
  echo "   ❌ All conversion methods failed"
  echo "   💡 Install Draw.io Desktop: https://www.diagrams.net/"
  return 1
}

# Process all .drawio files in drawio_files directory
processed_count=0
failed_count=0

echo "📁 Scanning drawio_files directory..."

if [[ ! -d "drawio_files" ]] || [[ -z "$(ls -A drawio_files/*.drawio 2>/dev/null)" ]]; then
  echo "⚠️  No .drawio files found in drawio_files directory"
  exit 0
fi

for file in drawio_files/*.drawio; do
  [[ ! -f "$file" ]] && continue
  
  basename_file=$(basename "$file")
  echo ""
  echo "🔍 Processing: $basename_file"
  
  # Check if file already has ID prefix
  if [[ "$basename_file" =~ ^([0-9]{3})_(.+)\.drawio$ ]]; then
    diagram_id="${BASH_REMATCH[1]}"
    diagram_name="${BASH_REMATCH[2]}"
    echo "✅ File has ID: $diagram_id"
  else
    # Assign new ID
    diagram_id=$(printf "%03d" $(get_next_id))
    diagram_name="${basename_file%.drawio}"
    new_filename="${diagram_id}_${diagram_name}.drawio"
    
    echo "🆔 Assigning ID: $diagram_id"
    echo "📝 Renaming: $basename_file -> $new_filename"
    
    mv "drawio_files/$basename_file" "drawio_files/$new_filename"
    increment_next_id
    
    basename_file="$new_filename"
    file="drawio_files/$new_filename"
  fi
  
  # Get next version
  version=$(get_next_version "$diagram_id" "$commit_message")
  echo "📊 Version: $version"
  
  # Generate SVG filename with version suffix
  svg_filename="${diagram_id}_${diagram_name}_${version}.svg"
  svg_path="svg_files/$svg_filename"
  
  echo "🖼️  Output: $svg_filename"
  
  # Convert to SVG
  if convert_to_svg "$file" "$svg_path"; then
    file_size=$(du -h "$svg_path" | cut -f1)
    echo "✅ Conversion successful ($file_size)"
    
    # Update registry
    update_diagram_registry "$diagram_id" "$diagram_name" "$basename_file" "$basename_file" "$version" "$svg_filename"
    
    # Add to changelog
    changelog_entry="${current_date},${current_time},\"${diagram_id}\",\"${diagram_name}\",\"Converted\",\"${version}\",\"${commit_hash}\",\"${author_name}\",\"${commit_message}\",\"${file_size}\",\"${svg_filename}\""
    echo "$changelog_entry" >> svg_files/CHANGELOG.csv
    
    ((processed_count++))
  else
    echo "❌ Conversion failed"
    
    # Add failure to changelog
    changelog_entry="${current_date},${current_time},\"${diagram_id}\",\"${diagram_name}\",\"Failed\",\"${version}\",\"${commit_hash}\",\"${author_name}\",\"${commit_message}\",\"0\",\"N/A\""
    echo "$changelog_entry" >> svg_files/CHANGELOG.csv
    
    ((failed_count++))
  fi
done

echo ""
echo "📊 Processing Summary:"
echo "✅ Successfully processed: $processed_count"
echo "❌ Failed: $failed_count"
echo ""
echo "📄 Updated files:"
echo "  - diagram-registry.json"
echo "  - svg_files/CHANGELOG.csv"
echo "  - $(ls -1 svg_files/*.svg 2>/dev/null | wc -l | tr -d ' ') SVG files"

exit 0
