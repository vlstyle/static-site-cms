import { defineConfig } from 'astro/config';
import staticSiteCms from 'static-site-cms';

export default defineConfig({
  site: process.env.SITE_URL || 'http://localhost:4321',
  base: process.env.BASE_PATH || '/',
  trailingSlash: 'always',
  build: { format: 'directory' },
  integrations: [staticSiteCms()],
});
