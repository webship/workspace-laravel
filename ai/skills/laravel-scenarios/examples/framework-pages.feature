@js-off
Feature: The framework's own pages
  As the owner of the app
  I want an error to answer with a plain error page, and the health route to answer
  So that visitors understand what happened and a monitor knows the app is up

  # The browser logs every error page as a resource that failed to load: the feature carries @js-off.

  Scenario: An address the app does not have answers with the 404 page
    Given I am an anonymous user
    When I go to "/no-such-page-of-the-app"
    Then I should see the 404 error page
    And the page should not show debug information

  Scenario: A form sent from another site is refused with the expired page
    Given I am an anonymous user
    When a page of another site sends a form to "/login"
    Then I should see the 419 error page
    And I should not be logged in

  Scenario: The health route answers that the app is up
    Given I am an anonymous user
    When I go to "/up"
    Then the response status code should be 200
    And I should see "Application up"
