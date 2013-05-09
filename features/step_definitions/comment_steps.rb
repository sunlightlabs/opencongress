When /^I enter a comment with content "([^"]*)"$/ do |content|
  within("#add_comment_form") do
    fill_in "Comment", :with => content
    click_button "Add Comment"
  end
end
