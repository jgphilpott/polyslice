# Troubleshooting

## npm pack/publish Issues

If you encounter errors like `ENOENT: no such file or directory, lstat '/path/to/rc/polyslice.coffee'` when running `npm pack` or `npm publish`, try these solutions:

1. **Clear npm cache:**
   ```bash
   npm cache clean --force
   ```

2. **Remove node_modules and reinstall:**
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

3. **Ensure all files are built:**
   ```bash
   npm run build
   ```

4. **Check for corrupted workspace:**
   ```bash
   git status
   git clean -fd  # Remove untracked files
   ```

## Workflow Badge Issues

If the GitHub Actions badge is not displaying correctly, ensure:

1. The workflow file is in `.github/workflows/` (lowercase)
2. The workflow has run at least once
3. The badge URL matches the workflow file name

## Development Workflow

1. Write CoffeeScript in `src/*.coffee`
2. Run `npm run compile` to generate JavaScript
3. Run `npm test` to test (auto-compiles first)
4. Run `npm run build` to create distribution files
5. Run `npm pack --dry-run` to test packaging