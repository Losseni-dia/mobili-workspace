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
  // Sur Windows, shell:true casse les chemins avec espaces (ex. C:\Program Files\nodejs\node.exe).
  const useShell = isWin && cmd !== process.execPath;
  const r = spawnSync(cmd, args, {
    cwd,
    stdio: 'inherit',
    shell: useShell,
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

console.log('▶ backend: Maven Wrapper → test (reactor backend + mobili-core + mobili-boot) …');
run(root, process.execPath, [join(root, 'scripts', 'backend-mvnw.mjs'), '-B', 'test']);

console.log('▶ frontend: ng build (development) — appli « voyageur » (racine) …');
run(frontend, 'npx', ['ng', 'build', '--configuration=development']);

console.log('▶ frontend: ng build mobili-business (development) — portail partenaire (Phase 1) …');
run(frontend, 'npx', ['ng', 'build', 'mobili-business', '--configuration=development']);

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

console.log(
  '✓ verify terminé : backend + ng build (frontend) + ng build (mobili-business) + ng test',
);
console.log(
  '  (optionnel, aligné CI Playwright) depuis la racine : npm run verify:e2e:all',
);
