require 'spec_helper'

describe Authable do

  describe '.authenticate' do
    before :each do
      @user = FactoryGirl.create(:user, {
        :password => "therightpassword"
      })
    end

    it 'should return a user object' do
      user = User.authenticate(@user.login, "therightpassword")
      expect(user).to be_a(User)
    end

    it 'should return false' do
      user = User.authenticate(@user.login, 'wrongpasswordoverhere')
      expect(user).to be_falsey
    end
  end

end