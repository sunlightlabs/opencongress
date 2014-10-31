require 'spec_helper'

describe Authable do

  before(:each) do
    @user30 = User.find(30)
  end

  describe '.authenticate' do

    it 'should return a user object' do
      user = User.authenticate('dan', 'test')
      expect(user).to be_a(User)
    end

    it 'should return false' do
      user = User.authenticate('dan', 'nope')
      expect(user).to be_falsey
    end

    it 'should return true' do

    end

  end

end