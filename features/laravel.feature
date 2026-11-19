Feature: The Laravel plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Laravel builder, each
  AI folder lists the items of its kind the plugin ships, and the Plugins page lists the plugin
  with its steps.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package and what it ships
    Given I am on "/settings"
     Then I should see "Laravel"
     When I go to "/settings/plugin/laravel"
     Then I should see "@webship.co/workspace-laravel"
      And I should see "cmd-laravel-project.sh"
      And I should see "laravel-site-builder"

  Scenario: A sites folder offers the Laravel builder
    Given I am on "/dev"
     Then "option[value='cmd-laravel-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=laravel-"
     Then I should see "laravel-site-builder"
      And I should see "laravel-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=laravel-scenarios"
     Then I should see "laravel-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=laravel-test"
     Then I should see "laravel-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=laravel-"
     Then I should see "laravel-build-and-test"
      And I should see "laravel-scenarios-for-an-account"
