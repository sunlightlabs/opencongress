Given /^a user signs up as "(.*)"$/ do |login|
  VCR.use_cassette('new_user_signup') do
    visit "/register"
    within("#signupform") do
      fill_in("Choose a Username", :with => login)
      fill_in("Choose a Password", :with => 'generic')
      fill_in("Confirm Password", :with => 'generic')
      fill_in("Email", :with => "dshettler-#{login}@gmail.com")
      fill_in("user[zipcode]", :with => "22204")
      fill_in("user[captcha]", :with => 'dummy')
      check("user[accept_tos]")
      click_button("Register")
    end
    page.should have_content("Thank you for Signing Up")
    user = User.find_by_login(login)
    code = user.activation_code
    visit "/account/activate/#{code}"
    page.should have_content("Thanks for registering")
  end
end

Given /^a newly created user is logged in as "(.*)"$/ do |login|
  VCR.use_cassette('new_user') do
    visit "/register"
    within("#signupform") do
      fill_in("Choose a Username", :with => login)
      fill_in("Choose a Password", :with => 'generic')
      fill_in("Confirm Password", :with => 'generic')
      fill_in("Email", :with => "dshettler-#{login}@gmail.com")
      fill_in("user[zipcode]", :with => "22204")
      fill_in("user[captcha]", :with => 'dummy')
      check("user[accept_tos]")
      click_button("Register")
    end
    page.should have_content("Thank you for Signing Up")
    user = User.find_by_login(login)
    code = user.activation_code
    visit "/account/activate/#{code}"
    page.should have_content("Thanks for registering")
    click_link("Logout")
    visit "/login"
    page.should_not have_content("Welcome, #{login}")
    within("#login-left") do
      fill_in("Login", :with => login)
      fill_in("Password", :with => 'generic')
      click_button("Login")
    end
    page.should have_content("Welcome, #{login}")
  end
end

When /^"(.*)" sets all email options to be false$/ do |login|
  visit "/users/#{login}/profile/edit"
  within(".user_user_options_opencongress_mail") do
    choose("No")
  end
  within(".user_user_options_partner_mail") do
    choose("No")
  end
  click_button("Save Profile")
end

Then /^"(.*)" should not be signed up for OC or partner emails$/ do |login|
  user = User.find_by_login(login)
  user.user_options.opencongress_mail.should == false
  user.user_options.partner_mail.should == false
end

When /^"(.*)" sets all privacy options to "(.*)"$/ do |login, privacy_setting|
  user = User.find_by_login(login)
  visit "/users/#{login}/profile/edit"
  user_privacy_selects.keys.each do |s|
    within("#privacy_settings") do
      select(privacy_setting, from: s)
    end
  end
  click_button("Save Profile")
end

Then /^"(.*)" should have all "(.*)" actions$/ do |login, privacy_setting|
  user = User.find_by_login(login)
  user_privacy_selects.values.each do |s|
    user.user_privacy_options.send(s).should === UserPrivacyOptions::PRIVACY_OPTIONS[privacy_setting.to_sym]
  end
end

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
      :plaintext_password => 'generic',
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

Given /^an active user is logged in as "(.*)"$/ do |login|
  VCR.use_cassette('active_user') do
    @current_user = User.create!(
      :login => login,
      :plaintext_password => 'generic',
      :password_confirmation => 'generic',
      :email => "dshettler-#{login}@gmail.com",
      :zipcode => '22204',
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

