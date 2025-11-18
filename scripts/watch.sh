#!/bin/bash

# Diagrams-v4 File Watcher
# Monitors drawio_files directory and auto-converts on save

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WATCH_DIR="$PROJECT_ROOT/drawio_files"

echo "👀 Starting file watcher for diagrams-v4..."
echo "📁 Watching: $WATCH_DIR"
echo "🔄 Auto-converting .drawio files on save"
echo ""
echo "Press Ctrl+C to stop watching"
echo ""

# Ensure watch directory exists
mkdir -p "$WATCH_DIR"

# Check if fswatch is available (macOS)
if command -v fswatch &> /dev/null; then
  echo "✅ Using fswatch for file monitoring"
  
  fswatch -0 -e ".*" -i "\\.drawio$" "$WATCH_DIR" | while read -d "" file; do
    if [[ -f "$file" ]] && [[ "$file" == *.drawio ]]; then
      echo ""
      echo "📝 Detected change: $(basename "$file")"
      echo "🔄 Running conversion..."
      
      # Run conversion script
      "$SCRIPT_DIR/convert.sh"
      
      echo "✅ Conversion complete"
      echo ""
      echo "👀 Watching for changes..."
    fi
  done

# Fallback to inotifywait (Linux)
elif command -v inotifywait &> /dev/null; then
  echo "✅ Using inotifywait for file monitoring"
  
  while true; do
    inotifywait -q -e modify,create,moved_to -r "$WATCH_DIR" --include '\.drawio$' | while read -r directory events filename; do
      echo ""
      echo "📝 Detected change: $filename"
      echo "🔄 Running conversion..."
      
      # Run conversion script
      "$SCRIPT_DIR/convert.sh"
      
      echo "✅ Conversion complete"
      echo ""
      echo "👀 Watching for changes..."
    done
  done

# Fallback to polling (works everywhere but less efficient)
else
  echo "⚠️  No file watcher tool found (fswatch/inotifywait)"
  echo "📊 Using polling mode (checks every 5 seconds)"
  echo ""
  echo "💡 For better performance, install fswatch:"
  echo "   brew install fswatch (macOS)"
  echo "   apt-get install inotify-tools (Linux)"
  echo ""
  
  # Store initial state
  declare -A file_states
  
  # Function to get file modification time
  get_mod_time() {
    if [[ -f "$1" ]]; then
      stat -f "%m" "$1" 2>/dev/null || stat -c "%Y" "$1" 2>/dev/null || echo "0"
    else
      echo "0"
    fi
  }
  
  # Initial scan
  for file in "$WATCH_DIR"/*.drawio; do
    [[ -f "$file" ]] && file_states["$file"]=$(get_mod_time "$file")
  done
  
  while true; do
    sleep 5
    
    # Check for changes
    changed=false
    
    for file in "$WATCH_DIR"/*.drawio; do
      [[ ! -f "$file" ]] && continue
      
      current_time=$(get_mod_time "$file")
      previous_time="${file_states[$file]:-0}"
      
      if [[ "$current_time" != "$previous_time" ]]; then
        echo ""
        echo "📝 Detected change: $(basename "$file")"
        echo "🔄 Running conversion..."
        
        # Run conversion script
        "$SCRIPT_DIR/convert.sh"
        
        echo "✅ Conversion complete"
        echo ""
        echo "👀 Watching for changes..."
        
        changed=true
        break
      fi
    done
    
    # Update file states after processing
    if $changed; then
      for file in "$WATCH_DIR"/*.drawio; do
        [[ -f "$file" ]] && file_states["$file"]=$(get_mod_time "$file")
      done
    fi
  done
fi
