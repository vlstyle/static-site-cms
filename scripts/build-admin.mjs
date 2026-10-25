#!/usr/bin/env node
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const adminDir = fileURLToPath(new URL('../admin', import.meta.url));
const out = process.env.ADMIN_OUT_DIR || 'dist-admin';
const siteUrl = process.env.SITE_URL || 'http://localhost:4321';

if (!existsSync('cms.config.json')) {
  console.error('cms.config.json が見つかりません');
  process.exit(1);
}
const { repo, branch = 'main', baseUrl } = JSON.parse(readFileSync('cms.config.json', 'utf8'));
if (!repo) {
  console.error('cms.config.json に repo (owner/name) を指定してください');
  process.exit(1);
}

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
cpSync(`${adminDir}/index.html`, `${out}/index.html`);

const config = readFileSync(`${adminDir}/config.template.yml`, 'utf8')
  .replaceAll('__REPO__', repo)
  .replaceAll('__BRANCH__', branch)
  .replaceAll('__BASE_URL_LINE__', baseUrl ? `  base_url: ${baseUrl}\n` : '')
  .replaceAll('__SITE_URL__', siteUrl);
writeFileSync(`${out}/config.yml`, config);
console.log(`admin built -> ${out} (repo=${repo}, site_url=${siteUrl})`);
