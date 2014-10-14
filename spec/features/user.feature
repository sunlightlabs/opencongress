Feature: Users
  Users should be able to signup
  and login properly
  and edit privacy settings
  and edit email options
  and reset passwords

  Scenario: Create User
    Given a user signs up as "dirt"
    Then I should see "Thanks for registering"

  Scenario: Login
    Given a newly created user is logged in as "dirt"
    Then I should see "Welcome, dirt"

  Scenario: Email option edits
    Given a newly created user is logged in as "hans"
    When "hans" sets all email options to be false
    Then "hans" should not be signed up for OC or partner emails

  Scenario: Privacy option edits
    Given a newly created user is logged in as "secretive"
    When "secretive" sets all privacy options to "public"
    Then "secretive" should have all "public" actions
    When "secretive" sets all privacy options to "private"
    Then "secretive" should have all "private" actions

  Scenario: Password reset
    Given pending password reset test

#  @javascript
#  Scenario: Track Bill
#    Given a newly created user is logged in as "dirt"
#    When I track a bill
#    Then I should see "Tracking Now"
#
#  @javascript
#  Scenario: Forgot password invalid email
#    Given I am on the forgot password page
#    When I fill in "user[email]" with "#awioehkjahwelguhawjeghkjlh"
#      And I press "Request Password"
#    Then I should see "Could not find a user with that email #address."
#
#  Scenario: Forgot password valid email
#    Given I am on the forgot password page
#    When I fill in "user[email]" with "#donnydonnyzxcasdqwe@gmail.com"
#      And I press "Request Password"
#    Then I should see "A reset password link has been sent to #your email address."
#
#  Scenario: Forgot password valid email, case-insensitive
#    Given I am on the forgot password page
#    When I fill in "user[email]" with "#doNnydOnnyZxcasdQwe@gMaIl.com"
#      And I press "Request Password"
#    Then I should see "A reset password link has been sent to #your email address."
#