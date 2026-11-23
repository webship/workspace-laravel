# @webship.co/workspace-laravel

Laravel for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that
makes a real Laravel app in a container with the official installer and an official starter kit
(Livewire, React or Vue), an Artisan tool for the apps it built, the default accounts, the
[Laravel step pack](https://github.com/webship/laravel-steps) wired into the workspace's testing
setup, and its AI items — two agents, a skill, a command and two prompts — each listed in the
workspace folder of its kind.

The workspace is container-based (DDEV by default): a Laravel project is a row like any other, so
the row menus the core draws (start, stop, launch, backup, clone, remove, tests) work on it
unchanged.

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-laravel --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate laravel --with-needs                         # plugins.laravel in settings.yml
bash core/scripts/plugins.sh --install laravel                                       # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure laravel                                     # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an AI item you edited stays.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active
workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-laravel-project.sh`, `cmd-tools-laravel-artisan.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `laravel-site-builder`, `laravel-tester` | `ai-agents/` |
| The skill `laravel-scenarios` | `ai-skills/` |
| The command `/laravel-test` | `ai-commands/` |
| The prompts `laravel-build-and-test`, `laravel-scenarios-for-an-account` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate laravel --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install laravel
```

Everything the builder runs for an app runs in the app's own container, through the container tool the workspace already needs: the official installer is added to the web container for the time of the build only. The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-laravel-project.sh` | The builder, in the Build list as **Laravel (starter kit)**, installed into every sites folder |
| `commands/cmd-tools-laravel-artisan.sh` | Artisan for one app: what the app is, a command, updates, maintenance mode, the default accounts |
| `scripts/functions/fun-laravel.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_laravel_users`, `add_laravel_users`, `cancel_laravel_users`, `testing_configure_laravel`) |
| `scripts/args/arg-laravel.sh`, `arg-laravel-artisan.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `testing/site.feature` | The first feature a Laravel project gets when testing is set up |
| `ai/agents/laravel-site-builder.md` | The agent that builds and maintains Laravel apps with these commands |
| `ai/agents/laravel-tester.md` | The agent that writes and runs scenarios with the Laravel step pack |
| `ai/skills/laravel-scenarios/` | The skill: the step pack's phrases by area, the traps found on a real app, three example features |
| `ai/commands/laravel-test.md` | The slash command `/laravel-test <app>`: set up, match every step, run, report |
| `ai/prompts/laravel-build-and-test.md`, `laravel-scenarios-for-an-account.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Laravel here |
| `features/laravel.feature` | Scenarios for the dashboard's own browser suite |
| `features/laravel-runtimes.feature` | The row, the test users and the pages of an app built on Docker Compose and on Kubernetes |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build an app

```bash
cd ~/workspace/dev
bash cmd-laravel-project.sh myapp --install --add-users
```

| Flag | What it does |
| --- | --- |
| `--starter-kit <kit>` | The official starter kit: `livewire` (the default), `react` or `vue` |
| `--install` | Migrate the database, with the workspace account as the first account of the app |
| `--add-users` | With `--install`: add the default accounts |
| `--production` | Run the app as a live app runs: `APP_ENV=production`, `APP_DEBUG=false` (error pages instead of the debug page, the stricter password rules) |
| `--php-version <x>` | The PHP of the project container |
| `--runtime <name>` | The container runtime to build on: `ddev` (the default), `docker`, `kubernetes`, `podman`, `lando` or `docksal`. See [Runtimes](#runtimes) |
| `--launch` | Open the app when it is ready |

On DDEV the app answers at `https://myapp.ddev.site`, the login at `/login`, its mail catcher at
`https://myapp.ddev.site:8026`. The build runs `ddev config --project-type=laravel` with the
Node.js of the workspace (24), makes the app with the official installer in the web container
(`laravel new --livewire`, `--react` or `--vue`), the way the DDEV quickstart for Laravel does, and
leaves the database settings to the container tool (it writes them into `.env`): it writes none.
A project of the same name is deleted first.


### Runtimes

```bash
bash cmd-laravel-project.sh myapp --install --add-users                        # DDEV, the default
bash cmd-laravel-project.sh myapp --install --add-users --runtime docker       # Docker Compose
bash cmd-laravel-project.sh myapp --install --add-users --runtime kubernetes   # a Kubernetes cluster
bash cmd-laravel-project.sh myapp --install --add-users --runtime lando        # Lando
bash cmd-laravel-project.sh myapp --install --add-users --runtime docksal      # Docksal
```

Without `--runtime` a build takes `container.runtime` of the workspace's `settings.yml`, then DDEV.
It needs a Webship Workspace with the container runtimes
([webship/workspace#694](https://github.com/webship/workspace/issues/694)); on an older one the
builder refuses `--runtime` and builds on DDEV only. Lando and Docksal need a Workspace whose runtime
layer has them ([webship/workspace#729](https://github.com/webship/workspace/issues/729),
[#730](https://github.com/webship/workspace/issues/730)).

| | DDEV | Docker Compose | Kubernetes | Podman | Lando | Docksal |
| --- | --- | --- | --- | --- | --- | --- |
| Build with `--install --add-users --production` | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The pages, and a login as the workspace account and the default accounts | Yes | Yes | Yes | Not yet run | Yes | Yes |
| `cmd-tools-laravel-artisan.sh`: status, `--run`, the accounts | Yes | Yes | Yes | Not yet run | Yes | Yes |
| Test users, added and cancelled | Yes | Yes | Yes | Not yet run | Yes | Yes |
| Mail caught by Mailpit (a password reset) | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The testing setup and the first feature | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The step pack's examples (48 scenarios) | Yes | Yes | Yes | Not yet run | Yes | Yes |
| Export and import the database | Yes | Yes | Yes | Not yet run | Yes | Yes |
| The row in the dashboard, and remove | Yes | Yes | Yes | Not yet run | Yes | Yes |

"Yes" means it was run on a real app of that runtime. Podman runs the same code as Docker Compose
and was not run yet.

| Runtime | The app's address | What the project carries |
| --- | --- | --- |
| DDEV | `https://myapp.ddev.site` | `.ddev/config.yaml` |
| Docker Compose | `http://127.0.0.1:<port>`, printed by the build | `compose.yaml`, `.webship/runtime/Dockerfile` |
| Kubernetes | `http://<node address>:<port>`, printed by the build | The same, and `k8s/` (the namespace `ws-myapp`) |
| Lando | `http://127.0.0.1:<port>`, printed by the build | `.lando.yml` (Lando's proxy stays off) |
| Docksal | `http://myapp.docksal.site`, on Docksal's own proxy | `.docksal/docksal.env`, `.docksal/docksal.yml` |

What differs on Docker Compose, Kubernetes, Lando and Docksal:

- **`.env`** is written by the builder, as DDEV writes it on start: the address (`APP_URL`), the database of the project's own stack (`DB_CONNECTION=mariadb`, `db`/`db`/`db` on the host `db`) and its mail catcher (`MAIL_HOST=mail`, `mailpit` on Lando, port 1025). Nothing personal. On DDEV the builder still writes none.
- **The official installer** runs from Composer's own folder of the web container, without the front end (`LARAVEL_INSTALLER_NO_NODE`): the web container there has no Node.js. `npm install` and `npm run build` run in the Workspace's tests container, as `laravel new --npm` runs them on DDEV.
- **Artisan** runs as `php artisan` in the web container (`ddev exec`), and `.env` keys are set by the plugin (`laravel_dotenv_set`): DDEV's `ddev artisan` and `ddev dotenv` are DDEV's own. The tool, the test users and the testing hook use them on every runtime.
- **On Kubernetes** a site's mail needs the Workspace's webship/workspace#748 (the cluster's service links set `MAIL_PORT` in the pod, which Laravel reads before `.env`).
- **HTTPS and a host name** are DDEV's: a runtime's address is plain HTTP.

The same commands work on every runtime: `cmd-tools-laravel-artisan.sh`, `cmd-tools-add-users.sh`,
`cmd-tools-testing.sh`. The pattern is the Workspace's
[`core/docs/plugins-on-runtimes.md`](https://github.com/webship/workspace/blob/1.0.x/core/docs/plugins-on-runtimes.md).

### Work on an app

```bash
bash cmd-tools-laravel-artisan.sh myapp                                   # version, environment, accounts
bash cmd-tools-laravel-artisan.sh myapp --run "migrate:status"
bash cmd-tools-laravel-artisan.sh myapp --update                          # Composer and npm packages, migrations, assets
bash cmd-tools-laravel-artisan.sh myapp --down --secret preview-2026      # maintenance mode, with a way past it
bash cmd-tools-laravel-artisan.sh myapp --up                              # live again
bash cmd-tools-laravel-artisan.sh myapp --add-users                       # the default accounts
bash cmd-tools-laravel-artisan.sh myapp --cancel-users                    # delete them
```

### The default accounts

| Account | Address | State | Handle in the tests |
| --- | --- | --- | --- |
| `member` | `member@example.com` | address verified | `member` |
| `unverified` | `unverified@example.com` | address not verified | `unverified` |

The starter kits have no roles: what tells two accounts apart is whether the address is verified,
and the app keeps an unverified account on its verification notice. Each account has the password
of the workspace's other default lists. They are for local apps and for tests; the app's first
account is the workspace account and is never written into a test. The row's Users menu (**Add the
test users**) and `bash cmd-tools-add-users.sh myapp laravel` add the same list; adding them again
gives them back their name, password and state.

### Test an app

```bash
bash cmd-tools-testing.sh myapp                 # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh myapp --run           # run the suite in the container
bash cmd-tools-testing.sh myapp --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a Laravel project it also adds
`@webship-js/laravel-steps` to `package.json`, lists its step definitions in `cucumber.js` after
webship-js's own, writes the users registry (the handles above, overridable with
`LARAVEL_<HANDLE>_EMAIL` and `LARAVEL_<HANDLE>_PASSWORD`), the mailbox of the project (`mailUrl`)
and the tags that keep the pack's two lanes (`@maintenance`, `@debug-page`) out of a normal run,
places `tests/features/site.feature` when the project has none, and makes sure the default accounts
are on the app. The app's `package.json` says `"type": "module"`, so node reads its `.js` files as ES
modules: the setup turns `cucumber.js` into an ES module that exports the same profile, and gives
`tests/` a `package.json` of its own that keeps the step definitions there CommonJS. Run it again
and it adds what is missing and keeps what you changed.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and
`--install` places it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `laravel-site-builder` | Build, update, maintain or remove a Laravel app with the commands above, in containers only |
| Agent | `laravel-tester` | Set the testing stack up, look at the app in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `laravel-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the traps found on a real app, and three features that pass on a fresh app |
| Command | `/laravel-test <app> [feature or @tag]` | Run the suite of an app from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `laravel-build-and-test` | Start a session that builds an app, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `laravel-scenarios-for-an-account` | Start a session that writes and runs the scenarios of one account |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill
or a command into Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or
from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh laravel-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh laravel-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh laravel-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the
dashboard's **New screen** form lists it as a template. By hand, fill the placeholders in and run
the command of the file from the folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and
the file layout are Claude Code's, the body of each item is plain Markdown that names no tool or
feature of one CLI, a command says in words what its arguments are, and the text between the
triple quotes of a prompt can be given to another AI CLI as it is.

Every step phrase the items show is checked against the definitions of the step pack and of
webship-js (`tests/fixtures/step-definitions.txt`), and every command and flag against the
plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 24 and 26, parses every shell script, and runs the plugin's
`features/laravel.feature` against a dashboard with this plugin installed
(`webship/workspace/.github/workflows/plugin-browser-suite.yml`).
