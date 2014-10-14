Feature: Bill Voting
  @javascript
  Scenario: Supporting a bill
    Given a newly created user is logged in as "dirt"
    When "dirt" votes "support" on a bill
    Then the page should show you voted in "support"