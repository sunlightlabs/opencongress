require 'factory_girl'

When /^"(.*)" votes "(.*)" on a bill$/ do |login, position|
  bill = FactoryGirl.create(:bill)
  visit bill_path(bill)
  click_on("Support this Bill")
end

Then /^the page should show you voted in "(.*)"$/ do |position|
  page.should have_content("You voted #{position}")
end