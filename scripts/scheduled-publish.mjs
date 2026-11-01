#!/usr/bin/env node
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { extname, join, relative } from 'node:path';
import { formatLocal, readTimeZone, toLocalDate } from '../src/lib/timezone.mjs';

const root = process.argv[2] ?? '.';
const contentDir = join(root, 'src/content');
const zone = readTimeZone(root);
const now = new Date();

const walk = (dir) =>
  readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });

const frontMatter = (path, text) => {
  if (extname(path) === '.md' || extname(path) === '.mdx') {
    const m = text.match(/^---\r?\n([\s\S]*?)\r?\n---/);
    return m ? m[1] : '';
  }
  return text;
};

const field = (block, key) => {
  const m = block.match(new RegExp(`^${key}:[ \\t]*(.*?)[ \\t]*$`, 'm'));
  if (!m) return undefined;
  return m[1].replace(/\s+#.*$/, '').replace(/^["']|["']$/g, '');
};

const rows = [];
if (existsSync(contentDir)) {
  for (const path of walk(contentDir)) {
    if (!['.md', '.mdx', '.yaml', '.yml'].includes(extname(path))) continue;
    const block = frontMatter(path, readFileSync(path, 'utf8'));
    const raw = field(block, 'publishDate');
    if (!raw) continue;
    const date = new Date(toLocalDate(raw, zone));
    if (Number.isNaN(date.getTime()) || date <= now) continue;
    rows.push({ date, file: relative(root, path), title: field(block, 'title') ?? '' });
  }
}

rows.sort((a, b) => a.date - b.date || a.file.localeCompare(b.file));
if (rows.length > 0) {
  console.log(`| 公開日時（${zone}） | ファイル | タイトル |`);
  console.log('|---|---|---|');
  for (const r of rows) console.log(`| ${formatLocal(r.date, zone)} | \`${r.file}\` | ${r.title.replace(/\|/g, '\\|')} |`);
}
