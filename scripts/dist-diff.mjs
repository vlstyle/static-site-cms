#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { appendFileSync, mkdirSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, relative } from 'node:path';

const [baseDir, headDir, outDir = 'dist-diff'] = process.argv.slice(2);
if (!baseDir || !headDir) {
  console.error('使い方: cms-dist-diff <ベースの出力ディレクトリ> <PRの出力ディレクトリ> [レポートの出力先]');
  process.exit(1);
}

const TEXT_EXTENSIONS = new Set(['.html', '.css', '.js', '.mjs', '.json', '.xml', '.txt', '.svg', '.webmanifest']);
const HASHED_NAME = /\.[A-Za-z0-9_-]{8}\.(?=(?:js|mjs|css|woff2?|ttf|png|jpe?g|gif|webp|avif|svg|ico)\b)/g;
const LIMIT = 50;

const normalize = (text) => text.replace(HASHED_NAME, '.HASH.');

const walk = (dir) =>
  readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });

const collect = (dir, side) => {
  const files = new Map();
  for (const path of walk(dir)) {
    const rel = relative(dir, path);
    const key = normalize(rel);
    const raw = readFileSync(path);
    const isText = TEXT_EXTENSIONS.has(extname(path));
    const content = isText ? Buffer.from(normalize(raw.toString('utf8'))) : raw;
    const copy = join(outDir, side, key);
    mkdirSync(dirname(copy), { recursive: true });
    writeFileSync(copy, content);
    files.set(key, {
      size: raw.length,
      hash: createHash('sha256').update(content).digest('hex'),
      isText,
    });
  }
  return files;
};

const base = collect(baseDir, 'base');
const head = collect(headDir, 'head');

const added = [...head.keys()].filter((k) => !base.has(k)).sort();
const removed = [...base.keys()].filter((k) => !head.has(k)).sort();
const changed = [...head.keys()].filter((k) => base.has(k) && base.get(k).hash !== head.get(k).hash).sort();
const unchanged = head.size - added.length - changed.length;

const total = (files) => [...files.values()].reduce((sum, f) => sum + f.size, 0);
const delta = total(head) - total(base);
const sign = delta > 0 ? '+' : '';

const list = (title, keys, detail = () => '') => {
  if (keys.length === 0) return [];
  const shown = keys.slice(0, LIMIT).map((k) => `- \`${k}\`${detail(k)}`);
  const rest = keys.length > LIMIT ? [`- ほか ${keys.length - LIMIT} 件`] : [];
  return ['', `<details><summary>${title}（${keys.length}）</summary>`, '', ...shown, ...rest, '', '</details>'];
};

const sizeChange = (k) => {
  const diff = head.get(k).size - base.get(k).size;
  return diff === 0 ? '' : ` (${diff > 0 ? '+' : ''}${diff} B)`;
};

const noChange = added.length === 0 && removed.length === 0 && changed.length === 0;

const report = [
  `## ビルド成果物の差分（${process.env.DIST_DIFF_TITLE || 'ベースとの比較'}）`,
  '',
  noChange
    ? 'ビルド成果物に差分はありません。'
    : `追加 ${added.length} / 削除 ${removed.length} / 変更 ${changed.length} / 変更なし ${unchanged}（合計サイズ ${sign}${delta} B）`,
  '',
  ...(process.env.DIST_DIFF_NOTE ? [process.env.DIST_DIFF_NOTE, ''] : []),
  'ハッシュ付きのファイル名（`name.XXXXXXXX.js` など）は、ハッシュを無視して比較しています。',
  ...list('追加', added),
  ...list('削除', removed),
  ...list('変更', changed, sizeChange),
].join('\n');

writeFileSync(join(outDir, 'report.md'), `${report}\n`);
if (process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${report}\n`);
console.log(report);

try {
  execFileSync('diff', ['-ruN', join(outDir, 'base'), join(outDir, 'head')], { maxBuffer: 256 * 1024 * 1024 });
} catch (e) {
  if (e.status === 1) writeFileSync(join(outDir, 'dist.patch'), e.stdout);
  else throw e;
}
