# Documentation Versioning Update Plan

**Created**: October 16, 2025  
**Status**: PLAN ONLY - DO NOT EXECUTE YET  
**Purpose**: Update all documentation references from `docs/v1.0.0/` to `docs/` with proper semantic versioning

---

## 🎯 Objective

Remove the `v1.0.0/` subdirectory structure and implement semantic versioning directly in the `docs/` folder, updating all references across the repository.

## 📊 Current State

### File Locations (After Manual Move)
```
docs/
├── architecture.md                 ← Moved from docs/v1.0.0/
├── CHANGELOG.md                   ← Moved from docs/v1.0.0/
├── deployment-guide.md            ← Moved from docs/v1.0.0/
├── failover-testing-guide.md      ← Moved from docs/v1.0.0/
├── load-testing-cheat-sheet.md    ← NEW (was CHEAT-SHEET.md)
├── load-testing-guide.md          ← Moved from docs/v1.0.0/
└── v1.0.0/                        ← NOW EMPTY
```

### Reference Count
- **100+ references** to `docs/v1.0.0/` or `v1.0.0/` across all markdown files
- References found in:
  - Root README.md
  - docs/*.md files
  - scripts/README.md files
  - archive/ documentation
  - CHANGELOG.md

---

## 📋 Implementation Plan

### Phase 1: Add Semantic Version Headers to All Docs

Add version metadata to the frontmatter/header of each main documentation file:

#### Files to Update

1. **docs/load-testing-guide.md**
   ```markdown
   # Load Testing Guide
   
   **Version**: 1.1.0  
   **Last Updated**: October 16, 2025  
   **Status**: Current
   ```

2. **docs/load-testing-cheat-sheet.md**
   ```markdown
   # Load Testing Cheat Sheet
   
   **Version**: 1.0.0  
   **Last Updated**: October 16, 2025  
   **Status**: Current
   ```

3. **docs/failover-testing-guide.md**
   ```markdown
   # Failover Testing Guide
   
   **Version**: 1.0.0  
   **Last Updated**: October 16, 2025  
   **Status**: Current
   ```

4. **docs/deployment-guide.md** (Already has version 2.1.0)
   - Keep existing version
   - Update "Last Updated" to October 16, 2025

5. **docs/architecture.md**
   ```markdown
   # Architecture Documentation
   
   **Version**: 2.0.0  
   **Last Updated**: October 16, 2025  
   **Status**: Current
   ```

6. **docs/CHANGELOG.md**
   ```markdown
   # Documentation Changelog
   
   **Version**: 2.2.0  
   **Last Updated**: October 16, 2025  
   **Status**: Current
   ```

---

### Phase 2: Update All Internal References

#### Group A: Root Files (5 files)

**File**: `README.md`
- **Lines to Update**: 8, 76, 181, 194, 382, 447, 489, 490, 495
- **Pattern**: Replace `docs/v1.0.0/` → `docs/`
- **Examples**:
  ```markdown
  # Before
  [![Documentation Version](https://img.shields.io/badge/docs-v1.0.0-blue.svg)](docs/v1.0.0/)
  
  # After
  [![Documentation Version](https://img.shields.io/badge/docs-v1.1.0-blue.svg)](docs/)
  ```
  ```markdown
  # Before
  [Failover Testing Guide](docs/v1.0.0/failover-testing-guide.md)
  
  # After
  [Failover Testing Guide](docs/failover-testing-guide.md)
  ```

**File**: `CHANGELOG.md`
- **Lines to Update**: 74
- **Pattern**: Update reference to archived v1.0.0 docs
- **Example**:
  ```markdown
  # Before
  - Updated `docs/v1.0.0/failover-testing-guide.md` with Npgsql prerequisites
  
  # After
  - Updated `docs/failover-testing-guide.md` (v1.0.0) with Npgsql prerequisites
  ```

#### Group B: Documentation Files (6 files)

**File**: `docs/load-testing-guide.md`
- **Lines to Update**: 1582 (file structure diagram), 1587-1599 (version history)
- **Actions**:
  - Remove `v1.0.0/` from file structure
  - Update version from v1.0.0 to v1.1.0
  - Add version history entry for v1.1.0

**File**: `docs/load-testing-cheat-sheet.md`
- **Lines to Update**: Footer/metadata
- **Actions**:
  - Update version to 1.0.0
  - Update last updated date

**File**: `docs/failover-testing-guide.md`
- **Lines to Update**: 305
- **Pattern**: Replace `docs/v1.0.0/load-testing-guide.md` → `docs/load-testing-guide.md`

**File**: `docs/deployment-guide.md`
- **Lines to Update**: 7 (reference to archive), 995
- **Actions**:
  - Keep archive reference as-is (correct)
  - Update line 995: `/docs/v1.0.0/` → `/docs/`

**File**: `docs/CHANGELOG.md`
- **Lines to Update**: 14, 24, 25, 73, 74, 81
- **Actions**:
  - Update references from `docs/v1.0.0/` to `docs/`
  - Keep archive references intact

#### Group C: Scripts Documentation (3 files)

**File**: `scripts/README.md`
- **Lines to Update**: 431-435
- **Pattern**: Replace `../docs/v1.0.0/` → `../docs/`
- **Examples**:
  ```markdown
  # Before
  - **Deployment Guide:** `../docs/v1.0.0/deployment-guide.md`
  
  # After
  - **Deployment Guide:** `../docs/deployment-guide.md`
  ```

**File**: `scripts/loadtesting/README.md`
- **Lines to Update**: 9, 10, 142, 151
- **Pattern**: Replace `../../docs/v1.0.0/` → `../../docs/`

**File**: `scripts/loadtesting/archive/README.md`
- **Lines to Update**: 107 (2 instances), 127, 162, 163
- **Pattern**: Replace `docs/v1.0.0/` → `docs/`

#### Group D: API Documentation (1 file)

**File**: `api/README.md`
- **Lines to Update**: 152
- **Pattern**: Replace `../docs/v1.0.0/deployment-guide.md` → `../docs/deployment-guide.md`

#### Group E: Archive Documentation (Keep As-Is)

**No changes needed** for files in `archive/` directory:
- These are historical references
- Should remain unchanged for accuracy
- Archive files: ~70+ markdown files

---

### Phase 3: Delete Empty v1.0.0 Directory

**Action**:
```powershell
Remove-Item "docs\v1.0.0" -Force
```

**Verification**:
- Ensure directory is empty before deletion
- Confirm no files were accidentally left behind

---

## 📝 Detailed File-by-File Changes

### Priority 1: Core Documentation (Must Update)

| File | Lines | Changes | Version |
|------|-------|---------|---------|
| `README.md` | 8, 76, 181, 194, 382, 447, 489, 490, 495 | Replace all `docs/v1.0.0/` → `docs/` | Badge: v1.1.0 |
| `docs/load-testing-guide.md` | Header, 1582, 1587-1599 | Add version 1.1.0, update structure | v1.1.0 |
| `docs/load-testing-cheat-sheet.md` | Header | Add version 1.0.0 | v1.0.0 |
| `docs/failover-testing-guide.md` | Header, 305 | Add version 1.0.0, fix reference | v1.0.0 |
| `docs/deployment-guide.md` | 995 | Update reference | v2.1.0 (existing) |
| `docs/architecture.md` | Header | Add version 2.0.0 | v2.0.0 |
| `docs/CHANGELOG.md` | Header, 14, 24, 25, 73, 74, 81 | Add version 2.2.0, update refs | v2.2.0 |

### Priority 2: Scripts Documentation (Should Update)

| File | Lines | Changes |
|------|-------|---------|
| `scripts/README.md` | 431-435 | Replace `../docs/v1.0.0/` → `../docs/` |
| `scripts/loadtesting/README.md` | 9, 10, 142, 151 | Replace `../../docs/v1.0.0/` → `../../docs/` |
| `scripts/loadtesting/archive/README.md` | 107, 127, 162, 163 | Replace `docs/v1.0.0/` → `docs/` |
| `api/README.md` | 152 | Replace `../docs/v1.0.0/` → `../docs/` |

### Priority 3: Root Metadata (Should Update)

| File | Lines | Changes |
|------|-------|---------|
| `CHANGELOG.md` | 74 | Update reference format |

### Priority 4: Archive Files (Do NOT Update)

**Keep historical accuracy** - all files in `archive/` should maintain original `docs/v1.0.0/` references.

---

## 🔍 Verification Checklist

After making changes:

### Automated Checks

```powershell
# 1. Find remaining v1.0.0 references (should only be in archive/)
Select-String -Path "*.md" -Pattern "docs/v1\.0\.0/" -Recurse | 
    Where-Object { $_.Path -notlike "*archive*" }

# 2. Verify empty v1.0.0 directory
Test-Path "docs\v1.0.0" -PathType Container

# 3. Check all docs have version headers
Get-ChildItem "docs\*.md" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -notmatch '\*\*Version\*\*:') {
        Write-Host "Missing version: $($_.Name)" -ForegroundColor Yellow
    }
}
```

### Manual Checks

- [ ] All main docs have version headers
- [ ] README.md badge shows v1.1.0
- [ ] No broken links (test in VS Code or GitHub preview)
- [ ] Archive references remain unchanged
- [ ] v1.0.0 directory deleted
- [ ] All 100+ references updated (except archive)

---

## 📊 Impact Assessment

### Files to Modify
- **Root**: 2 files (README.md, CHANGELOG.md)
- **docs/**: 6 files (all main documentation)
- **scripts/**: 3 files (README files)
- **api/**: 1 file (README.md)
- **Total**: **12 files** (excluding archive)

### References to Update
- **Non-archive**: ~30 references
- **Archive (keep as-is)**: ~70 references
- **Total found**: 100+ references

### Risk Level
- **Low Risk**: Straightforward find/replace
- **Testing Required**: Link validation
- **Rollback**: Git revert if issues found

---

## 🚀 Execution Order

### Step 1: Version Headers (6 files)
1. `docs/load-testing-guide.md` → v1.1.0
2. `docs/load-testing-cheat-sheet.md` → v1.0.0
3. `docs/failover-testing-guide.md` → v1.0.0
4. `docs/architecture.md` → v2.0.0
5. `docs/CHANGELOG.md` → v2.2.0
6. `docs/deployment-guide.md` → Update date only (keep v2.1.0)

### Step 2: Root Files (2 files)
1. `README.md`
2. `CHANGELOG.md`

### Step 3: Documentation Cross-References (4 files)
1. `docs/load-testing-guide.md`
2. `docs/failover-testing-guide.md`
3. `docs/deployment-guide.md`
4. `docs/CHANGELOG.md`

### Step 4: Scripts Documentation (4 files)
1. `scripts/README.md`
2. `scripts/loadtesting/README.md`
3. `scripts/loadtesting/archive/README.md`
4. `api/README.md`

### Step 5: Cleanup
1. Verify `docs/v1.0.0/` is empty
2. Delete `docs/v1.0.0/` directory
3. Run verification scripts

### Step 6: Validation
1. Check for broken links
2. Verify version headers
3. Confirm no remaining non-archive v1.0.0 references
4. Test documentation in GitHub preview

---

## 📌 Semantic Versioning Strategy

### Version Numbering Scheme

**Format**: `MAJOR.MINOR.PATCH`

| Document | Current | Proposed | Reasoning |
|----------|---------|----------|-----------|
| `load-testing-guide.md` | v1.0.0 | **v1.1.0** | Minor update (bug fixes, new param) |
| `load-testing-cheat-sheet.md` | N/A | **v1.0.0** | New document |
| `failover-testing-guide.md` | N/A | **v1.0.0** | Moved from v1.0.0, stable |
| `deployment-guide.md` | v2.1.0 | **v2.1.0** | Keep existing |
| `architecture.md` | N/A | **v2.0.0** | Major consolidated version |
| `CHANGELOG.md` | N/A | **v2.2.0** | Documentation version tracking |

### Version Increment Rules

- **MAJOR** (x.0.0): Breaking changes, major restructuring
- **MINOR** (x.x.0): New features, non-breaking additions
- **PATCH** (x.x.x): Bug fixes, typos, clarifications

### Change Log Entries

Each document should maintain a version history section:

```markdown
## Version History

### v1.1.0 (2025-10-16)
- Fixed TPS calculation bugs (uptime parsing)
- Added MaxMonitoringSeconds parameter
- Updated documentation structure (removed v1.0.0 subdirectory)

### v1.0.0 (2025-10-15)
- Initial release
- App Service-based load testing
- RTO/RPO measurement capabilities
```

---

## 🎯 Success Criteria

- [ ] All 6 main docs have version headers
- [ ] All non-archive `docs/v1.0.0/` references updated
- [ ] README.md badge shows v1.1.0
- [ ] `docs/v1.0.0/` directory deleted
- [ ] No broken links
- [ ] Archive references unchanged
- [ ] Version history updated in affected docs
- [ ] Verification scripts pass

---

## ⚠️ Important Notes

1. **Do NOT modify archive/ files** - maintain historical accuracy
2. **Test all links** before committing
3. **Update version badge** in README.md
4. **Document changes** in docs/CHANGELOG.md
5. **Coordinate with git workflow** - single commit preferred

---

## 📅 Timeline Estimate

- **Phase 1** (Version Headers): ~15 minutes
- **Phase 2** (Reference Updates): ~30 minutes
- **Phase 3** (Cleanup): ~5 minutes
- **Verification**: ~15 minutes
- **Total**: ~65 minutes

---

## 🔄 Rollback Plan

If issues are encountered:

```powershell
# Revert all changes
git checkout HEAD -- docs/ README.md CHANGELOG.md scripts/ api/

# Or revert specific commit
git revert <commit-hash>
```

---

**END OF PLAN**

This plan is ready for review. Do not execute until approved.
