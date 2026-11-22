#!/usr/bin/env bash

# workspace-name: Laravel (starter kit)

# Installed by the Laravel plugin (plugins.sh --install laravel); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Laravel app in a container with the official installer and an official starter kit
# (Livewire by default, React or Vue with --starter-kit): on DDEV (the default) at
# https://<name>.ddev.site, and with --runtime docker, podman, kubernetes, lando or docksal on that
# runtime, at the address the build prints. With --install
# its database is migrated and the workspace account is its first account; with --add-users it also
# gets the default accounts.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Set the starter kit.
site_starter_kit="livewire";

# Distribution.
distribution_name="laravel";
distribution_title="Laravel";
distribution_webroot="public";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} app in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/laravel/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/laravel/args/arg-laravel.sh || exit 1 ;

shift $#;

laravel_build ;
