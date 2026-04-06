import type { APIRoute } from 'astro';

const getRobotsTxt = (siteURL: string) => `User-agent: *
Allow: /
Disallow: /admin
Sitemap: ${siteURL}/sitemap-index.xml`;

export const GET: APIRoute = ({ site }) => {
  return new Response(getRobotsTxt(site?.toString().replace(/\/$/, '') || 'https://devping.app'));
};
