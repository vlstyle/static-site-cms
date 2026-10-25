import { defineConfig } from 'astro/config';
import staticSiteCms from 'static-site-cms';

export default defineConfig({
  site: process.env.SITE_URL || 'http://localhost:4321',
  trailingSlash: 'always',
  build: { format: 'directory' },
  integrations: [staticSiteCms()],
});
