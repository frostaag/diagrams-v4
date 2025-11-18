# Diagram File Controls & Prevention System

## Overview

This document describes the controls implemented to prevent duplicate diagram files and maintain a clean, organized diagram repository.

## The Problem

Without proper controls, the diagram repository can develop several issues:

1. **Duplicate files**: Same diagram with and without ID prefixes (e.g., `SAP Cloud.drawio` AND `001_SAP Cloud.drawio`)
2. **Test files in production**: Temporary files with suffixes like "- test", "- export verify", "- reprocess"
3. **Orphaned files**: Numbered files not registered in `diagram-registry.json`
4. **Duplicate IDs**: Multiple files sharing the same ID prefix

## Solution: Three-Layer Control System

### 1. Validation Script (`validate-diagram-files.sh`)

**Purpose**: Detect and report issues before they're committed

**What it checks**:
- ✅ Files without ID prefixes (XXX_)
- ✅ Duplicate ID usage
- ✅ Test/temporary file patterns in production
- ✅ Files not in registry
- ✅ Registry/file name mismatches

**Usage**:
```bash
./validate-diagram-files.sh
```

**Output**: Color-coded report showing:
- 🔴 Critical issues (require immediate action)
- 🟡 Cleanup opportunities
- 🟢 Validation passed

### 2. Cleanup Script (`cleanup-diagram-files.sh`)

**Purpose**: Archive problematic files safely

**What it does**:
- Moves test/temporary files to `drawio_files/.archive/`
- Moves orphaned files to archive
- Moves corresponding PNG files to `drawio_files/.archive_png/`
- Preserves files (no deletion)

**Usage**:
```bash
./cleanup-diagram-files.sh
```

**Safety features**:
- Interactive confirmation before archiving
- Files are moved, not deleted
- Easy to restore from archive if needed

### 3. Pre-commit Hook (`.git/hooks/pre-commit`)

**Purpose**: Prevent problematic files from being committed

**How it works**:
- Runs automatically on every `git commit`
- Executes validation script
- Blocks commit if issues found
- Provides clear error messages and fix suggestions

**Bypass** (not recommended):
```bash
git commit --no-verify
```

## File Naming Rules

### ✅ CORRECT Production Files
- Must start with 3-digit ID: `012_diagram-name.drawio`
- Must be in registry: `diagram-registry.json`
- No test suffixes

### ❌ INCORRECT Files
- No ID prefix: `diagram-name.drawio`
- Test suffixes: `012_diagram-name - test.drawio`
- Not in registry: Orphaned files

### Test Files (archived automatically)
Files with these patterns are considered test files:
- `- test`, `- Test`, `- TEST`
- `- reprocess`
- `- export`, `- verify`
- `- copy`, `- stub`
- `- deps`, `- appimage`
- `- web export`, `- newline`
- `- path`

## Workflow

### For New Diagrams

1. Create diagram in `drawio_files/` (any name)
2. Run validation: `./validate-diagram-files.sh`
3. Assign IDs: `./assign-diagram-ids.sh`
4. Commit: `git commit` (validation runs automatically)

### For Testing/Experimentation

1. Create test file with suffix: `012_diagram - test.drawio`
2. Work on it
3. When ready for production:
   - Remove suffix manually
   - Update registry if needed
4. Or let cleanup script archive it

### For Cleanup

1. Run validation: `./validate-diagram-files.sh`
2. Run cleanup: `./cleanup-diagram-files.sh`
3. Review archived files in `.archive/`
4. Commit changes

## Registry Management

The `diagram-registry.json` is the source of truth:

```json
{
  "nextId": 23,
  "mappings": {
    "012": {
      "id": "012",
      "originalName": "SAP Cloud.drawio",
      "currentDrawioFile": "012_SAP Cloud.drawio",
      "currentPngFile": "012_SAP Cloud.png",
      "title": "SAP Cloud",
      "status": "active"
    }
  }
}
```

**Key points**:
- Every production diagram must have a registry entry
- IDs are never reused
- `nextId` tracks the next available ID

## Best Practices

### DO ✅
- Use `assign-diagram-ids.sh` for new files
- Run validation before committing
- Use descriptive file names
- Keep registry in sync with files
- Use test suffixes for experiments

### DON'T ❌
- Manually create ID prefixes
- Commit files without validation
- Reuse IDs
- Delete files (archive instead)
- Skip the pre-commit hook

## Troubleshooting

### "Production files without IDs"
```bash
./assign-diagram-ids.sh
```

### "Test files in production"
```bash
./cleanup-diagram-files.sh
```

### "Duplicate IDs"
Manual resolution required:
1. Identify which file should keep the ID
2. Archive or rename the duplicate
3. Update registry

### "File not in registry"
Either:
- Add to registry with `assign-diagram-ids.sh`
- Or archive with `cleanup-diagram-files.sh`

## Archive Management

Archives are in `.gitignore` and not tracked by git.

**Location**:
- Drawio files: `drawio_files/.archive/`
- PNG files: `drawio_files/.archive_png/`

**To restore a file**:
```bash
mv drawio_files/.archive/012_diagram.drawio drawio_files/
mv drawio_files/.archive_png/012_diagram.png png_files/
# Update registry if needed
```

## Maintenance

### Regular Tasks
- Weekly: Run validation
- Monthly: Review and clean archives
- Before major commits: Full validation + cleanup

### After Updates
If you update the naming rules or patterns:
1. Update `validate-diagram-files.sh` patterns
2. Update `cleanup-diagram-files.sh` patterns
3. Update this documentation
4. Run full validation on repo

## Technical Details

### Scripts Requirements
- bash
- jq (JSON processor)
- find
- git

### Hook Installation
Pre-commit hook is automatically active after first commit.

To reinstall:
```bash
chmod +x .git/hooks/pre-commit
```

To disable:
```bash
rm .git/hooks/pre-commit
```

## Summary

This three-layer system ensures:
1. **Detection**: Validation script finds issues
2. **Remediation**: Cleanup script fixes issues
3. **Prevention**: Pre-commit hook blocks bad commits

Result: Clean, organized diagram repository with no duplicates or orphaned files.
