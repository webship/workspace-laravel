#!/usr/bin/env bash

# Installed by the Laravel plugin (plugins.sh --install laravel); __WORKSPACE__ is the workspace it was installed into.
#
# Artisan for one Laravel app of this workspace, in its container: say what the app is, run an
# Artisan command, update its packages, put it down for maintenance and up again, add or remove
# the default accounts. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="laravel";

ARGPARSE_DESCRIPTION="Run Artisan on a Laravel app of __WORKSPACE__: status, a command, updates, maintenance mode, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/laravel/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/laravel/args/arg-laravel-artisan.sh || exit 1 ;

shift $#;

laravel_artisan_tool ;
