Feature: A member's own settings
  As a member
  I want to change my name and the look of the app, and to be asked for my password before my account goes
  So that the app is mine and stays mine

  # Every change is changed back in the same scenario; the account is never deleted.

  Scenario: A new name is saved, and the name of the account is put back
    Given I am a logged in user with the "member" user
    When I go to "/settings/profile"
    And I fill in "Name" with "A name a scenario wrote"
    And I click the "Save" button
    Then I should see the success notification "Profile updated."
    When I fill in "Name" with the name of "member"
    And I click the "Save" button
    Then I should see the success notification "Profile updated."
    When I reload the page
    Then the "Name" field should hold the name of "member"

  Scenario: The dark appearance is chosen, and the system's again
    Given I am a logged in user with the "member" user
    When I go to "/settings/appearance"
    And I choose the "Dark" appearance
    Then the chosen appearance should be "Dark"
    And the page should be shown in the dark appearance
    When I choose the "System" appearance
    Then the chosen appearance should be "System"

  Scenario: Deleting the account asks for the password and refuses a wrong one
    Given I am a logged in user with the "member" user
    When I go to "/settings/profile"
    And I press "Delete account"
    Then I should see "Are you sure you want to delete your account?" in the modal
    When I fill in "Password" with "wrong-password"
    And I click "Delete account" in the modal
    Then the "Password" field should have the error "The password is incorrect."
    When I click "Cancel" in the modal
    Then I should not see a modal
