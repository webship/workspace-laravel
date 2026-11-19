#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The Laravel app in this workspace.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='An Artisan command to run in the app, without the leading artisan. Example: --run "route:list --except-vendor"')
parser.add_argument('-u', '--update',
                    action='store_true',
                    default=False,
                    help='Update the Composer and npm packages within their constraints, migrate the database and build the assets again.')
parser.add_argument('-d', '--down',
                    action='store_true',
                    default=False,
                    help='Put the app into maintenance mode. With --secret, that address lets a browser past the maintenance page.')
parser.add_argument('-s', '--secret',
                    default="",
                    help='With --down: the secret that lets a browser past the maintenance page (https://<name>.ddev.site/<secret>). Example: --secret preview-2026')
parser.add_argument('-U', '--up',
                    action='store_true',
                    default=False,
                    help='Bring the app out of maintenance mode.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts. An account that is already there gets its name, password and state back.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts.')
ARGEOF
