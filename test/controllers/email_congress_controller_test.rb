require 'test_helper'

class EmailCongressControllerTest < ActionController::TestCase
  tests EmailCongressController
  include OpenCongress::Application.routes.url_helpers

  def at_email_congress (localpart)
    "#{localpart}@#{Settings.email_congress_domain}"
  end

  def incoming_email (options=Hash.new)
    default_email = {
      "Date" => "Fri, 2 May 2014 16:29:46 -0400",
      "From" => "user@example.com",
      "FromFull" => {
        "Email" => "user@example.com",
        "Name" => "John Doe"
      },
      "FromName" => "John Doe",
      "Headers" => [],
      "HtmlBody" => "(empty body)",
      "MailboxHash" => "",
      "MessageID" => "8edcca77-08b8-4c6f-b3a6-5497c4d6bf5d",
      "ReplyTo" => "",
      "Subject" => "(no subject)",
      "Tag" => "",
      "TextBody" => "(empty body)",
      "To" => "Sen.Brown@inbound.postmarkapp.com",
      "ToFull" => [
        {
          "Email" => "sen.brown@inbound.postmarkapp.com",
          "Name" => ""
        }
      ]
    }
    return default_email.merge(options)
  end

  def incoming_seed (options=Hash.new)
    @seed = EmailCongress.seed_for_postmark_object(incoming_email(options))
    return @seed
  end

  def setup
  end

  def teardown
    @seed.destroy unless @seed.nil?
    @user.destroy unless @user.nil?
  end

  test 'bounce_for_illegitimate_recipeints' do
    delivery_cnt_before = ActionMailer::Base.deliveries.length
    @request.env['RAW_POST_DATA'] = JSON.dump(incoming_email({"To" => "user@example.com", "ToFull" => { "Name" => "", "Email" => "user@example.com" }}))
    post(:message_to_members)
    delivery_cnt_after = ActionMailer::Base.deliveries.length
    assert_response :success
    assert_not_equal delivery_cnt_before, delivery_cnt_after

    message = ActionMailer::Base.deliveries.last
    assert_match(/^Could not deliver message:/, message.subject)
  end

  test 'no_bounce_for_new_user_emailing_myreps' do
    delivery_cnt_before = ActionMailer::Base.deliveries.length
    @request.env['RAW_POST_DATA'] = JSON.dump(incoming_email({"To" => at_email_congress('myreps'), "ToFull" => { "Name" => "", "Email" => at_email_congress('myreps') }}))
    post(:message_to_members)
    delivery_cnt_after = ActionMailer::Base.deliveries.length
    assert_response :success
    assert_not_equal delivery_cnt_before, delivery_cnt_after

    message = ActionMailer::Base.deliveries.last
    assert_no_match(/^Could not deliver message:/, message.subject)
  end

  test 'confirming_new_seed_redirects' do
    incoming_seed
    get(:confirm, {'confirmation_code' => @seed.confirmation_code})
    assert_redirected_to @controller.url_for(:action => :complete_profile,
                                             :confirmation_code => @seed.confirmation_code)
  end

  test 'simple_path_for_known_user' do
    profile = EmailCongress::ProfileProxy.new(OpenStruct.new({
      :first_name => 'John',
      :last_name => 'Doe',
      :email => 'user@example.com',
      :street_address => '4236 Bowden St',
      :city => 'Frisco City',
      :state => 'AL',
      :zipcode => '36445',
      :zip_four => '',
      :mobile_phone => '5555555555',
      :accept_tos => true
    }))
    @user = User.new(:login => 'jdoe', :password => User.random_password)
    @user.user_profile = UserProfile.new
    MultiGeocoder.stub(:coordinates, [31.4228, -87.41734]) do
      MultiGeocoder.stub(:search, [OpenStruct.new({ "zipcode" => "36445", "zip4" => "5420" })]) do
        Congress.stub(:districts_locate, OpenStruct.new({ "results" => [OpenStruct.new({ "state" => "AL", "district" => 1 }) ], "count" => 1 })) do
          profile.copy_to(@user)
          @user.save!

          profile.copy_to(@user.user_profile)
          @user.user_profile.save!

          incoming_seed({
            "From" => @user.email,
            "FromFull" => { "Name" => "", "Email" => @user.email },
            "To" => at_email_congress('myreps'),
            "ToFull" => [ { "Name" => "", "Email" => at_email_congress('myreps') } ]
          })
          get(:confirm, {'confirmation_code' => @seed.confirmation_code})
        end
      end
    end
    assert_equal nil, flash[:error]
    assert_redirected_to @controller.url_for(:action => :confirmed,
                                             :confirmation_code => @seed.confirmation_code)
  end
end
