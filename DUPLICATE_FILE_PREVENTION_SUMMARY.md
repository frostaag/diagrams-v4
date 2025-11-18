# Duplicate File Prevention - Implementation Summary

## Problem Identified

From the GitHub screenshot, the repository had multiple problematic file patterns:

1. **Duplicate files** - Same diagram with and without ID prefixes
2. **Test files in production** - Files with suffixes like "- test", "- export verify", "- reprocess"
3. **Orphaned files** - Numbered files not registered in `diagram-registry.json`
4. **Duplicate IDs** - Multiple files sharing the same ID prefix

## Solution Implemented

A three-layer control system to prevent, detect, and remediate duplicate files:

### 1. Validation Script (`validate-diagram-files.sh`)
- Scans all `.drawio` files in the repository
- Detects 4 types of issues:
  - Files without ID prefixes (XXX_)
  - Duplicate ID usage
  - Test/temporary file patterns
  - Files not in registry
- Provides color-coded output and actionable recommendations
- Returns exit code 1 if issues found (blocks CI/CD)

### 2. Cleanup Script (`cleanup-diagram-files.sh`)
- Safely archives problematic files to `drawio_files/.archive/`
- Moves corresponding PNG files to `.archive_png/`
- Interactive confirmation before archiving
- Preserves files (no deletion)
- Can be restored if needed

### 3. Pre-commit Hook (`.git/hooks/pre-commit`)
- Runs validation automatically before every commit
- Blocks commits if validation fails
- Provides clear error messages and fix suggestions
- Prevents problematic files from entering the repository

## Current Repository Status

Running validation on the current repository revealed:

### Critical Issues (5)
- **4 production files without IDs**:
  - `3.1. SAP RISE Connections - reprocess 2.drawio`
  - `User Provisioning Shorter Term.drawio`
  - `3.1. SAP RISE Connections.drawio`
  - `3.1. SAP RISE Connections - reprocess.drawio`

- **1 duplicate ID conflict**:
  - ID 016 used by both:
    - `016_3.1. SAP Task Center.drawio`
    - `016_3.1. SAP Task Center - stub flow test.drawio`

### Cleanup Opportunities (38 files)
- **14 test/temporary files** with suffixes like:
  - "- test", "- export verify", "- reprocess"
  - "- appimage test", "- web export test"
  
- **26 orphaned files** (numbered but not in registry)

## Usage

### Check current status:
```bash
./validate-diagram-files.sh
```

### Fix production files without IDs:
```bash
./assign-diagram-ids.sh
```

### Clean up test/orphaned files:
```bash
./cleanup-diagram-files.sh
```

### Commit changes (validation runs automatically):
```bash
git add .
git commit -m "Clean up diagram files"
# Pre-commit hook validates automatically
```

## Prevention Mechanism

The pre-commit hook ensures that:
1. **No duplicate files** can be committed
2. **No files without IDs** can be committed
3. **No test files with production IDs** can be committed
4. **All numbered files** must be in registry

If validation fails, the commit is blocked with clear instructions on how to fix the issues.

## File Organization Rules

### ✅ CORRECT Production Files
```
012_diagram-name.drawio          # Has ID prefix
Must be in diagram-registry.json # Registered
No test suffixes                 # Clean name
```

### ❌ INCORRECT Files
```
diagram-name.drawio              # Missing ID prefix
012_diagram-name - test.drawio   # Test suffix
015_orphaned-file.drawio         # Not in registry
```

### Test Files (will be archived)
Use these patterns for testing/experimentation:
- `diagram-name - test.drawio`
- `012_diagram - export verify.drawio`
- `012_diagram - reprocess.drawio`

These are automatically identified and archived by the cleanup script.

## Benefits

1. **Prevents confusion** - Only one official version of each diagram
2. **Maintains clean git history** - No temporary files in commits
3. **Enforces naming standards** - All production files have IDs
4. **Automatic validation** - Catches issues before they're committed
5. **Safe cleanup** - Archives rather than deletes files
6. **Easy recovery** - Archived files can be restored if needed

## Additional Files

- **`.gitignore`** - Updated to ignore `.archive/` directories
- **`DIAGRAM_FILE_CONTROLS.md`** - Comprehensive documentation with:
  - System overview
  - Usage workflows
  - Best practices
  - Troubleshooting guide
  - Technical details

## Next Steps

1. **Immediate**: Run `./validate-diagram-files.sh` to see current issues
2. **Fix critical issues**: 
   - Run `./assign-diagram-ids.sh` for files without IDs
   - Manually resolve duplicate ID conflicts
3. **Cleanup**: Run `./cleanup-diagram-files.sh` to archive test files
4. **Commit**: Changes will be validated automatically
5. **Ongoing**: Pre-commit hook prevents future issues

## Maintenance

- **Weekly**: Run validation check
- **Monthly**: Review and clean archives
- **Before major commits**: Full validation + cleanup

## Technical Details

- **Language**: Bash shell scripts
- **Dependencies**: jq, find, git (standard on macOS/Linux)
- **Compatibility**: Fixed bash 3.x compatibility issues
- **Performance**: Fast scanning using `find` with `-print0`
- **Safety**: Non-destructive operations, everything archived

## Result

This system ensures a clean, organized diagram repository with:
- No duplicate files
- No orphaned files
- No test files in production
- Consistent naming with ID prefixes
- Full registry synchronization
