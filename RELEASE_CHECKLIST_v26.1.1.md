# v26.1.1 Release Checklist

## ✅ Pre-Release Validation Complete

- [x] **Compilation**: `npm run compile` - Success
- [x] **Tests**: `npm test` - All 651 tests passed
- [x] **Linting**: `npm run lint` - Passed
- [x] **Build**: `npm run build` - Success (all distributions built)
- [x] **Examples**: `npm run slice` - All examples succeeded

## ✅ Version Updates Complete

- [x] **package.json**: Updated from 26.1.0 → 26.1.1
- [x] **package-lock.json**: Auto-updated
- [x] **CHANGELOG.md**: Moved unreleased changes to [26.1.1] section with date 2026-01-23

## ✅ Git Operations Complete

- [x] **Commit**: Created commit "26.1.1" with version changes
- [x] **Tag**: Created local tag `v26.1.1`
- [x] **Branch Push**: Pushed to `copilot/release-v26-1-1` branch

## ⏭️ Next Steps (Post-Merge)

### 1. Merge Pull Request
Merge the `copilot/release-v26-1-1` branch to `main` via GitHub PR.

### 2. Push Git Tag
After merge, the maintainer should push the tag:
```bash
git checkout main
git pull origin main
git push origin v26.1.1
```

### 3. Create GitHub Release
1. Go to https://github.com/jgphilpott/polyslice/releases
2. Click "Draft a new release"
3. Select tag: `v26.1.1`
4. Set title: "Release v26.1.1"
5. Copy content from `RELEASE_NOTES_v26.1.1.md`
6. Publish release

### 4. Publish to npm
```bash
# Test publish (dry run)
npm publish --dry-run

# Actual publish (requires npm auth)
npm publish

# Verify
npm view @jgphilpott/polyslice version
```

### 5. Post-Publish Verification
- [ ] Check npm: `npm view @jgphilpott/polyslice version` returns "26.1.1"
- [ ] Test install: `npm install @jgphilpott/polyslice` in clean directory
- [ ] Verify unpkg CDN: https://unpkg.com/@jgphilpott/polyslice@26.1.1/
- [ ] Verify GitHub release is live

## 📋 Release Summary

**Version**: 26.1.1  
**Date**: 2026-01-23  
**Type**: Second release of January 2026

### Key Changes
- ✨ Smart wipe nozzle feature
- ✨ Complete adhesion module (skirt, brim, raft)
- ✨ Travel path optimization
- 🐛 Various bug fixes
- 🗑️ Removed deprecated `outline` setting

### Stats
- Tests: 651 passed
- Build size: ~389KB (Node), ~2.7MB (Browser IIFE), ~854KB (Browser ESM)
- Example scripts: All passed

## 📝 Documentation Files

- `CHANGELOG.md` - Updated with v26.1.1 changes
- `RELEASE_NOTES_v26.1.1.md` - Comprehensive release notes for GitHub
- `RELEASE_CHECKLIST_v26.1.1.md` - This file

## 🔒 Security

No security vulnerabilities fixed in this release.

## 🎯 Acceptance Criteria

- [x] Version follows calendar format (26.1.1 = 2026, January, second release)
- [x] CHANGELOG.md updated with all changes
- [x] Git tag created matching version (v26.1.1)
- [x] All tests pass
- [x] All builds succeed
- [x] Release notes prepared
- [x] Working directory clean
