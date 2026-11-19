#!/usr/bin/env bash

# Laravel for the Webship Workspace: build an app from an official starter kit, run Artisan on it,
# add its default accounts, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install laravel` in core/scripts/plugins/laravel/functions/, where
# bootstrap sources it after the core's own functions. Everything runs in the project's container
# (DDEV by default: `ddev artisan …`, `ddev composer …`, `ddev npm …`), never on the host. The
# container tool writes the database settings of the app into its .env, so nothing here writes any.
#
# Four names are the ones the core's tools look for, under the DDEV project type `laravel`:
#   set_laravel_users        the default accounts          (cmd-tools-add-users.sh <project> laravel)
#   add_laravel_users        create them through the app   (the same tool, and --add-users of the builder)
#   cancel_laravel_users     delete them                   (cmd-tools-cancel-users.sh <project> laravel)
#   testing_configure_laravel  the step pack in the testing stack (cmd-tools-testing.sh <project>)

# The step pack a Laravel app is tested with, and the release line it is required at.
readonly LARAVEL_STEPS_PACKAGE='@webship-js/laravel-steps';
readonly LARAVEL_STEPS_VERSION='^2.0.0';

# The default accounts, the ones a scenario logs in as. The starter kits have no roles: what tells
# two accounts apart is whether the address is verified, so that is the "role" here. Accounts are
# configuration, created once on the app; a test suite never creates or deletes one.
#   member      a verified account: the dashboard and every settings page
#   unverified  an account whose address is not verified: the app keeps it on the verification notice
function set_laravel_users() {
  users=(member unverified);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
  done
  user_member_role='verified' ;
  user_unverified_role='unverified' ;
}

# Is this folder a Laravel project? Its DDEV project type says so.
function laravel_is_project() {
  local project_path="$1";
  grep -qE '^type:[[:space:]]*"?laravel"?[[:space:]]*$' "${project_path}/.ddev/config.yaml" 2>/dev/null ;
}

# Go to the project a tool was asked about, or say why not.
function laravel_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! laravel_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Laravel project (its .ddev/config.yaml does not say type: laravel)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# Write accounts through the app itself, so a password is hashed the way the app hashes it and the
# model is the app's own (config auth.providers.users.model). Reads lines of
# "name|email|password|verified" on standard input; "delete" as the first argument removes the
# accounts of those addresses instead, and "list" lists every account of the app. Runs in the
# project folder, in the container.
function laravel_write_accounts() {
  local action="${1:-save}" script=".webship-accounts-$$.php" list=".webship-accounts-$$.txt" ;
  cat > "${list}" ;
  cat > "${script}" <<'PHPEOF'
<?php
require __DIR__.'/vendor/autoload.php';
$app = require __DIR__.'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
$model = config('auth.providers.users.model');
[$self, $action, $file] = $argv;
if ($action === 'list') {
    foreach ($model::query()->orderBy('id')->get() as $user) {
        printf("  %s <%s>%s\n", $user->name, $user->email, $user->email_verified_at ? '' : ' (address not verified)');
    }
    exit(0);
}
foreach (file($file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
    [$name, $email, $password, $verified] = array_pad(explode('|', $line), 4, '');
    if ($action === 'delete') {
        $deleted = $model::query()->where('email', $email)->delete();
        printf("  %s %s\n", $email, $deleted ? 'deleted' : 'is not there');
        continue;
    }
    $user = $model::query()->firstOrNew(['email' => $email]);
    $user->name = $name;
    $user->password = $password;
    $user->email_verified_at = $verified === 'verified' ? now() : null;
    $user->save();
    printf("  %s <%s>%s\n", $user->name, $user->email, $user->email_verified_at ? '' : ' (address not verified)');
}
PHPEOF
  ddev exec php "${script}" "${action}" "${list}" ;
  local rc=$? ;
  rm -f "${script}" "${list}" ;
  return ${rc} ;
}

# Build a Laravel app from nothing: the container, the app made by the official installer with an
# official starter kit, and with --install its database and its first account.
function laravel_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local kit="${STARTER_KIT:-${site_starter_kit:-livewire}}" ;
  local php_version="${PHP_VERSION:-${site_php_version:-}}" ;

  case "${kit}" in
    livewire|react|vue) ;;
    *) echo "--starter-kit must be livewire, react or vue, not \"${kit}\"." ; exit 1 ;;
  esac

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;

  ddev config --project-type=laravel --docroot="${distribution_webroot}" --project-name=${PROJECT_NAME} \
    --nodejs-version=$(ddev_nodejs_version) ${php_version:+--php-version=${php_version}} --auto || exit 1 ;

  # The official installer, in the web container for the time of the build only (the DDEV quickstart
  # for Laravel does the same).
  mkdir -p .ddev/web-build ;
  cat > .ddev/web-build/Dockerfile.laravel-installer <<'DOCKERFILEEND'
ARG COMPOSER_HOME=/usr/local/composer
RUN composer global require laravel/installer
RUN ln -s $COMPOSER_HOME/vendor/bin/laravel /usr/local/bin/laravel
DOCKERFILEEND
  ddev_up start -y || exit 1 ;

  ddev exec laravel new temp --${kit} --database=sqlite --pest --npm --no-boost --no-interaction \
    || { echo "laravel new failed." ; exit 1 ; } ;
  ddev exec 'rsync -rltgopD temp/ ./ && rm -rf temp' || exit 1 ;
  rm -f .ddev/web-build/Dockerfile.laravel-installer .env ;
  # The restart writes the database settings of the container into .env.
  ddev_up restart || exit 1 ;
  ddev composer run-script post-root-package-install || exit 1 ;

  if [ "${INSTALL}" == 'yes' ] ; then
    # The application key and the migrations (the starter kit's own script).
    ddev composer run-script post-create-project-cmd || { echo "The migrations failed." ; exit 1 ; } ;
    printf '%s|%s|%s|verified\n' "${account_name}" "${account_mail}" "${account_pass}" | laravel_write_accounts save > /dev/null \
      || { echo "The workspace account could not be written." ; exit 1 ; } ;

    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_laravel_users ;
      add_laravel_users ;
      cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;
    fi

    if [ "${PRODUCTION}" == 'yes' ] ; then
      ddev dotenv set .env --app-env=production --app-debug=false > /dev/null ;
    fi

    echo "${doc_name} ${PROJECT_NAME} has been installed: $(ddev artisan --version 2>/dev/null) with the ${kit} starter kit.";
    echo "Go to ${base_url}/login and log in as ${account_mail}";
  else
    ddev artisan key:generate --ansi > /dev/null ;
    [ "${ADD_USERS}" == 'yes' ] && echo "--add-users needs --install: there is no database to add accounts to yet." ;
    echo "${doc_name} ${PROJECT_NAME} is ready: migrate its database with bash cmd-tools-laravel-artisan.sh ${PROJECT_NAME} --run \"migrate\"";
    echo "Go to ${base_url}";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts through the app. An account that is already there gets its name,
# password and state back. The list is loaded by the caller (set_laravel_users): the core's
# add_users, the builder, the Artisan tool.
function add_laravel_users() {
  laravel_enter_project || return 1 ;
  local user user_name user_mail user_password user_role lines="" ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "     User state: ${!user_role:-verified}";
    echo " ================================================================= ";

    lines="${lines}${!user_name}|${!user_mail}|${!user_password}|${!user_role:-verified}"$'\n' ;
  done
  printf '%s' "${lines}" | laravel_write_accounts save ;
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Delete the default accounts.
function cancel_laravel_users() {
  laravel_enter_project || return 1 ;
  local user user_name user_mail lines="" ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
    lines="${lines}${!user_name}|${!user_mail}||"$'\n' ;
  done
  printf '%s' "${lines}" | laravel_write_accounts delete ;
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# What cmd-tools-laravel-artisan.sh does: the first of --run, --update, --down, --up, --add-users,
# --cancel-users that was asked for; with none of them, what the app is.
function laravel_artisan_tool() {
  trim_project_name ;
  laravel_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y || exit 1 ;
  fi

  if [ ! "${RUN}" == '_none_' ] ; then
    # Unquoted on purpose: --run "route:list --except-vendor" is a command and its arguments.
    ddev artisan ${RUN} ;
    exit $? ;
  fi

  if [ "${UPDATE}" == 'yes' ] ; then
    ddev composer update --no-interaction ;
    ddev artisan migrate --force ;
    ddev npm install ;
    ddev npm run build ;
  elif [ "${DOWN}" == 'yes' ] ; then
    ddev artisan down ${SECRET:+--secret="${SECRET}"} ;
  elif [ "${UP}" == 'yes' ] ; then
    ddev artisan up ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_laravel_users ;
    add_laravel_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_laravel_users ;
    cancel_laravel_users ;
  else
    echo "${doc_name}/${PROJECT_NAME}: $(ddev artisan --version 2>/dev/null) at https://${PROJECT_NAME}.ddev.site" ;
    echo "" ; ddev artisan about --only=environment ;
    echo "" ; echo "Accounts:" ;
    printf '' | laravel_write_accounts list ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Laravel project. The core's testing_configure calls this
# in the project folder once webship-js is scaffolded and before the dependencies are installed;
# for a project that is not Laravel it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's
# own, gives cucumber.js the users registry of the default accounts (a handle a scenario reads,
# mapped to an account; never the workspace account), the mailbox of the project and the tags that
# keep the pack's lanes out of a normal run, and writes a first feature when the project has none of
# its own. Every part is skipped when it is already there, so a second run adds what the first
# missed and never resets a suite.
function testing_configure_laravel() {
  local project_path="$1";
  laravel_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Laravel: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Laravel step pack (${LARAVEL_STEPS_PACKAGE} ${LARAVEL_STEPS_VERSION}).";
  set_laravel_users ;
  local registry="" user user_name user_mail user_password ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password";
    registry="${registry}${user}|${!user_mail}|${!user_password}|${!user_name}"$'\n' ;
  done

  python3 - "${project_path}" "${LARAVEL_STEPS_PACKAGE}" "${LARAVEL_STEPS_VERSION}" 'LARAVEL' "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry = sys.argv[1:6]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

# cucumber.js: the pack's step definitions after webship-js's own, the users registry, the mailbox
# and the tags of the pack's lanes.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's lanes need the app in another state (@maintenance: down; @debug-page: APP_DEBUG=true),",
            pad + "// and its assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail and not @maintenance and not @debug-page',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the lanes of the pack out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
if not re.search(r"^[ \t]*mailUrl:", src, re.M):
    additions += [
        pad + "// The mailbox that catches the mail of the app (the password reset and verification steps read it).",
        pad + "mailUrl: process.env.MAIL_URL || (process.env.LAUNCH_URL || '').replace(/\\/+$/, '') + ':8026',",
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of this app (the default",
        pad + "// accounts: cmd-tools-add-users.sh). Override one with %s_<HANDLE>_EMAIL and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, email, password, name in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { email: process.env.%s_EMAIL || '%s', password: process.env.%s_PASSWORD || '%s', name: '%s' }," % (handle, env, email, env, password, name))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]

# An app's package.json says "type": "module" (Vite's convention), so node reads every .js file of
# the app as an ES module: the CommonJS cucumber.js the scaffold writes cannot load there, and
# neither can the step definitions under tests/. cucumber.js becomes an ES module that exports the
# same default profile, and tests/ gets a package.json of its own that keeps its .js files CommonJS.
if pkg.get('type') == 'module':
    if re.search(r"^module\.exports\s*=\s*\{", src, re.M) and not re.search(r"^export default ", src, re.M):
        src = re.sub(r"^module\.exports\s*=\s*\{", "// The app's package.json says \"type\": \"module\": this file is an ES module, the profiles stay as they were.\nconst config = {", src, count=1, flags=re.M)
        src = src.rstrip() + '\n\nexport default config.default;\n'
        print('  cucumber.js: an ES module (the package.json of the app says "type": "module")')
    tests_pkg = project + '/tests/package.json'
    try:
        open(tests_pkg)
    except OSError:
        import os
        os.makedirs(project + '/tests', exist_ok=True)
        open(tests_pkg, 'w').write(json.dumps({'type': 'commonjs'}, indent=2) + '\n')
        print('  tests/package.json: the step definitions under tests/ stay CommonJS')

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the app yet: the home page, the login page, each
  # default account where the app sends it.
  local feature="${WORKSPACE_SCRIPTS}/plugins/laravel/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the app" ;
  fi

  # The scenarios log in as the default accounts: make sure a migrated app has them.
  if ddev artisan migrate:status > /dev/null 2>&1 ; then
    ( add_laravel_users > /dev/null ) && echo "  the default accounts are on the app (${users[*]})" ;
  fi
}
