#!/usr/bin/env node
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { extname, join } from 'node:path';

const dist = process.argv[2] ?? 'dist';
const base = (process.env.BASE_PATH ?? '/').replace(/\/+$/, '');

const htmlFiles = (dir) =>
  readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return htmlFiles(path);
    return extname(name) === '.html' ? [path] : [];
  });

const resolves = (path) => {
  const target = join(dist, decodeURIComponent(path.split(/[?#]/)[0]));
  if (path.endsWith('/')) return existsSync(join(target, 'index.html'));
  return existsSync(target) || existsSync(join(target, 'index.html'));
};

const errors = [];
for (const file of htmlFiles(dist)) {
  const html = readFileSync(file, 'utf8');
  for (const [, value] of html.matchAll(/\s(?:href|src)="(\/[^"]*)"/g)) {
    if (value.startsWith('//')) continue;
    if (base && value !== base && !value.startsWith(`${base}/`)) {
      errors.push(`${file}: ${value} は ${base} で始まっていません`);
      continue;
    }
    const local = base ? value.slice(base.length) || '/' : value;
    if (!resolves(local)) errors.push(`${file}: ${value} が見つかりません`);
  }
}

if (errors.length > 0) {
  for (const e of errors) console.error(e);
  process.exit(1);
}
console.log(`link check ok (base=${base || '/'})`);
