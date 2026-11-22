import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-laravel.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['ts-node/register'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/** A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled. */
function project(type: string) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'laravel-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${type}\ndocroot: ""\n`);
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'laravel'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'laravel', 'site.feature'));
  return { root, dir, scripts };
}

/** Run bash with the plugin's functions sourced and `ddev` replaced by a recorder. */
function bash(script: string, env: Record<string, string> = {}) {
  const r = spawnSync('bash', ['-c', `ddev() { echo "ddev $*" >> "\${DDEV_LOG:-/dev/null}" ; if [ "$1" == "exec" ] && [ -f "$5" ] ; then cat "$5" >> "\${DDEV_LOG:-/dev/null}" ; fi ; return 0 ; }\nsource ${FUNCTIONS}\n${script}`],
    { encoding: 'utf8', env: { ...process.env, ...env } });
  return r;
}

test('the default accounts are a verified one and one whose address is not verified, with example addresses', () => {
  const r = bash('set_laravel_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; l="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!l}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['member', 'unverified']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['verified', 'unverified']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 12, 'long enough for the password rules of a live app');
  }
});

test('the accounts are written through the app, with their state, and removed through it', () => {
  const p = project('laravel');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log };
  let r = bash('set_laravel_users ; add_laravel_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  let written = fs.readFileSync(log, 'utf8');
  assert.match(written, /ddev exec php \.webship-accounts-\d+\.php save \.webship-accounts-\d+\.txt/);
  assert.match(written, /^member\|member@example\.com\|[^|]+\|verified$/m);
  assert.match(written, /^unverified\|unverified@example\.com\|[^|]+\|unverified$/m);
  assert.deepStrictEqual(fs.readdirSync(p.dir).filter((f) => f.startsWith('.webship-accounts')), [], 'the files of the write are gone');
  fs.writeFileSync(log, '');
  r = bash('set_laravel_users ; cancel_laravel_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  written = fs.readFileSync(log, 'utf8');
  assert.match(written, /ddev exec php \.webship-accounts-\d+\.php delete /);
  assert.match(written, /^member\|member@example\.com\|\|$/m);
});

test('the accounts get a hashed password even where the User model does not hash it, and keep a hash that matches', () => {
  const src = fs.readFileSync(FUNCTIONS, 'utf8');
  const php = src.slice(src.indexOf("cat > \"${script}\" <<'PHPEOF'"), src.indexOf('PHPEOF\n', src.indexOf("<<'PHPEOF'") + 10));
  assert.match(php, /Hash::make\(\$password\)/, 'the password is hashed with the app\'s hasher');
  assert.match(php, /Hash::check\(\$password, \$user->password\)/, 'a password the account already has keeps its hash');
  assert.doesNotMatch(php, /\$user->password = \$password;/, 'never the password as it is written');
});

test('the testing hook adds the step pack, the users registry, the mailbox, the tags and a first feature to a Laravel project, once', () => {
  const p = project('laravel');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_laravel ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/laravel-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/laravel-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /member: \{ email: process\.env\.LARAVEL_MEMBER_EMAIL \|\| 'member@example\.com', password: process\.env\.LARAVEL_MEMBER_PASSWORD \|\| '[^']+', name: 'member' \},/);
  assert.match(cucumber, /unverified: \{ email: process\.env\.LARAVEL_UNVERIFIED_EMAIL \|\| 'unverified@example\.com'/);
  assert.match(cucumber, /mailUrl: process\.env\.MAIL_URL \|\|/);
  assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail and not @maintenance and not @debug-page',/);
  // Still a module node can load, with the registry where webship-js reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users), c.tags, typeof c.worldParameters.mailUrl]))`], { encoding: 'utf8', env: { ...process.env, LAUNCH_URL: 'https://site1.ddev.site' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags, mail] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['member', 'unverified']);
  assert.match(tags, /not @maintenance/);
  assert.strictEqual(mail, 'string');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), /^member\|member@example\.com\|[^|]+\|verified$/m, 'a migrated app gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('in an app whose package.json is a module, cucumber.js becomes an ES module and tests/ stays CommonJS, once', () => {
  const p = project('laravel');
  fs.writeFileSync(path.join(p.dir, 'package.json'), JSON.stringify({ name: 'site1', private: true, type: 'module', devDependencies: { 'webship-js': '^2.0.16' } }, null, 2));
  const run = () => bash(`cd ${p.dir} && testing_configure_laravel ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const src = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  assert.match(src, /^const config = \{/m);
  assert.doesNotMatch(src, /module\.exports/);
  assert.match(src, /\nexport default config\.default;\n$/);
  assert.deepStrictEqual(JSON.parse(fs.readFileSync(path.join(p.dir, 'tests', 'package.json'), 'utf8')), { type: 'commonjs' });
  // Node reads it the way cucumber-js does in such a package: as an ES module, its default export the default profile.
  const url = 'file://' + path.join(p.dir, 'cucumber.js');
  const loaded = spawnSync(process.execPath, ['--input-type=module', '-e', `const c = (await import(${JSON.stringify(url)})).default; console.log(JSON.stringify([c.require.length, Object.keys(c.worldParameters.users), c.tags]))`], { encoding: 'utf8', env: { ...process.env, LAUNCH_URL: 'https://site1.ddev.site' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires, 3);
  assert.deepStrictEqual(handles, ['member', 'unverified']);
  assert.match(tags, /not @debug-page/);
  // Again: nothing is converted twice.
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), src);
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal11');
  const r = bash(`cd ${p.dir} && testing_configure_laravel ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the Artisan tool refuses a project that is not Laravel', () => {
  const p = project('drupal11');
  const r = bash('PROJECT_NAME=site1 ; RUN="about" ; trim_project_name() { :; } ; laravel_artisan_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a Laravel project/);
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /laravel|livewire|inertia|fortify/i, s);
  assert.doesNotMatch(feature, /password "/);
  assert.doesNotMatch(feature, /user create|I register/i, 'a suite never creates an account');
});

// ---- The runtimes: DDEV as before, and Docker Compose, Podman, Kubernetes, Lando and Docksal through the core's layer ----

const ADDRESSES: Record<string, string> = {
  docker: 'http://127.0.0.1:41234', podman: 'http://127.0.0.1:41234', lando: 'http://127.0.0.1:41234',
  kubernetes: 'http://172.18.0.2:30080', docksal: 'http://site1.docksal.site',
};

/**
 * Run the builder in a throwaway workspace with `ddev` replaced by a recorder, and the core's layer by stand-ins:
 * `layer` is the runtime it answers with (runtime_of, rt_url), or '' for a core that has no layer yet. The
 * recorder makes the .env.example the official installer would have made.
 */
function build(layer: string, env: Record<string, string> = {}) {
  const p = project('laravel');
  fs.rmSync(p.dir, { recursive: true });
  const log = path.join(p.root, 'ddev.log');
  const address = ADDRESSES[layer] || '';
  const prelude = [
    `ddev() { echo "ddev $*" >> "${log}" ; case "$*" in *" new temp "*) printf 'APP_URL=http://localhost\\nDB_CONNECTION=sqlite\\n# DB_HOST=127.0.0.1\\n# DB_DATABASE=laravel\\nMAIL_MAILER=log\\n' > .env.example ;; esac ; return 0 ; }`,
    'trim_project_name() { :; } ; drop_database() { :; } ; ddev_nodejs_version() { echo 24 ; } ; ddev_up() { ddev "$@" ; }',
    layer ? `runtime_of() { echo "\${RUNTIME_ANSWER}" ; } ; rt_url() { [ "\${RUNTIME_ANSWER}" == ddev ] && echo "https://\${PROJECT_NAME}.ddev.site" || echo "${address}" ; }` : '',
    `source ${FUNCTIONS}`,
    'laravel_build',
  ].join('\n');
  const r = spawnSync('bash', ['-c', prelude], { encoding: 'utf8', input: '', env: { ...process.env, WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1',
    INSTALL: 'yes', ADD_USERS: 'no', PRODUCTION: 'no', LAUNCH: 'no', STARTER_KIT: 'livewire', distribution_webroot: 'public', RUNTIME: '_none_', RUNTIME_ANSWER: layer || 'ddev',
    account_name: 'webmaster', account_pass: 'CHANGE_ME.123123', account_mail: 'webmaster@example.com', ...env } });
  const calls = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n').filter((c) => c.startsWith('ddev ')).map((c) => c.replace(/\.webship-accounts-\d+\./g, '.webship-accounts-N.')) : [];
  return { r, calls, dir: path.join(p.root, 'dev', 'site1'), root: p.root };
}

test('on DDEV the build is what it was: the same commands with the layer and without it, the installer in DDEV\'s image', () => {
  const without = build('');
  const withLayer = build('ddev');
  for (const b of [without, withLayer]) {
    assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
    assert.match(b.r.stdout, /Go to https:\/\/site1\.ddev\.site\/login and log in as webmaster@example\.com/);
    assert.ok(!fs.existsSync(path.join(b.dir, '.env')), 'DDEV writes the .env: the builder writes none');
    assert.ok(!fs.existsSync(path.join(b.dir, 'compose.yaml')));
  }
  assert.deepStrictEqual(withLayer.calls, without.calls);
  assert.deepStrictEqual(without.calls.slice(0, 2), [
    'ddev config --project-type=laravel --docroot=public --project-name=site1 --nodejs-version=24 --auto',
    'ddev start -y',
  ]);
  assert.ok(without.calls.includes('ddev exec laravel new temp --livewire --database=sqlite --pest --npm --no-boost --no-interaction'));
  assert.ok(without.calls.includes('ddev exec rsync -rltgopD temp/ ./ && rm -rf temp'));
  assert.ok(without.calls.includes('ddev restart'), 'the restart that writes the .env');
  assert.ok(without.calls.includes('ddev artisan --version'));
  assert.ok(!without.calls.some((c) => c.startsWith('ddev npm ')), 'npm runs in the web container, through the installer');
});

test('on Docker Compose, Podman, Kubernetes, Lando and Docksal the app gets the .env DDEV would write, its front end from the tests container, Artisan through exec', () => {
  const ddev = build('ddev').calls;
  for (const runtime of Object.keys(ADDRESSES)) {
    const address = ADDRESSES[runtime];
    const b = build(runtime, { RUNTIME: runtime });
    assert.strictEqual(b.r.status, 0, runtime + ': ' + b.r.stderr + b.r.stdout);
    assert.deepStrictEqual(b.calls.slice(0, 2), ddev.slice(0, 2), runtime);
    const installer = b.calls.find((c) => c.includes(' new temp '));
    assert.match(installer || '', /^ddev exec composer global require laravel\/installer .* && LARAVEL_INSTALLER_NO_NODE=1 ".*\/laravel" new temp --livewire --database=sqlite --pest --no-boost --no-interaction$/, runtime);
    assert.ok(b.calls.includes('ddev exec cp -a temp/. ./ && rm -rf temp'), runtime);
    assert.ok(b.calls.includes('ddev npm install --no-audit --no-fund') && b.calls.includes('ddev npm run build'), runtime);
    assert.ok(!b.calls.includes('ddev restart'), `${runtime}: no restart, the builder writes the .env`);
    assert.ok(!b.calls.some((c) => /^ddev (artisan|dotenv) /.test(c)), `${runtime}: no verb the layer does not know`);
    assert.ok(b.calls.includes('ddev exec php artisan --version'), runtime);
    assert.ok(!fs.existsSync(path.join(b.dir, '.ddev')), `${runtime}: nothing of DDEV's is written`);
    const dotenv = fs.readFileSync(path.join(b.dir, '.env'), 'utf8');
    for (const line of [`APP_URL=${address}`, 'DB_CONNECTION=mariadb', 'DB_HOST=db', 'DB_PORT=3306', 'DB_DATABASE=db', 'DB_USERNAME=db', 'DB_PASSWORD=db', 'MAIL_MAILER=smtp', 'MAIL_PORT=1025']) {
      assert.match(dotenv, new RegExp(`^${line.replace(/[.:/]/g, '\\$&')}$`, 'm'), `${runtime}: ${line}`);
    }
    assert.match(dotenv, new RegExp(`^MAIL_HOST=${runtime === 'lando' ? 'mailpit' : 'mail'}$`, 'm'), runtime);
    assert.doesNotMatch(dotenv, /^# DB_HOST/m, 'the commented-out key is the one set');
    assert.match(b.r.stdout, new RegExp(`Go to ${address.replace(/[.]/g, '\\.')}/login and log in as webmaster@example\\.com`), runtime);
    assert.doesNotMatch(b.r.stdout + dotenv, /ddev\.site/, runtime);
  }
});

test('a .env key is set where the file has it, commented out or not, and added when it has none', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'laravel-dotenv-'));
  const file = path.join(dir, '.env');
  fs.writeFileSync(file, 'APP_NAME=Laravel\nAPP_ENV=local\n# DB_HOST=127.0.0.1\nDB_HOST_OTHER=x\n');
  const r = bash(`runtime_of() { echo docker ; } ; laravel_dotenv_set ${file} --app-env=production --db-host=db --mail-from-name='Two words' --queue-connection=sync`);
  assert.strictEqual(r.status, 0, r.stderr);
  assert.strictEqual(fs.readFileSync(file, 'utf8'), 'APP_NAME=Laravel\nAPP_ENV=production\nDB_HOST=db\nDB_HOST_OTHER=x\nMAIL_FROM_NAME="Two words"\nQUEUE_CONNECTION=sync\n');
  // On DDEV it is DDEV's own verb.
  const log = path.join(dir, 'ddev.log');
  bash(`runtime_of() { echo ddev ; } ; laravel_dotenv_set .env --app-env=production`, { DDEV_LOG: log });
  assert.strictEqual(fs.readFileSync(log, 'utf8'), 'ddev dotenv set .env --app-env=production\n');
});

test('--runtime on a workspace without the runtime layer is refused, never built on DDEV in silence', () => {
  const b = build('', { RUNTIME: 'docker' });
  assert.strictEqual(b.r.status, 1);
  assert.match(b.r.stdout, /--runtime docker needs a Webship Workspace with the container runtimes/);
  assert.deepStrictEqual(b.calls, []);
  assert.ok(!fs.existsSync(b.dir), 'no folder was made');
  assert.strictEqual(build('', { RUNTIME: 'ddev' }).r.status, 0);
});

test('the builder takes --runtime, with the runtimes of the core\'s own builders', () => {
  const args = fs.readFileSync(path.join(PKG, 'scripts', 'args', 'arg-laravel.sh'), 'utf8');
  assert.match(args, /parser\.add_argument\('--runtime',\s+dest='RUNTIME',\s+default="_none_",\s+choices=\['ddev', 'docker', 'podman', 'kubernetes', 'lando', 'docksal'\],/);
});

/** An app of another runtime: compose.yaml with its type, no .ddev folder. */
function runtimeApp() {
  const p = project('laravel');
  fs.rmSync(path.join(p.dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(p.dir, 'compose.yaml'), 'name: site1\nx-webship:\n  runtime: docker\n  type: laravel\n  port: 41234\n');
  return p;
}
const LAYER = 'runtime_of() { echo docker ; } ; rt_is_platform() { grep -q "^  type: $2$" "$1/compose.yaml" 2>/dev/null ; } ; rt_url() { echo http://127.0.0.1:41234 ; } ; ';

test('an app is known on every runtime: the layer reads its type', () => {
  const rt = runtimeApp();
  assert.strictEqual(bash(`${LAYER} laravel_is_project ${rt.dir}`).status, 0);
  assert.notStrictEqual(bash(`laravel_is_project ${rt.dir}`).status, 0, 'an older core reads no compose.yaml');
  assert.strictEqual(bash(`laravel_is_project ${project('laravel').dir}`).status, 0, 'DDEV as before');
  assert.notStrictEqual(bash(`${LAYER} laravel_is_project ${project("drupal11").dir}`).status, 0);
});

test('the Artisan tool and the test users work on an app of a runtime, and say its address', () => {
  const rt = runtimeApp();
  const log = path.join(rt.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: rt.root, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log };
  const add = bash(`${LAYER} set_laravel_users ; add_laravel_users`, env);
  assert.strictEqual(add.status, 0, add.stdout + add.stderr);
  assert.match(fs.readFileSync(log, 'utf8'), /^member\|member@example\.com\|[^|]+\|verified$/m);
  fs.writeFileSync(log, '');
  const tool = (run: string) => bash(`${LAYER} trim_project_name() { :; } ; RUN="${run}" ; UPDATE=no ; DOWN=no ; UP=no ; ADD_USERS=no ; CANCEL_USERS=no ; laravel_artisan_tool`, env);
  const what = tool('_none_');
  assert.strictEqual(what.status, 0, what.stdout + what.stderr);
  assert.match(what.stdout, /^dev\/site1: .* at http:\/\/127\.0\.0\.1:41234$/m);
  assert.doesNotMatch(what.stdout, /ddev\.site/);
  assert.strictEqual(tool('route:list --except-vendor').status, 0);
  const calls = fs.readFileSync(log, 'utf8');
  assert.match(calls, /^ddev exec php artisan about --only=environment$/m);
  assert.match(calls, /^ddev exec php artisan route:list --except-vendor$/m);
  assert.doesNotMatch(calls, /^ddev artisan /m);
});

test('the feature of the runtimes drives an app of the platform, and names no platform in a step', () => {
  const feature = fs.readFileSync(path.join(PKG, 'features', 'laravel-runtimes.feature'), 'utf8');
  const scenarios = feature.split(/\n(?=  @needs-runtime-)/).slice(1);
  assert.strictEqual(scenarios.length, 6);
  for (const s of scenarios) assert.match(s, /^  @needs-runtime-(docker|kubernetes) @needs-platform-laravel\n  Scenario: /);
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  for (const s of steps) assert.doesNotMatch(s, /laravel|livewire/i, s);
  assert.doesNotMatch(feature, /ddev\.site|127\.0\.0\.1/);
  const manifest = JSON.parse(fs.readFileSync(path.join(PKG, 'package.json'), 'utf8')).workspacePlugin;
  assert.ok(manifest.features.includes('features/laravel-runtimes.feature'));
  assert.match(manifest.featuresSite, /^cmd-laravel-project\.sh ci-laravel( [A-Za-z0-9._=-]+)* --runtime docker$/);
});
