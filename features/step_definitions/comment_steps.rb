When /^I enter a comment with content "([^"]*)"$/ do |content|
  within(".comment-add") do
    fill_in "comment[comment]", :with => content
    click_button "Add Comment"
  end
end
