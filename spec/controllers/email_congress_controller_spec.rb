require 'spec_helper'
require 'spec_helpers/email_congress_spec_helper'

RSpec.configure do |c|
  c.include EmailCongressHelper
end

describe EmailCongressController do
  describe 'Known user' do
    before(:each) do
      @user = users(:jdoe)
    end

    it "should bounce for illegitimate recipient" do
			delivery_count_before = ActionMailer::Base.deliveries.length
      email = incoming_email({
        "To" => "user@example.com",
        "ToFull" => { "Name" => "", "Email" => "user@example.com" },
        "From" => @user.email, "FromFull" => {"Name" => @user.full_name, "Email" => @user.email}
      })
      request.env['RAW_POST_DATA'] = JSON.dump(email)
      post :message_to_members
      assert_response :success
	    delivery_count_after = ActionMailer::Base.deliveries.length
	    delivery_count_before.should_not == delivery_count_after
	    message = ActionMailer::Base.deliveries.last
			assert_match(/^Could not deliver message:/, message.subject)    	
    end

    it 'should not be able to send to reps outside their district' do
    	pending "Cannot make sense of this test. When I try to email an out-of-district
    	rep on live (as logged in user), I get the response from no_recipient_bounce"
	    other_state = State::ABBREVIATIONS.values.reject{ |st| st == @user.state }.first
	    other_sen = Person.sen.where(:state => other_state).first
	    rcpt_addr = EmailCongress.email_address_for_person(other_sen)
	    seed = incoming_seed({
	      "To" => rcpt_addr,
	      "ToFull" => [ { "Email" => rcpt_addr, "Name" => "" } ]
	    })
	    get :confirm, :confirmation_code => seed.confirmation_code
	    assert_redirected_to @controller.url_for(:action => :complete_profile,
	                                             :confirmation_code => seed.confirmation_code)
	    get :complete_profile, :confirmation_code => seed.confirmation_code
	    assert_response :success
    end

    it "should send a confirmation link when user emails myreps@" do
      email = incoming_email({
        "To" => at_email_congress('myreps'),
        "ToFull" => [ { "Name" => "", "Email" => at_email_congress('myreps') } ],
        "From" => @user.email,
        "FromFull" => {"Name" => @user.full_name, "Email" => @user.email}
      })
      request.env['RAW_POST_DATA'] = JSON.dump(email)
      post :message_to_members
      assert_response :success

	    message = ActionMailer::Base.deliveries.last
	    assert_match(/^Please confirm your message to Congress:/, message.subject)
    end

    it "successful_confirmation" do
	    seed = incoming_seed({
	      "From" => @user.email,
	      "FromFull" => { "Name" => "", "Email" => @user.email },
	      "To" => at_email_congress('myreps'),
	      "ToFull" => [ { "Name" => "", "Email" => at_email_congress('myreps') } ]
	    })
	    VCR.use_cassette('successful confirmation') do
	    	get(:confirm, {'confirmation_code' => seed.confirmation_code})
	    end
	    assert_equal nil, flash[:error]
	    assert_redirected_to @controller.url_for(:action => :confirmed,
	                                             :confirmation_code => seed.confirmation_code)
    end

    it 'should send a warning email to people that haven\'t supplied a plaintext verion' do
      email = incoming_email({
        "To" => at_email_congress('myreps'),
        "ToFull" => [ { "Name" => "", "Email" => at_email_congress('myreps') } ],
        "From" => @user.email,
        "FromFull" => {"Name" => @user.full_name, "Email" => @user.email},
        "TextBody" => ""
      })
      request.env['RAW_POST_DATA'] = JSON.dump(email)
      post(:message_to_members)
      message = ActionMailer::Base.deliveries.last
      assert_match(/^Email Congress could not deliver your message/, message.subject)
    end


    it 'should send a warning email to people that try to email someone that\'s uncontactable' do
      @target = Person.where(firstname: "Richard", lastname: "Shelby").first
      @target.contactable = false; @target.save!
      email = incoming_email({
        "To" => "Sen.Shelby@opencongress.org",
        "ToFull" => [ { "Name" => "", "Email" => at_email_congress('Sen.Shelby') } ],
        "From" => @user.email,
        "FromFull" => {"Name" => @user.full_name, "Email" => @user.email},
        "TextBody" => "Hello, world!"
      })
      request.env['RAW_POST_DATA'] = JSON.dump(email)
      post(:message_to_members)
      message = ActionMailer::Base.deliveries.last
      assert_match(/^Sorry! OpenCongress could not send your message/, message.subject)
    end
  end
  describe 'New users' do
    it 'no_bounce_for_illegitimate_recipients_for_new_user' do
	    delivery_count_before = ActionMailer::Base.deliveries.length
	    @request.env['RAW_POST_DATA'] = JSON.dump(incoming_email({"To" => "user@example.com", "ToFull" => { "Name" => "", "Email" => "user@example.com" }}))
	    post(:message_to_members)
	    delivery_count_after = ActionMailer::Base.deliveries.length
	    assert_response :success
	    assert_not_equal delivery_count_before, delivery_count_after

	    message = ActionMailer::Base.deliveries.last
	    assert_no_match(/^Could not deliver message:/, message.subject)
    end

    it 'should not bounce when new user emails myreps@' do
	    delivery_count_before = ActionMailer::Base.deliveries.length
	    @request.env['RAW_POST_DATA'] = JSON.dump(incoming_email({"To" => at_email_congress('myreps'), "ToFull" => { "Name" => "", "Email" => at_email_congress('myreps') }}))
	    post :message_to_members
	    delivery_count_after = ActionMailer::Base.deliveries.length
	    assert_response :success
	    assert_not_equal delivery_count_before, delivery_count_after

	    message = ActionMailer::Base.deliveries.last
	    assert_no_match(/^Could not deliver message:/, message.subject)
    end

    it "New seed should redirect to /complete_profile" do
	    seed = incoming_seed
	    get :confirm, {'confirmation_code' => seed.confirmation_code}
	    assert_redirected_to @controller.url_for(:action => :complete_profile, :confirmation_code => seed.confirmation_code)
    end
  end
end
