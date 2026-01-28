# Release v26.1.2 - Pre-Release Checklist

## ✅ Completed Steps

### 1. Pre-Release Validation
- ✅ **Compiled CoffeeScript**: All source files compiled successfully
- ✅ **Tests Passed**: All 695 tests passed (188.2s)
- ✅ **Linting Passed**: No linting issues found
- ✅ **Build Successful**: All distributions built
  - `dist/index.js` (430KB) - Node.js CommonJS
  - `dist/index.esm.js` (430KB) - Node.js ES Module  
  - `dist/index.browser.js` (2.8MB) - Browser IIFE
  - `dist/index.browser.esm.js` (895KB) - Browser ES Module

### 2. Version Management
- ✅ **package.json**: Updated to 26.1.2
- ✅ **CHANGELOG.md**: Updated with v26.1.2 release notes
- ✅ **Git Commit**: Created with message "26.1.2"
- ✅ **Git Tag**: Created v26.1.2 tag
- ✅ **Release Notes**: Created comprehensive release notes

### 3. Package Verification
- ✅ **npm publish --dry-run**: Successful
  - Package size: 1.4 MB
  - Unpacked size: 8.1 MB
  - Total files: 142
- ✅ **Working directory**: Clean (except release notes)

## 📋 Remaining Steps (Manual)

### 4. Push to GitHub
```bash
git push origin copilot/prepare-v26-1-2-release
```

### 5. Merge Pull Request
1. Go to: https://github.com/jgphilpott/polyslice/pulls
2. Find PR for branch `copilot/prepare-v26-1-2-release`
3. Review changes
4. Merge to `main` branch

### 6. Push Tags
```bash
git checkout main
git pull origin main
git push origin v26.1.2
```

### 7. Create GitHub Release
1. Go to: https://github.com/jgphilpott/polyslice/releases/new
2. Select tag: `v26.1.2`
3. Title: "Release v26.1.2"
4. Description: Copy from `RELEASE_NOTES_v26.1.2.md`
5. Click "Publish release"

### 8. Publish to npm
```bash
npm login  # If not already logged in
npm publish
```

### 9. Verify Publication
```bash
# Check npm registry
npm view @jgphilpott/polyslice version
# Should output: 26.1.2

# Test installation in a new directory
mkdir test-install && cd test-install
npm install @jgphilpott/polyslice
node -e "const Polyslice = require('@jgphilpott/polyslice'); console.log(new Polyslice());"
```

### 10. Verify CDN
Wait a few minutes after npm publish, then check:
- https://unpkg.com/@jgphilpott/polyslice@26.1.2/
- https://unpkg.com/@jgphilpott/polyslice@26.1.2/dist/index.browser.js

## 📝 Release Summary

**Version:** 26.1.2
**Release Date:** January 28, 2026
**Release Type:** Feature Addition (Calendar-based: Third release of January 2026)

**Main Feature:** G-code metadata extraction with `getGcodeMetadata()` method
- Multi-slicer support (Polyslice, Cura, PrusaSlicer)
- Automatic slicer detection
- Structured metadata with units
- Backward compatible (no breaking changes)

**Validation Status:**
- All tests: ✅ PASSED (695/695)
- Linting: ✅ PASSED
- Build: ✅ PASSED
- Dry run: ✅ PASSED

## 🔗 Important Links

- **Repository**: https://github.com/jgphilpott/polyslice
- **npm Package**: https://www.npmjs.com/package/@jgphilpott/polyslice
- **Documentation**: https://github.com/jgphilpott/polyslice/blob/main/docs/api/API.md
- **CHANGELOG**: https://github.com/jgphilpott/polyslice/blob/main/CHANGELOG.md

## 📦 Files Modified

- `package.json` - Version bump to 26.1.2
- `CHANGELOG.md` - Added v26.1.2 release notes
- `RELEASE_NOTES_v26.1.2.md` - Comprehensive release notes
- `RELEASE_CHECKLIST_v26.1.2.md` - This checklist

## 🏷️ Git Information

- **Branch**: `copilot/prepare-v26-1-2-release`
- **Tag**: `v26.1.2`
- **Commit**: `36b6d46` ("26.1.2")

---

**Status**: Ready for merge, tag push, and npm publish! 🚀
