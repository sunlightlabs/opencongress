require 'spec_helper'

describe PrivacyObject do

  describe '#can_show_to?' do

    before(:each) do
      @user12 = FactoryGirl.create(:user)
      @user13 = FactoryGirl.create(:user)
    end

    describe 'User' do

      describe 'public' do

        before(:each) do
          [@user12,@user13].each {|user| user.set_all_default_privacies(:public) }
        end

        it 'should return TRUE for general public option' do
          expect(@user12.can_show_to?(@user13)).to be_truthy
        end

        it 'should return TRUE for default public login attribute' do
          expect(@user12.can_show_to?(@user13,'login')).to be_truthy
        end

      end

      describe 'private' do

        before(:each) do
          [@user12,@user13].each {|user| user.set_all_default_privacies(:private) }
        end

        it 'should return FALSE for default private email attribute' do
          expect(@user12.can_show_to?(@user13,'email')).to be_falsey
        end

        it 'should return FALSE for default private district attribute' do
          expect(@user12.can_show_to?(@user13,'district')).to be_falsey
        end

      end

    end

    describe 'BillVote' do

      describe 'public' do

        before(:each) do
          [@user12,@user13].each {|user| user.set_all_default_privacies(:public) }
          @bv = BillVote.create(bill_id:56724, user_id:@user12.id, support:0)
        end

        it 'should return TRUE for default public' do
          expect(@bv.can_show_to?(@user13)).to be_truthy
        end

        it 'should return TRUE for default public, method from user' do
          expect(@user12.can_show_item_to?(@user13, @bv)).to be_truthy
        end

      end

      describe 'private' do

        before(:each) do
          [@user12,@user13].each {|user| user.set_all_default_privacies(:private) }
          @bv = BillVote.create(bill_id:56724, user_id:@user12.id, support:0)
        end

        it 'should return FALSE for default private' do
          expect(@bv.can_show_to?(@user13)).to be_falsey
        end

        it 'should return FALSE for default private, method from user' do
          expect(@user12.can_show_item_to?(@user13, @bv)).to be_falsey
        end
      end

    end

    describe 'ContactCongressLetter' do

      describe 'public' do

        before(:each) do
          [@user12,@user13].each {|user| user.set_all_default_privacies(:public) }
          @ccl = ContactCongressLetter.create(user: @user12, disposition:'support', source: :browser)
        end

        it 'should return FALSE for default public' do
          expect(@ccl.can_show_to?(@user13)).to be_falsey
        end

        it 'should return TRUE for default public and is creator' do
          expect(@ccl.can_show_to?(@user12)).to be_truthy
        end

        it 'should return FALSE for default public, method from user' do
          expect(@user12.can_show_item_to?(@user13, @ccl)).to be_falsey
        end

        it "should return FALSE for default public, item doesn't belong to calling user" do
          expect(@user13.can_show_item_to?(@user12, @ccl)).to be_falsey
        end

      end

      describe 'private' do

        before(:each) do
          [@user12,@user13].each {|user| user.set_all_default_privacies(:public) }
          @ccl = ContactCongressLetter.create(user: @user12, disposition:'support', source: :browser)
        end

        it 'should return FALSE for default private' do
          expect(@ccl.can_show_to?(@user13)).to be_falsey
        end

        it 'should return TRUE for default private and is creator' do
          expect(@ccl.can_show_to?(@user12)).to be_truthy
        end

        it 'should return FALSE for default private, method from user' do
          expect(@user12.can_show_item_to?(@user13, @ccl)).to be_falsey
        end

        it 'should return TRUE for default private, method from user and is self' do
          expect(@user12.can_show_item_to?(@user12, @ccl)).to be_truthy
        end

      end

    end

  end

end