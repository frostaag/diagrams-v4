#!/bin/bash

echo "🧹 Diagram Files Cleanup Script"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create archive directory if it doesn't exist
ARCHIVE_DIR="drawio_files/.archive"
mkdir -p "$ARCHIVE_DIR"

# Arrays to store files
declare -a TEST_FILES
declare -a ORPHANED_FILES
FILES_MOVED=0

# Test/temporary file patterns
TEST_PATTERNS=("- test" "- Test" "- reprocess" "- export" "- verify" "- copy" "- stub" "- deps" "- appimage" "- web export" "- newline" "- path")

echo "${BLUE}🔍 Identifying files to clean up...${NC}"
echo ""

# Find test/temporary files with ID prefixes
echo "1. Scanning for test/temporary files with ID prefixes..."
while IFS= read -r -d '' file; do
    basename_file=$(basename "$file")
    
    # Check if file has ID prefix (production file)
    if [[ "$basename_file" =~ ^[0-9]{3}_ ]]; then
        for pattern in "${TEST_PATTERNS[@]}"; do
            if [[ "$basename_file" =~ $pattern ]]; then
                TEST_FILES+=("$basename_file")
                echo "   ${YELLOW}📦 Found: $basename_file${NC}"
                break
            fi
        done
    fi
done < <(find drawio_files -maxdepth 1 -name "*.drawio" -type f -print0)

# Find orphaned files (numbered but not in registry)
echo ""
echo "2. Scanning for orphaned files (not in registry)..."
if [[ -f "diagram-registry.json" ]]; then
    while IFS= read -r -d '' file; do
        basename_file=$(basename "$file")
        
        # Only check numbered files
        if [[ "$basename_file" =~ ^([0-9]{3})_ ]]; then
            id="${BASH_REMATCH[1]}"
            
            # Skip if already in TEST_FILES
            skip=false
            for test_file in "${TEST_FILES[@]}"; do
                if [[ "$test_file" == "$basename_file" ]]; then
                    skip=true
                    break
                fi
            done
            
            if [[ "$skip" == false ]]; then
                # Check if ID exists in registry
                registry_file=$(jq -r ".mappings.\"$id\".currentDrawioFile // empty" diagram-registry.json)
                
                if [[ -z "$registry_file" ]]; then
                    ORPHANED_FILES+=("$basename_file")
                    echo "   ${YELLOW}📦 Found: $basename_file (ID: $id not in registry)${NC}"
                fi
            fi
        fi
    done < <(find drawio_files -maxdepth 1 -name "*.drawio" -type f -print0)
fi

echo ""
echo "======================================"
echo "📊 CLEANUP SUMMARY"
echo "======================================"
echo "  Test/temporary files: ${#TEST_FILES[@]}"
echo "  Orphaned files: ${#ORPHANED_FILES[@]}"
echo "  Total files to archive: $((${#TEST_FILES[@]} + ${#ORPHANED_FILES[@]}))"
echo ""

if [[ ${#TEST_FILES[@]} -eq 0 && ${#ORPHANED_FILES[@]} -eq 0 ]]; then
    echo "${GREEN}✅ No files need cleanup!${NC}"
    exit 0
fi

echo "${YELLOW}⚠️  These files will be moved to: $ARCHIVE_DIR${NC}"
echo ""
echo "Files to be archived:"
for file in "${TEST_FILES[@]}" "${ORPHANED_FILES[@]}"; do
    echo "   - $file"
done
echo ""

read -p "❓ Do you want to proceed with archiving these files? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled"
    exit 0
fi

echo ""
echo "${BLUE}🚀 Starting cleanup process...${NC}"
echo ""

# Move test files
for file in "${TEST_FILES[@]}"; do
    if [[ -f "drawio_files/$file" ]]; then
        mv "drawio_files/$file" "$ARCHIVE_DIR/"
        echo "   ${GREEN}✅ Archived: $file${NC}"
        ((FILES_MOVED++))
        
        # Also move corresponding PNG if it exists
        png_file="${file%.drawio}.png"
        if [[ -f "png_files/$png_file" ]]; then
            mkdir -p "${ARCHIVE_DIR}/../.archive_png"
            mv "png_files/$png_file" "${ARCHIVE_DIR}/../.archive_png/"
            echo "      ${GREEN}✅ Archived PNG: $png_file${NC}"
        fi
    fi
done

# Move orphaned files
for file in "${ORPHANED_FILES[@]}"; do
    if [[ -f "drawio_files/$file" ]]; then
        mv "drawio_files/$file" "$ARCHIVE_DIR/"
        echo "   ${GREEN}✅ Archived: $file${NC}"
        ((FILES_MOVED++))
        
        # Also move corresponding PNG if it exists
        png_file="${file%.drawio}.png"
        if [[ -f "png_files/$png_file" ]]; then
            mkdir -p "${ARCHIVE_DIR}/../.archive_png"
            mv "png_files/$png_file" "${ARCHIVE_DIR}/../.archive_png/"
            echo "      ${GREEN}✅ Archived PNG: $png_file${NC}"
        fi
    fi
done

echo ""
echo "======================================"
echo "${GREEN}✅ CLEANUP COMPLETED${NC}"
echo "======================================"
echo "  Files archived: $FILES_MOVED"
echo "  Archive location: $ARCHIVE_DIR"
echo ""
echo "${BLUE}📋 Next steps:${NC}"
echo "   1. Review archived files in $ARCHIVE_DIR"
echo "   2. Run ./validate-diagram-files.sh to verify cleanup"
echo "   3. Commit the changes to git"
echo ""
echo "${YELLOW}💡 Note: Archived files are preserved and can be restored if needed${NC}"
