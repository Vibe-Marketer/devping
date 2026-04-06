# Publish Commands

## 1. Build and notarize the app

```bash
./scripts/package-release.sh
./scripts/notarize-release.sh
```

## 2. Verify Gatekeeper acceptance

```bash
spctl -a -t exec -vv build/DevPing.app
```

Expected output includes:
- `accepted`
- `source=Notarized Developer ID`

## 3. Website local checks

```bash
cd website
npm install
npm run check
npm run build
```

## 4. Website deployment with Vercel

```bash
cd website
vercel
vercel --prod
```

Suggested production domain:
- `devping.app`

## 5. GitHub release draft prep

Release title:
- `DevPing v1.2.7 — notarized direct launch build`

Release notes source:
- `docs/GITHUB-RELEASE.md`

Checksums:
- `docs/RELEASE-CHECKSUMS.md`

## 6. Optional GitHub CLI release flow

Review before running:

```bash
gh release create v1.2.7 \
  build/DevPing-v1.2.7.zip \
  --title "DevPing v1.2.7 — notarized direct launch build" \
  --notes-file docs/GITHUB-RELEASE.md
```

## 7. Launch copy source files

- `docs/LAUNCH-POSTS.md`
- `docs/WEBSITE-COPY.md`
- `docs/SCREENSHOT-CHECKLIST.md`
- `docs/LAUNCH-CHECKLIST.md`
