#!/usr/bin/env node
import { execFileSync } from 'node:child_process';

const base = process.env.BASE_REF ?? 'origin/main';
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const IMAGE_EXTENSIONS = /\.(png|jpe?g|webp|gif|avif|svg)$/i;
const SAFE_PATH = /^[A-Za-z0-9._\/-]+$/;

const git = (...args) => execFileSync('git', args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });

const changed = git('diff', '--name-only', '--diff-filter=AMR', '-z', `${base}...HEAD`)
  .split('\0')
  .filter(Boolean);

const errors = [];

for (const file of changed) {
  if (!SAFE_PATH.test(file)) {
    errors.push(`${file}: ファイル名に使えるのは半角英数字と . _ - のみです（日本語・空白は不可）`);
    continue;
  }
  if (file.startsWith('public/images/') && !file.endsWith('/.gitkeep')) {
    if (!IMAGE_EXTENSIONS.test(file)) {
      errors.push(`${file}: public/images/ に置けるのは画像ファイルのみです`);
      continue;
    }
    const size = Number(git('cat-file', '-s', `HEAD:${file}`));
    if (size > MAX_IMAGE_BYTES) {
      errors.push(`${file}: ${(size / 1024 / 1024).toFixed(1)}MB は上限 ${MAX_IMAGE_BYTES / 1024 / 1024}MB を超えています`);
    }
  }
}

if (errors.length > 0) {
  for (const e of errors) console.error(e);
  process.exit(1);
}
console.log(`file check ok (${changed.length} files)`);
