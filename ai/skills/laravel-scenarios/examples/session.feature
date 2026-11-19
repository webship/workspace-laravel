Feature: Logging in and out
  As a member of the app
  I want to log in with my address and my password, and to log out again
  So that only I reach my dashboard

  Scenario: A member logs in with the login form and lands on the dashboard
    Given I am an anonymous user
    When I log in as "member" with the login form
    Then I should be on "/dashboard"
    And I should be logged in as "member"

  Scenario: A wrong password is refused with an error under the address
    Given I am an anonymous user
    And I am on "/login"
    When I fill in "Email address" with "unverified@example.com"
    And I fill in "Password" with "wrong-password"
    And I click the "Log in" button
    Then the "Email address" field should have the error "These credentials do not match our records."
    And I should not be logged in

  Scenario: Logging out ends the session
    Given I am an anonymous user
    When I log in as "member" with the login form
    And I log out
    Then I should be on the homepage
    And I should not be logged in

  Scenario: A page that needs a session sends a visitor to the login form
    Given I am an anonymous user
    When I go to "/settings/profile"
    Then I should see the login form
