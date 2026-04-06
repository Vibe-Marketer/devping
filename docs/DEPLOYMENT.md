# Deployment

## Website

Project path:
- `website/`

Domain:
- `https://devping.app`

### Vercel (recommended)

From `website/`:

```bash
vercel
vercel --prod
```

Build settings:
- Framework: Astro
- Build command: `npm run build`
- Output directory: `dist`

### Static hosting fallback
The Astro site is static and can also be deployed to:
- Netlify
- Cloudflare Pages
- GitHub Pages
- any static file host

## App release

Current release files:
- `build/DevPing.app`
- `build/DevPing-v1.2.6.zip`

Release flow:

```bash
./scripts/package-release.sh
./scripts/notarize-release.sh
```

Verification:

```bash
spctl -a -t exec -vv build/DevPing.app
```

Expected result:
- accepted
- source=Notarized Developer ID
