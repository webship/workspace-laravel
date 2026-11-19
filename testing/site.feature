Feature: The app answers and its accounts work
  As the owner of the app
  I want the home page, the login page and each default account to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-add-users.sh); a scenario logs in by a handle of
  # the users registry in cucumber.js, so no password is written here.

  @critical
  Scenario: The home page is served
    Given I am an anonymous user
    And I am on the homepage
    Then the response status code should be 200
    And the "Log in" link should be visible

  @critical
  Scenario: The login page is served with its form
    Given I am an anonymous user
    When I go to "/login"
    Then the response status code should be 200
    And I should see the login form

  Scenario: The verified account logs in and lands on the dashboard
    Given I am a logged in user with the "member" user
    Then I should be on "/dashboard"
    And I should be logged in as "member"
    And the navigation should show "Dashboard" as the current page

  Scenario: The account whose address is not verified is kept on the verification notice
    Given I am a logged in user with the "unverified" user
    Then I should see the email verification notice
    And I should be logged in as "unverified"

  Scenario: A page that needs a session sends a visitor to the login form
    Given I am an anonymous user
    When I go to "/dashboard"
    Then I should see the login form

  Scenario: The health route answers that the app is up
    Given I am an anonymous user
    When I go to "/up"
    Then the response status code should be 200
    And I should see "Application up"
