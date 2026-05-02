#!/usr/bin/env node
/**
 * Lance le Maven Wrapper depuis backend/ (compatible Windows/macOS/Linux).
 * Usage : node scripts/backend-mvnw.mjs -B test
 */
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const backendDir = join(__dirname, '..', 'backend');
const isWin = process.platform === 'win32';
const mvn = isWin ? 'mvnw.cmd' : './mvnw';
const args = process.argv.slice(2);

if (args.length === 0) {
  console.error('Usage: node scripts/backend-mvnw.mjs <arguments Maven>');
  console.error('Exemple : node scripts/backend-mvnw.mjs -B test');
  process.exit(1);
}

const result = spawnSync(mvn, args, {
  cwd: backendDir,
  stdio: 'inherit',
  shell: isWin,
  env: { ...process.env, CI: process.env.CI || '1' },
});

process.exit(result.status ?? (result.error ? 1 : 0));
