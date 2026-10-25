#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const OPERATOR_PATHS = [/^src\/content\//, /^public\/images\//];

const role = process.env.AUTHOR_ROLE ?? 'operator';
const base = process.env.BASE_REF ?? 'origin/main';

if (role !== 'operator') {
  console.log(`role=${role}: path guard skipped`);
  process.exit(0);
}

const changed = execFileSync('git', ['diff', '--name-only', `${base}...HEAD`], { encoding: 'utf8' })
  .split('\n')
  .filter(Boolean);

const violations = changed.filter((f) => !OPERATOR_PATHS.some((re) => re.test(f)));

if (violations.length > 0) {
  console.error('Operator は次のファイルを変更できません:');
  for (const f of violations) console.error(`  ${f}`);
  process.exit(1);
}
console.log(`path guard ok (${changed.length} files)`);
