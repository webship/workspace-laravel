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
| `--launch` | Open the app when it is ready |

The app answers at `https://myapp.ddev.site`, the login at `/login`, its mail catcher at
`https://myapp.ddev.site:8026`. The build runs `ddev config --project-type=laravel` with the
Node.js of the workspace (24), makes the app with the official installer in the web container
(`laravel new --livewire`, `--react` or `--vue`), the way the DDEV quickstart for Laravel does, and
leaves the database settings to the container tool (it writes them into `.env`): it writes none.
A project of the same name is deleted first.

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

CI runs the same on Node.js 20 and 24, parses every shell script, and runs the plugin's
`features/laravel.feature` against a dashboard with this plugin installed
(`webship/workspace/.github/workflows/plugin-browser-suite.yml`).
