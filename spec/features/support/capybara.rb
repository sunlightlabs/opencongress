require 'rubygems'
require 'capybara'
require 'capybara/poltergeist'
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(
    app,
    {
      js_errors: false,
      default_wait_time: 30
    }
  )
end 
# Capybara.ignore_hidden_elements = false