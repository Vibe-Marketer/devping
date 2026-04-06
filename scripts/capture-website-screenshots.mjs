import { chromium, devices } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';

const url = process.argv[2] || 'https://devping.app';
const outDir = process.argv[3] || 'docs/assets/screenshots';
await fs.mkdir(outDir, { recursive: true });
await fs.mkdir('website/public/screenshots', { recursive: true });

const browser = await chromium.launch({ headless: true });

async function saveBoth(page, name, options = {}) {
  const fileA = path.join(outDir, name);
  const fileB = path.join('website/public/screenshots', name);
  await page.screenshot({ path: fileA, ...options });
  await fs.copyFile(fileA, fileB);
}

const desktop = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
await desktop.goto(url, { waitUntil: 'networkidle' });
await desktop.locator('h1').waitFor();
await saveBoth(desktop, 'website-home-desktop-full.png', { fullPage: true });
await desktop.locator('main > section').first().screenshot({ path: path.join(outDir, 'website-home-hero-desktop.png') });
await fs.copyFile(path.join(outDir, 'website-home-hero-desktop.png'), path.join('website/public/screenshots', 'website-home-hero-desktop.png'));
await desktop.locator('#features').screenshot({ path: path.join(outDir, 'website-home-features-desktop.png') });
await fs.copyFile(path.join(outDir, 'website-home-features-desktop.png'), path.join('website/public/screenshots', 'website-home-features-desktop.png'));
await desktop.locator('#trust').screenshot({ path: path.join(outDir, 'website-home-trust-desktop.png') });
await fs.copyFile(path.join(outDir, 'website-home-trust-desktop.png'), path.join('website/public/screenshots', 'website-home-trust-desktop.png'));
await desktop.close();

const mobile = await browser.newPage({ ...devices['iPhone 13'] });
await mobile.goto(url, { waitUntil: 'networkidle' });
await mobile.locator('h1').waitFor();
await saveBoth(mobile, 'website-home-mobile-full.png', { fullPage: true });
await mobile.close();

await browser.close();
console.log('Saved screenshots to', outDir, 'and website/public/screenshots');
