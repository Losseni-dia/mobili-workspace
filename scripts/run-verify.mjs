/**
 * Vérification complète (compile + tests) — portable (Node).
 * usage : npm run verify
 */
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { existsSync } from 'node:fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = join(__dirname, '..');

function run(cwd, cmd, args, extraEnv = {}) {
  const isWin = process.platform === 'win32';
  const r = spawnSync(cmd, args, {
    cwd,
    stdio: 'inherit',
    shell: isWin,
    env: { ...process.env, ...extraEnv, CI: '1' },
  });
  if (r.error) throw r.error;
  if (r.status !== 0) process.exit(r.status ?? 1);
}

const backend = join(root, 'backend');
const frontend = join(root, 'frontend');

if (!existsSync(join(backend, 'pom.xml'))) {
  console.error('Backend introuvable :', backend);
  process.exit(1);
}
if (!existsSync(join(frontend, 'package.json'))) {
  console.error('Frontend introuvable :', frontend);
  process.exit(1);
}

console.log('▶ backend: mvn test (compile + tests unitaires) …');
run(backend, 'mvn', ['-B', 'test']);

console.log('▶ frontend: ng build (development) …');
run(frontend, 'npx', ['ng', 'build', '--configuration=development']);

const ngTest = ['ng', 'test', '--watch=false'];
console.log('▶ frontend: ng test (sans watch) …');
const testResult = spawnSync('npx', ngTest, {
  cwd: frontend,
  stdio: 'inherit',
  shell: process.platform === 'win32',
  env: { ...process.env, CI: '1' },
});
if (testResult.status !== 0) {
  console.error(
    "Les tests front ont échoué. Si le navigateur headless manque, installez les deps du projet ou lancez : set CI=true && npx ng test --watch=false",
  );
  process.exit(testResult.status ?? 1);
}

console.log('✓ verify terminé : backend compile + mvn test + ng build + ng test');
