When /^they visit a bill page and click comments$/ do
  bill = FactoryGirl.create(:bill)
  visit bill_path(bill)
  page.find("#comments a").click
end

When /^they enter a comment with content "(.*)"$/ do |content|
  VCR.use_cassette('create_comment') do
    within(".comment-add") do
      fill_in("comment[comment]", :with => content)
      click_button("Add Comment")
    end
  end
end

Then /^they should see a comment with content "(.*)"$/ do |content|
  within(".comments_master") do
    page.should have_content(content)
    save_and_open_page
  end
end
