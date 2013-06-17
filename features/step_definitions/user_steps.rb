When /^I track a bill$/ do
  @current_user = User.last
  bill = Bill.first
  visit url_for({:controller => 'bill', :action => 'show', :id => bill.ident})
  visit "/profile/track/#{bill.id}?type=Bill"
end

Given /^an active non-tos user is logged in as "(.*)"$/ do |login|
  VCR.use_cassette('active_non-tos_user') do
    @current_user = User.create!(
      :login => login,
      :password => 'generic',
      :password_confirmation => 'generic',
      :email => "dshettler-#{login}@gmail.com",
      :enabled => true,
      :status => 1,
      :accept_tos => false,
    )

    # :create syntax for restful_authentication w/ aasm. Tweak as needed.
    @current_user.activate!

    visit "/login"
    fill_in("user[login]", :with => login)
    fill_in("user[password]", :with => 'generic')
    click_button("Login")
    page.should have_content("Logged")
  end
end

Given /^a newly created user is logged in as "(.*)"$/ do |login|
  VCR.use_cassette('new_user') do
    visit "/register"
    fill_in("Choose a Username", :with => login)
    fill_in("Choose a Password", :with => 'generic')
    fill_in("Confirm Password", :with => 'generic')
    fill_in("Email", :with => "dshettler-#{login}@gmail.com")
    fill_in("user[zipcode]", :with => "22204")
    fill_in("user[captcha]", :with => SimpleCaptcha::SimpleCaptchaData.last.value)
    check("user[accept_tos]")
    click_button("Register")
    page.should have_content("Thank you for Signing Up")
    user = User.find_by_login(login)
    code = user.activation_code
    visit "/account/activate/#{code}"
    page.should have_content("Thanks for registering")
    visit "/logout"
    visit "/"
    find('#login-link').click
    fill_in("login_field", :with => login)
    fill_in("password_field", :with => 'generic')
    click_button("Login")
    page.should have_content("Logged")
  end
end

Given /^an active user is logged in as "(.*)"$/ do |login|
  VCR.use_cassette('active_user') do
    @current_user = User.create!(
      :login => login,
      :password => 'generic',
      :password_confirmation => 'generic',
      :email => "dshettler-#{login}@gmail.com",
      :zipcode => '22204',
      :enabled => true,
      :accept_tos => "1"
    )
    @current_user.accepted_tos_at = 10.minutes.ago
    @current_user.status = 1
    @current_user.save

    # :create syntax for restful_authentication w/ aasm. Tweak as needed.
    @current_user.activate!
    visit "/login"
    fill_in("user_login", :with => login)
    fill_in("user_password", :with => 'generic')
    click_button("Login")
    page.should have_content("Logged")
  end
end

Given /^an existing user is logged in as "(.*)"$/ do |login|
  VCR.use_cassette('existing_user') do
    visit "/login"
    fill_in("user[login]", :with => login)
    fill_in("user[password]", :with => 'generic')
    click_button("Login")
    page.should have_content("Logged")
  end
end

