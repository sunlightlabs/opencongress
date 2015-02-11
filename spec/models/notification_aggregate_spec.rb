# == Schema Information
#
# Table name: notification_aggregates
#
#  id          :integer          not null, primary key
#  score       :integer          default(0)
#  hide        :integer          default(0)
#  user_id     :integer
#  created_at  :datetime
#  updated_at  :datetime
#  click_count :integer          default(0)
#

require 'spec_helper'

RSpec.describe NotificationAggregate, :type => :model do
  describe "associations" do
    it "has many whatever" do
      2.class == Fixnum
    end

    it "" 
  end
end

describe NotificationAggregate do
  before(:each) do 
    VCR.use_cassette "create_bookmark" do
      @bookmark = FactoryGirl.create(:bookmark_on_bill)
    end

    @bill = @bookmark.bill
    # get user bookmarking this item receiving activity
    @user = @bookmark.user
    @activity_option = FactoryGirl.create(:activity_option, {
      :key => 'bill_action.create',
      :owner_model => 'Bill',
      :trackable_model => 'BillAction'  
    })
    @action = FactoryGirl.create(:action, {
      :bill => @bill
    })
  end
  describe '.create_from_activity' do

    # This is the case where the class method receives non-existent record IDs for either
    # the activity_id or user_id.
    it 'should return nil' do

      # run create_from_activity passing in non-existent activity id and user id
      na = NotificationAggregate.create_from_activity(0, 0)

      # class method should return nil with non-existent activity id and user id
      expect(na).to be_nil

    end

    # This is the case where an activity is created and no NotificationAggregate
    # currently exists within the timeframe for aggregation.
    it 'should create and return a new NotificationAggregate instance' do

      # generate activity
      activity = PublicActivity::Activity.create(trackable_id: 686252,
                                                 trackable_type: 'Action',
                                                 owner_id: @bill.id,
                                                 owner_type: 'Bill',
                                                 key: 'bill_action.create',
                                                 parameters: {},
                                                 recipient_id: nil,
                                                 recipient_type: nil)

      # run create_from_activity passing in valid arguments
      na = NotificationAggregate.create_from_activity(activity.id, @user.id)

      # class method should return an instance of NotificationAggregate
      expect(na).to be_an_instance_of(NotificationAggregate)

    end

    # This is the case where an activity is created and an NotificationAggregate
    # already exists within the timeframe for aggregation.
    it 'should associate activity with an existing NotificationAggregate instance' do

      # generate activity
      activity = PublicActivity::Activity.create(trackable_id: 686252,
                                                 trackable_type: 'Action',
                                                 owner_id: @bill.id,
                                                 owner_type: 'Bill',
                                                 key: 'bill_action.create',
                                                 parameters: {},
                                                 recipient_id: nil,
                                                 recipient_type: nil)

      # run create_from_activity passing in valid arguments
      na1 = NotificationAggregate.create_from_activity(activity.id, @user.id)

      # generate more activity
      activity = PublicActivity::Activity.create(trackable_id: 686253,
                                                 trackable_type: 'Action',
                                                 owner_id: @bill.id,
                                                 owner_type: 'Bill',
                                                 key: 'bill_action.create',
                                                 parameters: {},
                                                 recipient_id: nil,
                                                 recipient_type: nil)

      # run it again
      na2 = NotificationAggregate.create_from_activity(activity.id, @user.id)

      # the same NotificationAggregate should be associate with both activities
      expect(na1.id).to eq(na2.id)

    end

    # This is the case where an activity is created and the NotificationAggregate already
    # exists but it is stale so a new NotificationAggregate is created.
    it 'should not associate with existing NotificationAggregate because that instance is stale' do

      # create setting for user and activity option with an aggregate timeframe of 0 (immediately stale aggregates)
      UserNotificationOptionItem.create(aggregate_timeframe:0,
                                        user_notification_option_id: @user.id,
                                        bookmark_id: @bookmark.id,
                                        activity_option_id: @activity_option.id ) # '3 -> bill_action.create'

      # generate activity
      activity = PublicActivity::Activity.create(trackable_id: 686252,
                                                 trackable_type: 'Action',
                                                 owner_id: @bill.id,
                                                 owner_type: 'Bill',
                                                 key: 'bill_action.create',
                                                 parameters: {},
                                                 recipient_id: nil,
                                                 recipient_type: nil)

      # run create_from_activity passing in valid arguments
      na1 = NotificationAggregate.create_from_activity(activity.id, @user.id)

      # wait a few seconds
      sleep(3.second)

      # generate more activity
      activity = PublicActivity::Activity.create(trackable_id: 686253,
                                                 trackable_type: 'Action',
                                                 owner_id: @bill.id,
                                                 owner_type: 'Bill',
                                                 key: 'bill_action.create',
                                                 parameters: {},
                                                 recipient_id: nil,
                                                 recipient_type: nil)

      # run it again
      na2 = NotificationAggregate.create_from_activity(activity.id, @user.id)

      # the two NotificationAggregates should be different now
      expect(na1.id).not_to eq(na2.id)

    end

  end

end
