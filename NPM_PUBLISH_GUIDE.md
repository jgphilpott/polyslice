# npm Publishing Guide for v26.1.1

## Prerequisites

1. **Merge the PR**: This release branch must be merged to `main` first
2. **npm Authentication**: Must be logged in with publishing rights
3. **2FA Ready**: Have 2FA token generator ready if enabled

## Publishing Steps

### 1. Prepare Local Environment

```bash
# Switch to main branch
git checkout main

# Pull latest changes (after PR merge)
git pull origin main

# Verify you're on the right commit
git log -1
# Should show: "26.1.1"

# Verify tag exists locally
git tag -l v26.1.1
# Should show: v26.1.1
```

### 2. Push Git Tag

```bash
# Push the tag to GitHub
git push origin v26.1.1

# Verify on GitHub
# Visit: https://github.com/jgphilpott/polyslice/tags
```

### 3. Verify npm Login

```bash
# Check current npm user
npm whoami
# Should show: jgphilpott

# If not logged in:
npm login
```

### 4. Test Publish (Dry Run)

```bash
# Test what will be published
npm publish --dry-run

# Check the output for:
# - Correct version (26.1.1)
# - Files being included (dist/, src/, README.md, LICENSE)
# - No unexpected files
```

Expected output should include:
```
npm notice package: @jgphilpott/polyslice@26.1.1
npm notice === Tarball Contents ===
npm notice dist/
npm notice src/
npm notice README.md
npm notice LICENSE
npm notice package.json
```

### 5. Verify Package Contents

```bash
# Create a tarball to inspect
npm pack

# Extract and inspect
tar -xvzf jgphilpott-polyslice-26.1.1.tgz
cd package
ls -la

# Check:
# - dist/ directory exists with all builds
# - src/ directory has source files
# - README.md and LICENSE present
# - No node_modules/

# Clean up
cd ..
rm -rf package jgphilpott-polyslice-26.1.1.tgz
```

### 6. Actual Publish

```bash
# Publish to npm registry
npm publish

# This will:
# - Run prepublishOnly hook (npm run build && npm run build:minify)
# - Build all distributions
# - Create minified versions
# - Publish to registry

# Enter 2FA code if prompted
```

Expected output:
```
> @jgphilpott/polyslice@26.1.1 prepublishOnly
> npm run build && npm run build:minify

[build output...]

npm notice 
npm notice 📦  @jgphilpott/polyslice@26.1.1
npm notice === Tarball Details ===
npm notice name:          @jgphilpott/polyslice
npm notice version:       26.1.1
npm notice filename:      jgphilpott-polyslice-26.1.1.tgz
npm notice package size:  XXX.X kB
npm notice unpacked size: XXX.X kB
npm notice shasum:        [hash]
npm notice integrity:     [integrity]
npm notice total files:   XXX
npm notice 
npm notice Publishing to https://registry.npmjs.org/
+ @jgphilpott/polyslice@26.1.1
```

### 7. Verify Publication

```bash
# Check published version
npm view @jgphilpott/polyslice version
# Should output: 26.1.1

# Check all metadata
npm view @jgphilpott/polyslice

# Try installing in a test directory
mkdir /tmp/test-install
cd /tmp/test-install
npm init -y
npm install @jgphilpott/polyslice
node -e "console.log(require('@jgphilpott/polyslice').version)"
# Should output: undefined or check another way

# Clean up
cd -
rm -rf /tmp/test-install
```

### 8. Verify CDN

Wait 5-10 minutes for CDN to update, then check:

```bash
# unpkg CDN
curl -I https://unpkg.com/@jgphilpott/polyslice@26.1.1/
# Should return 200 OK

# Check browser bundle
curl -I https://unpkg.com/@jgphilpott/polyslice@26.1.1/dist/index.browser.min.js
# Should return 200 OK
```

### 9. Create GitHub Release

1. Go to: https://github.com/jgphilpott/polyslice/releases
2. Click "Draft a new release"
3. Choose tag: `v26.1.1` (should exist now)
4. Release title: `Release v26.1.1`
5. Description: Copy from `RELEASE_NOTES_v26.1.1.md`
6. Click "Publish release"

### 10. Announce Release (Optional)

Consider announcing on:
- GitHub Discussions
- Project README (update badges if needed)
- Social media (if applicable)
- npm package README updates

## Troubleshooting

### "You must verify your email to publish packages"
```bash
# Check email verification status
npm profile get

# Resend verification email if needed
npm profile set email your-email@example.com
```

### "You do not have permission to publish"
```bash
# Check package access
npm owner ls @jgphilpott/polyslice

# Add yourself if needed
npm owner add jgphilpott @jgphilpott/polyslice
```

### "Version 26.1.1 already exists"
If the version was already published:
```bash
# Check what's published
npm view @jgphilpott/polyslice versions

# If you need to republish (NOT recommended):
# 1. Deprecate the version
npm deprecate @jgphilpott/polyslice@26.1.1 "Republishing"

# 2. Wait 24 hours or contact npm support
# 3. Or bump to 26.1.2
```

### Build Fails During prepublishOnly
```bash
# Run builds manually to debug
npm run compile
npm run build
npm run build:minify

# Check for errors
# Fix any issues
# Try publish again
```

## Rollback Procedure

If critical issues are found after publishing:

### Option 1: Deprecate (Recommended)
```bash
npm deprecate @jgphilpott/polyslice@26.1.1 "Critical bug, use 26.1.2 instead"
```

### Option 2: Unpublish (Only within 72 hours)
```bash
npm unpublish @jgphilpott/polyslice@26.1.1
```

**Note**: Unpublishing is discouraged. Better to:
1. Deprecate the bad version
2. Fix the issue
3. Publish a new version (26.1.2)

## Post-Publish Checklist

- [ ] `npm view @jgphilpott/polyslice version` returns 26.1.1
- [ ] Test installation works in clean directory
- [ ] unpkg CDN serves the package
- [ ] GitHub release created
- [ ] Git tag pushed to GitHub
- [ ] No issues reported in first 24 hours
- [ ] Update project README if needed
- [ ] Close any related issues/PRs

## Support

If you encounter issues:
1. Check npm status: https://status.npmjs.org/
2. Review npm publish docs: https://docs.npmjs.com/cli/publish
3. Contact npm support: https://www.npmjs.com/support
