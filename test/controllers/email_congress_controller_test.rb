require 'test_helper'

class EmailCongressControllerTest < ActionController::TestCase
  tests EmailCongressController
  include OpenCongress::Application.routes.url_helpers

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
  end

  test 'bounce_for_illegitimate_recipeints' do
    delivery_cnt_before = ActionMailer::Base.deliveries.length
    @request.env['RAW_POST_DATA'] = JSON.dump(incoming_email({"To" => "user@example.com", "ToFull" => { "Name" => "", "Email" => "user@example.com" }}))
    post(:message_to_members)
    delivery_cnt_after = ActionMailer::Base.deliveries.length
    assert_response :success
    assert_not_equal delivery_cnt_before, delivery_cnt_after
  end

  test 'confirming_new_seed_redirects' do
    incoming_seed
    get(:confirm, {'confirmation_code' => @seed.confirmation_code})
    assert_redirected_to @controller.url_for(:action => :complete_profile,
                                             :confirmation_code => @seed.confirmation_code)
  end

  test 'simple_path_for_known_user' do
    incoming_seed
    user = User.create(:accepted_tos_at => Time.zone.now,
                       :full_name => 'John Doe',
                       :email => @seed.sender_email,
                       :login => 'jdoe',
                       :password => User.random_password,
                       :state => 'AL',
                       :zipcode => '36445',  # Frisco City
                       :zip_four => '')
    user.save!
    get(:confirm, {'confirmation_code' => @seed.confirmation_code})
    # TODO: This requires the profile changes from Dan
    assert_redirected_to @controller.url_for(:action => :confirmed,
                                             :confirmation_code => @seed.confirmation_code)
  end
end
