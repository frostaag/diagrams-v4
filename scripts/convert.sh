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
mkdir -p drawio_files png_files

# Ensure changelog exists with proper header
if [[ ! -f "png_files/CHANGELOG.csv" ]]; then
  echo "Date,Time,DiagramID,DiagramName,Action,Version,Commit,Author,CommitMessage,FileSize,PngPath" > png_files/CHANGELOG.csv
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

# Function to convert drawio to PNG
convert_to_png() {
  local drawio_file="$1"
  local png_file="$2"
  
  echo "🎨 Converting using diagrams.net export API..."
  
  # Read the .drawio file content
  local drawio_content=$(cat "$drawio_file")
  
  # Use diagrams.net export API
  local response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X POST \
    "https://convert.diagrams.net/export" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "format=png" \
    -d "scale=2" \
    -d "border=10" \
    -d "bg=ffffff" \
    --data-urlencode "xml=$drawio_content" \
    --output "$png_file")
  
  # Extract HTTP status code
  local http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
  
  if [[ "$http_code" -eq 200 ]] && [[ -f "$png_file" ]] && [[ -s "$png_file" ]]; then
    return 0
  else
    rm -f "$png_file" 2>/dev/null || true
    return 1
  fi
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
  
  # Generate PNG filename with version suffix
  png_filename="${diagram_id}_${diagram_name}_${version}.png"
  png_path="png_files/$png_filename"
  
  echo "🖼️  Output: $png_filename"
  
  # Convert to PNG
  if convert_to_png "$file" "$png_path"; then
    file_size=$(du -h "$png_path" | cut -f1)
    echo "✅ Conversion successful ($file_size)"
    
    # Update registry
    update_diagram_registry "$diagram_id" "$diagram_name" "$basename_file" "$basename_file" "$version" "$png_filename"
    
    # Add to changelog
    changelog_entry="${current_date},${current_time},\"${diagram_id}\",\"${diagram_name}\",\"Converted\",\"${version}\",\"${commit_hash}\",\"${author_name}\",\"${commit_message}\",\"${file_size}\",\"${png_filename}\""
    echo "$changelog_entry" >> png_files/CHANGELOG.csv
    
    ((processed_count++))
  else
    echo "❌ Conversion failed"
    
    # Add failure to changelog
    changelog_entry="${current_date},${current_time},\"${diagram_id}\",\"${diagram_name}\",\"Failed\",\"${version}\",\"${commit_hash}\",\"${author_name}\",\"${commit_message}\",\"0\",\"N/A\""
    echo "$changelog_entry" >> png_files/CHANGELOG.csv
    
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
echo "  - png_files/CHANGELOG.csv"
echo "  - $(ls -1 png_files/*.png 2>/dev/null | wc -l | tr -d ' ') PNG files"

exit 0
