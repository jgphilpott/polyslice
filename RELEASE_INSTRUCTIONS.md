# Release Instructions for v26.2.0

This document contains the final steps to complete the v26.2.0 release.

## ✅ Completed Steps

All preparation work has been completed:

1. ✅ Version updated to 26.2.0 in package.json
2. ✅ CHANGELOG.md updated with comprehensive changes since v26.1.2
3. ✅ RELEASE_NOTES.md created with detailed release information
4. ✅ All tests passing (740 tests, 36 test suites)
5. ✅ All builds successful (Node.js and browser bundles)
6. ✅ Linting passed with no errors
7. ✅ Git tag v26.2.0 created locally
8. ✅ Changes committed to copilot/prepare-release-v2620 branch

## 🔄 Remaining Steps

### 1. Merge PR and Push Tag

First, merge the PR for branch `copilot/prepare-release-v2620`:

```bash
# After PR is merged to main, checkout main and pull
git checkout main
git pull origin main

# Push the v26.2.0 tag
git push origin v26.2.0
```

### 2. Create GitHub Release

1. Go to https://github.com/jgphilpott/polyslice/releases/new
2. Select the tag: `v26.2.0`
3. Release title: `Release v26.2.0 - February 2026`
4. Copy the content from `RELEASE_NOTES.md` into the description
5. Click "Publish release"

### 3. Publish to npm

Before publishing, test with a dry run:

```bash
# Test the publish process
npm publish --dry-run
```

Review the output to ensure only the correct files will be published:
- dist/
- src/
- README.md
- LICENSE

Then publish:

```bash
npm publish
```

### 4. Verify Publication

After publishing, verify:

```bash
# Check npm package version
npm view @jgphilpott/polyslice version

# Test installation in a temp directory
mkdir /tmp/test-install
cd /tmp/test-install
npm install @jgphilpott/polyslice
node -e "const p = require('@jgphilpott/polyslice'); console.log('Version:', p.default ? 'loaded' : 'failed')"
```

### 5. Verify CDN Access

Check that the CDN has the new version:

- https://unpkg.com/@jgphilpott/polyslice@26.2.0/dist/index.browser.min.js
- https://unpkg.com/@jgphilpott/polyslice@26.2.0/dist/index.browser.esm.js

### 6. Post-Release Checklist

- [ ] GitHub release published
- [ ] npm package published
- [ ] CDN accessible
- [ ] Documentation updated (if needed)
- [ ] Announcement (optional - for major releases)

## 📝 Release Summary

**Version:** 26.2.0 (First release of February 2026)  
**Date:** February 14, 2026  
**Previous:** v26.1.2 (January 28, 2026)

**Major Features:**
- 4 new infill patterns: Concentric, Gyroid, Spiral, Lightning
- Infill pattern centering configuration
- Gyroid pattern algorithm completely revised

**Improvements:**
- Better layer-to-layer adhesion
- More consistent material usage
- Improved performance

**Bug Fixes:**
- Concentric infill gap and hole detection
- Cylinder bottom layer walls
- Spiral pattern tracking
- CI pipeline dependencies

## 📦 Package Information

- **Package:** @jgphilpott/polyslice
- **Registry:** npmjs.com
- **License:** MIT
- **Bundle sizes:**
  - Node.js CJS: 470.4kb
  - Node.js ESM: 470.7kb
  - Browser IIFE: 2.8mb (includes three.js)
  - Browser ESM: 935.7kb (external three.js)

## 🔗 Useful Links

- Repository: https://github.com/jgphilpott/polyslice
- npm Package: https://www.npmjs.com/package/@jgphilpott/polyslice
- Releases: https://github.com/jgphilpott/polyslice/releases
- Documentation: https://github.com/jgphilpott/polyslice#readme

## 💡 Notes

- This follows calendar-based versioning (YY.M.N)
- v26.2.0 = First release of February 2026
- Goal: At least one release per month
- No breaking changes in this release
