/**
 * Laravel for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the
 * Artisan tool in the sites folders, their functions and argparse under core/scripts/plugins/laravel/,
 * and its AI items (ai/ in this package) in the folder of their kind: the agents in AI Agents, the skill
 * in AI Skills, the command in AI Commands, the prompts in AI Prompts. The dashboard needs nothing drawn
 * for it: the builder is in the Build list because it is a cmd-*-project.sh, the row menus are the
 * core's, the AI items are listed like any other. What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name, which is also the DDEV project type its functions are named after. */
export const PLATFORM = 'laravel';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-laravel-project.sh', 'cmd-tools-laravel-artisan.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['laravel-site-builder', 'laravel-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['laravel-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['laravel-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['laravel-build-and-test', 'laravel-scenarios-for-an-account'];

/** What the assistant is told about Laravel in this workspace. */
export function assistantContext(): string {
  return [
    'Laravel (a plugin, @webship.co/workspace-laravel): a Laravel app is built with',
    '`bash cmd-laravel-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos),',
    'with the official installer and an official starter kit (`--starter-kit livewire|react|vue`, Livewire by default),',
    'in a container like every other project: on DDEV by default, at https://<name>.ddev.site, or with `--runtime docker|podman|kubernetes|lando|docksal`',
    'on that runtime, at the address the build prints (never write a ddev.site address for such an app); `--production` runs it as a live app runs.',
    '`bash cmd-tools-laravel-artisan.sh <name>` says what the app is; `--run "<artisan command>"` runs Artisan in it,',
    '`--update` updates its packages, `--down --secret <s>` and `--up` put it in and out of maintenance mode,',
    '`--add-users` adds the default accounts (member, verified; unverified).',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Laravel step pack; `--run` runs the suite.',
    `For Laravel work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <app>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run php, composer, npm or artisan on the host for a project; never write database settings into its .env by hand.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
