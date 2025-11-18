#!/bin/bash

echo "🔍 Diagram File Validation & Cleanup Script"
echo "==========================================="
echo ""

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Initialize counters
ISSUES_FOUND=0
FILES_TO_CLEAN=0

# Arrays to store issues
declare -a DUPLICATE_IDS
declare -a NON_NUMBERED_FILES
declare -a TEST_FILES
declare -a ORPHANED_FILES

echo "📋 Scanning drawio_files directory..."
echo ""

# Check for files without ID prefixes (XXX_)
echo "${BLUE}1. Checking for files without ID prefixes...${NC}"
while IFS= read -r -d '' file; do
    basename_file=$(basename "$file")
    
    # Skip system files
    [[ "$basename_file" == ".DS_Store" ]] && continue
    [[ "$basename_file" == *.txt ]] && continue
    
    # Check if file doesn't start with 3 digits and underscore
    if [[ ! "$basename_file" =~ ^[0-9]{3}_ ]]; then
        # Check if it's a test file
        if [[ "$basename_file" =~ (test|Test|TEST|workflow|trigger) ]]; then
            TEST_FILES+=("$basename_file")
            echo "   ${YELLOW}⚠️  Test file without ID: $basename_file${NC}"
        else
            NON_NUMBERED_FILES+=("$basename_file")
            echo "   ${RED}❌ Production file without ID: $basename_file${NC}"
            ((ISSUES_FOUND++))
        fi
    fi
done < <(find drawio_files -name "*.drawio" -type f -print0)

if [[ ${#NON_NUMBERED_FILES[@]} -eq 0 && ${#TEST_FILES[@]} -eq 0 ]]; then
    echo "   ${GREEN}✅ All files have proper ID prefixes${NC}"
fi
echo ""

# Check for duplicate IDs
echo "${BLUE}2. Checking for duplicate ID usage...${NC}"
# Use a temporary file to track IDs (more portable than associative arrays)
temp_ids=$(mktemp)
while IFS= read -r -d '' file; do
    basename_file=$(basename "$file")
    
    # Extract ID if present
    if [[ "$basename_file" =~ ^([0-9]{3})_ ]]; then
        id="${BASH_REMATCH[1]}"
        
        # Check if ID already seen
        if grep -q "^${id}:" "$temp_ids"; then
            existing_file=$(grep "^${id}:" "$temp_ids" | cut -d: -f2-)
            DUPLICATE_IDS+=("$id: $existing_file AND $basename_file")
            echo "   ${RED}❌ Duplicate ID $id found:${NC}"
            echo "      - $existing_file"
            echo "      - $basename_file"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        else
            echo "${id}:${basename_file}" >> "$temp_ids"
        fi
    fi
done < <(find drawio_files -name "*.drawio" -type f -print0)
rm -f "$temp_ids"

if [[ ${#DUPLICATE_IDS[@]} -eq 0 ]]; then
    echo "   ${GREEN}✅ No duplicate IDs found${NC}"
fi
echo ""

# Check for test/temporary file suffixes in production files
echo "${BLUE}3. Checking for test/temporary files in production...${NC}"
TEST_PATTERNS=("- test" "- Test" "- reprocess" "- export" "- verify" "- copy" "- stub" "- deps" "- appimage" "- web export" "- newline" "- path")

while IFS= read -r -d '' file; do
    basename_file=$(basename "$file")
    
    # Check if file has ID prefix (production file)
    if [[ "$basename_file" =~ ^[0-9]{3}_ ]]; then
        for pattern in "${TEST_PATTERNS[@]}"; do
            if [[ "$basename_file" =~ $pattern ]]; then
                TEST_FILES+=("$basename_file")
                echo "   ${YELLOW}⚠️  Production file with test suffix: $basename_file${NC}"
                ((FILES_TO_CLEAN++))
                break
            fi
        done
    fi
done < <(find drawio_files -name "*.drawio" -type f -print0)

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
    echo "   ${GREEN}✅ No test files in production${NC}"
fi
echo ""

# Check for files not in registry
echo "${BLUE}4. Checking for files not in registry...${NC}"
if [[ -f "diagram-registry.json" ]]; then
    while IFS= read -r -d '' file; do
        basename_file=$(basename "$file")
        
        # Only check numbered files
        if [[ "$basename_file" =~ ^([0-9]{3})_ ]]; then
            id="${BASH_REMATCH[1]}"
            
            # Check if ID exists in registry
            registry_file=$(jq -r ".mappings.\"$id\".currentDrawioFile // empty" diagram-registry.json)
            
            if [[ -z "$registry_file" ]]; then
                ORPHANED_FILES+=("$basename_file (ID: $id)")
                echo "   ${YELLOW}⚠️  File not in registry: $basename_file${NC}"
                ((FILES_TO_CLEAN++))
            elif [[ "$registry_file" != "$basename_file" ]]; then
                # File exists but name doesn't match registry
                echo "   ${YELLOW}⚠️  File name mismatch with registry:${NC}"
                echo "      File: $basename_file"
                echo "      Registry: $registry_file"
                ((ISSUES_FOUND++))
            fi
        fi
    done < <(find drawio_files -name "*.drawio" -type f -print0)
    
    if [[ ${#ORPHANED_FILES[@]} -eq 0 ]]; then
        echo "   ${GREEN}✅ All numbered files are in registry${NC}"
    fi
else
    echo "   ${YELLOW}⚠️  diagram-registry.json not found${NC}"
fi
echo ""

# Summary
echo "======================================"
echo "📊 VALIDATION SUMMARY"
echo "======================================"
echo ""
echo "Critical Issues (require immediate action):"
echo "  - Production files without IDs: ${#NON_NUMBERED_FILES[@]}"
echo "  - Duplicate IDs: ${#DUPLICATE_IDS[@]}"
echo ""
echo "Cleanup Opportunities:"
echo "  - Test/temporary files: ${#TEST_FILES[@]}"
echo "  - Orphaned files (not in registry): ${#ORPHANED_FILES[@]}"
echo ""
echo "Total Issues Found: $ISSUES_FOUND"
echo "Total Files to Clean: $FILES_TO_CLEAN"
echo ""

# Provide recommendations
if [[ $ISSUES_FOUND -gt 0 || $FILES_TO_CLEAN -gt 0 ]]; then
    echo "======================================"
    echo "📋 RECOMMENDED ACTIONS"
    echo "======================================"
    echo ""
    
    if [[ ${#NON_NUMBERED_FILES[@]} -gt 0 ]]; then
        echo "${RED}🚨 CRITICAL: Production files without IDs${NC}"
        echo "   Run: ./assign-diagram-ids.sh"
        echo ""
    fi
    
    if [[ ${#DUPLICATE_IDS[@]} -gt 0 ]]; then
        echo "${RED}🚨 CRITICAL: Duplicate IDs detected${NC}"
        echo "   Manual action required to resolve conflicts"
        echo ""
    fi
    
    if [[ ${#TEST_FILES[@]} -gt 0 || ${#ORPHANED_FILES[@]} -gt 0 ]]; then
        echo "${YELLOW}🧹 CLEANUP: Test and orphaned files${NC}"
        echo "   Run: ./cleanup-diagram-files.sh"
        echo ""
    fi
    
    exit 1
else
    echo "${GREEN}✅ All validation checks passed!${NC}"
    echo "   Your diagram files are properly organized."
    exit 0
fi
