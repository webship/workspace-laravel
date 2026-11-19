---
name: laravel-scenarios
description: Write and run webship-js scenarios for a Laravel app of the Webship Workspace with the Laravel step pack (`@webship-js/laravel-steps`) — the phrases of the pack by area (the session, the auth pages and the mail, the settings, the user menu and the navigation, the error pages and maintenance mode), the handles of the users registry, and the workspace command that runs them in the app's container. Use when asked to "write a scenario for this Laravel app", "test the password reset", "which step is there for the user menu", "add a feature for the settings pages", or when a `.feature` file of a Laravel project is being written or fixed.
argument-hint: '<app> [what to cover]'
---

# laravel-scenarios

Scenarios for a Laravel app of a Webship Workspace (`~/workspace`, container-based, DDEV by
default), written from the steps of [`@webship-js/laravel-steps`](https://github.com/webship/laravel-steps)
and of [webship-js](https://github.com/webship/webship-js) itself, and run in the app's container
by the workspace's own command. It comes with the Laravel plugin (`@webship.co/workspace-laravel`),
like the builder (`cmd-laravel-project.sh`), the Artisan tool (`cmd-tools-laravel-artisan.sh`) and
the agents `laravel-site-builder` and `laravel-tester`.

## Where everything is

| What | Where |
| --- | --- |
| The app | `~/workspace/<folder>/<app>`, at `https://<app>.ddev.site` (`<folder>` is a sites folder: `dev`, `test`, `sandboxes`, `demos`) |
| Its mail | the mail catcher of the project, `https://<app>.ddev.site:8026` |
| The suite's configuration | `<app>/cucumber.js`: the step definitions it loads, the users registry (`worldParameters.users`), the mailbox (`mailUrl`) |
| The features | `<app>/tests/features/*.feature` (`site.feature` is the first one the setup wrote) |
| The pack's steps | `<app>/node_modules/@webship-js/laravel-steps/tests/step-definitions/*.steps.js` |
| webship-js's steps | `<app>/node_modules/webship-js/tests/step-definitions/*.js` |
| The reports | `<app>/tests/reports/` |

## The order of work

1. **Make sure the testing stack is there.** From the sites folder:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <app>
   ```
   It adds webship-js, the step pack, the users registry, the mailbox and
   `tests/features/site.feature`, and makes sure the default accounts are on the app. It is safe
   to run again: it adds what is missing and keeps what was changed.
2. **Read the installed steps before writing a phrase.** They are the source of truth: the pack
   moves, and a phrase from memory is a guess.
   ```bash
   cd ~/workspace/<folder>/<app>
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/laravel-steps/tests/step-definitions/*.steps.js
   ```
   Every step carries a comment block with five examples above it; open the file when a phrase
   is not obvious.
3. **Look at the page first** (the Playwright MCP browser, a tab of your own) when the scenario
   is about a page you have not seen. The three starter kits draw the same pages with other
   markup and other words on a few buttons: look at the app you test.
4. **Write the feature** in `<app>/tests/features/`, from phrases that exist (the lists below).
5. **Match every step without a browser**, then run the feature, then the suite:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <app> --dry-run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <app> --run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <app> --run --tags "@critical"
   bash cmd-tools-testing.sh <app> --run
   ```
   A dry run says `Undefined` for a phrase no definition matches: fix the phrase, do not write a
   step for it.

## Accounts: a handle, never a password

A scenario logs in by a handle of the users registry. The default accounts are on the app already
(`bash cmd-tools-laravel-artisan.sh <app> --add-users` writes them again, with their name, password
and state):

| Handle | Account | What the app does with it |
| --- | --- | --- |
| `member` | `member@example.com` | Address verified: the dashboard and every settings page |
| `unverified` | `unverified@example.com` | Address not verified: the app keeps it on the verification notice |

```gherkin
Given I am a logged in user with the "member" user
Then I should be logged in as "member"
When I fill in "Current password" with the password of "member"
```

## The phrases, by area

Each line is a phrase the pack or webship-js defines, and each one passed on an app built with
`bash cmd-laravel-project.sh <app> --install --add-users`. Most `should` steps also take the
negative: `should not see`, `should not be`, `should not offer`.

### The session

```gherkin
Given I am an anonymous user
Given I am a logged in user with the "member" user
When I log in as "member" with the login form
When I log in as "unverified" with the login form and "Remember me" checked
When I log in with the email "member@example.com" and the password "wrong-password"
When I try to log in 6 times with the email "guess@example.com" and a wrong password
When I log out
Then I should be logged in
Then I should not be logged in
Then I should be logged in as "member"
Then I should see the login form
```

### The auth pages and the mail

```gherkin
When I ask for a password reset link for "member"
Then I should see the status message "We have emailed your password reset link."
Then an email with the subject "Reset your password" should be sent to "member"
Then the email with the subject "Reset your password" to "member" should contain "This password reset link will expire in 60 minutes."
When I open the "Reset Password" link of the email to "member"
When I click the "Reset password" button
Then no email should be sent to "nobody@example.com"
Then I should see the email verification notice
When I open the "Verify Email Address" link of the email to "unverified" with a changed signature
Then I should be asked to confirm my password
When I confirm my password as "member"
When I confirm my password with "wrong-password"
```

### Forms

```gherkin
When I fill in "Password" with the password of "member"
When I fill in "Name" with the name of "member"
Then the "Name" field should hold the name of "member"
Then the "Email address" field should have the error "These credentials do not match our records."
Then the "Password" field should have no error
Then the "Name" field should block submission as required
Then I should see the success notification "Profile updated."
Then I should not see a success notification
When I show the value of the "Password" field
Then the "Password" field should show its value
```

### The frame of the app

```gherkin
When I open "Settings" from the user menu
Then the user menu should name "member"
Then the user menu should offer "Log out"
Then the navigation should have the item "Dashboard"
Then the navigation should show "Dashboard" as the current page
When I choose the "Dark" appearance
Then the chosen appearance should be "Dark"
Then the page should be shown in the dark appearance
```

### The framework's own pages

```gherkin
Then I should see the 404 error page
Then the page should not show debug information
When a page of another site sends a form to "/login"
Then I should see the 419 error page
When I use the maintenance bypass
```

`I am an anonymous user`, `I should see "<text>"`, `I click the "<name>" button`, `I click "<text>"
in the modal` and `the response status code should be 200` are webship-js's own steps; its fields,
dialogs, cookies, status codes and accessibility audits are used as they are and never redefined
for this platform.

## Traps found on a real app

- **Five logins a minute.** The app allows five login attempts a minute for one address and counts
  every one, also those that succeed. `I am a logged in user with the "..." user` takes over the
  session of the first login of the run; log in through the form only where the form is the
  subject. The login steps wait out the limit once, as long as the app's `Retry-After` header says.
- **A button by its role.** On the React and Vue kits the home link of the auth pages carries the
  title of the page as hidden text ("Reset password"), and `I press "Reset password"` can take
  that link: press a submit button with `I click the "Reset password" button`.
- **Words differ between kits.** The password confirmation button reads "Confirm" on the Livewire
  kit and "Confirm password" on the others (`I confirm my password with "..."` presses either); the
  email field of the profile is labelled "Email" on one kit and "Email address" on the others (name
  it by its name attribute, "email", where a scenario must hold on every kit).
- **A password reset link must be used.** The app refuses a second request for the same address
  for a minute while a link is unused: a scenario that asks for one uses it in the same scenario.
- **The 419 page needs another site.** The app accepts a form of its own pages without a valid
  token as long as the browser says it comes from the same site; `a page of another site sends a
  form to "/login"` is what gets the "Page Expired" page.
- **The 500 page needs a page that fails.** A new app has none: the error page scenarios open
  addresses that exist on any app (a 404, a 419), and a 500 needs a route the app adds.
- **Production or not.** `--production` gives the app the error pages instead of the debug page
  and the stricter password rules (at least 12 characters, both cases, a number, a symbol). A
  scenario about either needs an app built with it.

## Rules

- **No account is created in a suite.** No account made in a hook, no registration that goes
  through: registration is tested through its refusals only, with an address that is already
  taken. An account the registry does not have is asked for, not made.
- **Never the workspace account.** The app's first account is not in the registry.
- **No password in a feature file**, except where a wrong password is the subject.
- **No platform name in a step phrase**: `I should see the 404 error page`, never a phrase that
  names the framework or a library. The same holds for a custom step.
- **What a scenario changes, it changes back** in the same scenario: a name, the appearance; a
  password form is given the password the account has.
- **A custom step is the last resort**: look in the pack and in webship-js first, write it in
  `<app>/tests/step-definitions/` with a comment block and examples, and say it may belong in
  the pack.
- **Everything runs in the container**, through `cmd-tools-testing.sh`. Never `npx cucumber-js`
  or `npx playwright` on the host.
- **A failing scenario is a result.** No `@wip`, no longer timeout, no looser assertion to turn a
  run green: say what the app did.

## Examples that run

`examples/` holds three features that pass on an app built with
`bash cmd-laravel-project.sh <app> --install --add-users`. Copy one into the suite and run it:

```bash
cp ~/workspace/ai-skills/laravel-scenarios/examples/session.feature ~/workspace/<folder>/<app>/tests/features/
cd ~/workspace/<folder>
bash cmd-tools-testing.sh <app> --run --path tests/features/session.feature
```

| Feature | What it shows |
| --- | --- |
| `examples/session.feature` | Logging in with the form, a refused password with the error under the field, logging out, a page that needs a session |
| `examples/settings.feature` | A member changes the name of the account and puts it back, chooses the dark appearance and the system's again, and is refused the deletion of the account with a wrong password |
| `examples/framework-pages.feature` | The 404 page with no debug information, a form of another site refused with the 419 page, the health route |

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For Laravel.** Start with `ch10-authentication-authorization.md` (logins, sessions, password
  reset and protected pages), `ch06-form-testing-recipes.md` (forms, validation and their
  messages), `ch33-complete-step-definition-reference.md` (every built-in step) and
  `ch21-when-tests-go-bad.md` (flaky, brittle and slow scenarios).
