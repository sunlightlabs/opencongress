Feature: Comments
  We should be able to add comments to pages and visit those comments.

  @javascript
  Scenario: Add a comment to a blog post
    Given a newly created user is logged in as "dirt"
    When they visit a bill page and click comments
    Then they enter a comment with content "hello world"
    Then they should see a comment with content "hello world"
