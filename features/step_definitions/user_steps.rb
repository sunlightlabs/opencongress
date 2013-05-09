When /^I track a bill$/ do
  @current_user = User.last
  bill = Bill.first
  visit url_for({:controller => 'bill', :action => 'show', :id => bill.ident})
  visit "/profile/track/#{bill.id}?type=Bill"
end

Given /^an active non-tos user is logged in as "(.*)"$/ do |login|
  @current_user = User.create!(
    :login => login,
    :password => 'generic',
    :password_confirmation => 'generic',
    :email => "dshettler-#{login}@gmail.com",
    :enabled => true,
    :is_banned => false,
    :accept_tos => false,
    :accept_terms => true
  )

  # :create syntax for restful_authentication w/ aasm. Tweak as needed.
  @current_user.activate

  visit "/login"
  fill_in("user[login]", :with => login)
  fill_in("user[password]", :with => 'generic')
  click_button("Login")
  page.should have_content("Logged")
end

# TODO: Why does dev require a street address, but not prod?
Given /^a newly created user is logged in as "(.*)"$/ do |login|
  visit "/register"
  fill_in("Choose a Username", :with => login)
  fill_in("Choose a Password", :with => 'generic')
  fill_in("Confirm Password", :with => 'generic')
  fill_in("Email", :with => "dshettler-#{login}@gmail.com")
  fill_in("user[zipcode]", :with => "20036")
  fill_in("user[captcha]", :with => SimpleCaptcha::SimpleCaptchaData.last.value)
  check("user[accept_tos]")
  click_button("Register")
  page.should have_content("Thank you for Signing Up")
  user = User.find_by_login(login)
  code = user.activation_code
  visit "/account/activate/#{code}"
  # "Determine your congressional district" flow
  page.should have_content("your exact Congressional District")
  fill_in("address", :with => "1818 N St. NW")
  click_button("Submit")
  # Regularly scheduled programming
  page.should have_content("Thanks for registering")
  visit "/logout"
  visit "/"
  fill_in("user[login]", :with => login)
  fill_in("user[password]", :with => 'generic')
  click_button("Login")
  page.should have_content("Logged")
end

Given /^an active user is logged in as "(.*)"$/ do |login|
  @current_user = User.create!(
    :login => login,
    :password => 'generic',
    :password_confirmation => 'generic',
    :email => "dshettler-#{login}@gmail.com",
    :zipcode => '90039',
    :enabled => true,
    :is_banned => false,
    :accepted_tos => true,
    :accept_terms => true
  )

  # :create syntax for restful_authentication w/ aasm. Tweak as needed.
  @current_user.activate

  visit "/login"
  fill_in("user[login]", :with => login)
  fill_in("user[password]", :with => 'generic')
  click_button("Login")
  page.should have_content("Logged")
end

Given /^an existing user is logged in as "(.*)"$/ do |login|
  visit "/login"
  fill_in("user[login]", :with => login)
  fill_in("user[password]", :with => 'generic')
  click_button("Login")
  page.should have_content("Logged")
end

