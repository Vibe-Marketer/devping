# DevPing Website

Astro marketing site for the DevPing launch.

## Domain

Production canonical domain:

- `https://devping.app`

## Stack

- Astro
- Tailwind
- sitemap integration
- static output

## Commands

```bash
npm install
npm run dev
npm run check
npm run build
npm run preview
```

## Pages

- `/`
- `/privacy`
- `/support`
- `/uninstall`
- `/robots.txt`
- sitemap output during build

## Deployment

This site is static and can be deployed to:

- Vercel
- Netlify
- Cloudflare Pages
- GitHub Pages
- any static host

### Recommended deployment
Vercel is the simplest default for this project.

Build command:

```bash
npm run build
```

Output directory:

```bash
dist
```

## SEO notes

- canonical domain is set in `astro.config.mjs`
- sitemap is enabled
- robots.txt is generated
- OG image is in `public/og-default.svg`

## Launch note

This site is intentionally focused on the direct-download launch, not App Store distribution.
