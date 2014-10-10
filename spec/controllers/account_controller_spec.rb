require 'spec_helper'

describe AccountController, type: :controller do
  describe 'POST #signup' do
    before(:all) do
      @post_params = { 
        "user" => {
          "login"=>"uniqhelloworld12356789",
          "password"=>"[FILTERED]",
          "password_confirmation"=>"[FILTERED]",
          "email"=>"helloworld123@yahoo.com",
          "zipcode"=>"12345",
          "user_role_id" => 1,
          "user_options_attributes" => {
            "partner_mail"=>"0",
            "opencongress_mail"=>"0"
          },
          "accept_tos"=> "1"
        }
      }
    end
    context 'when user attempts to set admin attributes' do
      it "should not be an admin" do
        post :signup, @post_params
        expect(User.find_by(login: "uniqhelloworld12356789").user_role_id).to eq(0)
      end
    end
    context 'when user selects email options' do
      it "should modify user_options model" do
        post :signup, @post_params
        expect(User.find_by(login: "uniqhelloworld12356789").user_options.opencongress_mail).to eq(false)
        expect(User.find_by(login: "uniqhelloworld12356789").user_options.partner_mail).to eq(false)
      end
    end
  end
end
