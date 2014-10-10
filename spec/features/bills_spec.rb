require_relative '../spec_helper'

feature "Bills", :type => :feature do
  self.use_transactional_fixtures = false
  scenario "User wants to view bill text"
end
