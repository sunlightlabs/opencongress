require 'spec_helper'

describe PrivacyObject do

  describe '#can_show_to?' do

    describe 'User' do

      before(:each) do
        @user12 = User.find(12)
        @user13 = User.find(13)
      end

      it 'should return TRUE for general public option' do

        [@user12,@user13].each {|user| user.set_all_default_privacies(:public) }

        expect(@user12.can_show_to?(@user13)).to be_truthy
      end

      it 'should return TRUE for default public login attribute' do

        [@user12,@user13].each {|user| user.set_all_default_privacies(:public) }

        expect(@user12.can_show_to?(@user13,'login')).to be_truthy
      end

      it 'should return FALSE for default private email attribute' do

        [@user12,@user13].each {|user| user.set_all_default_privacies(:private) }

        expect(@user12.can_show_to?(@user13,'email')).to be_falsey
      end

      it 'should return FALSE for default private district attribute' do

        [@user12,@user13].each {|user| user.set_all_default_privacies(:private) }

        expect(@user12.can_show_to?(@user13,'district')).to be_falsey
      end

    end

    describe 'BillVote' do

      before(:each) do
        @user12 = User.find(12)
        @user13 = User.find(13)
      end

      it 'should return TRUE for default public' do

        [@user12,@user13].each {|user| user.set_all_default_privacies(:public) }

        @bv = BillVote.create(bill_id:56724, user_id:@user12.id, support:0)

        expect(@bv.can_show_to?(@user13)).to be_truthy

      end

      it 'should return TRUE for default public, method from user' do

        [@user12,@user13].each {|user| user.set_all_default_privacies(:public) }

        @bv = BillVote.create(bill_id:56724, user_id:@user12.id, support:0)

        expect(@user12.can_show_item_to?(@user13, @bv)).to be_truthy
      end

      it 'should return FALSE for default private' do

        [@user12,@user13].each {|user| user.set_all_default_privacies(:private) }

        @bv = BillVote.create(bill_id:56724, user_id:@user12.id, support:0)

        expect(@bv.can_show_to?(@user13)).to be_falsey
      end

      it 'should return FALSE for default private, method from user' do

        [@user12,@user13].each {|user| user.set_all_default_privacies(:private) }

        @bv = BillVote.create(bill_id:56724, user_id:@user12.id, support:0)

        expect(@user12.can_show_item_to?(@user13, @bv)).to be_falsey
      end

    end

  end

end