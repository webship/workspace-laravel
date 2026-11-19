#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-k', '--starter-kit',
                    default="${site_starter_kit}",
                    choices=['livewire', 'react', 'vue'],
                    help='The official starter kit the app is made from. Example: --starter-kit react [default %(default)s]')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Migrate the database, with the workspace account as the first account of the app.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts: the ones the test scenarios log in as.')
parser.add_argument('-p', '--production',
                    action='store_true',
                    default=False,
                    help='Run the app as a live app runs: APP_ENV=production and APP_DEBUG=false (error pages instead of the debug page, the stricter password rules).')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the app in a browser when it is ready.')
parser.add_argument('--php-version',
                    default="",
                    choices=['8.5', '8.4', '8.3'],
                    help='PHP version for the project container; empty means the default of the container tool. Example: --php-version 8.4')
ARGEOF
