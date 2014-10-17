# == Schema Information
#
# Table name: user_notification_option_items
#
#  id                          :integer          not null, primary key
#  feed                        :integer
#  feed_priority               :string(255)
#  email                       :integer
#  email_frequency             :string(255)
#  mobile                      :integer
#  mobile_frequency            :string(255)
#  mms_message                 :integer
#  mms_message_frequency       :string(255)
#  user_notification_option_id :integer
#  activity_option_id          :integer
#  bookmark_id                 :integer
#  created_at                  :datetime
#  updated_at                  :datetime
#  aggregate_timeframe         :integer          default(21600)
#

class UserNotificationOptionItem < OpenCongressModel

  before_create -> { set_default_attributes_for_nil }

  #========== CONSTANTS

  DEFAULT_ATTRIBUTES = {
    feed: 1,
    feed_priority: '10',
    email: 1,
    email_frequency: '10',
    mobile: 0,
    mobile_frequency: '10',
    mms_message: 0,
    mms_message_frequency: '10'
  }

  #========== VALIDATORS

  validates_associated :activity_option, :user_notification_options

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :activity_option
  belongs_to :user_notification_options
  belongs_to :bookmark

  #========== METHODS

  #----- CLASS

  #----- INSTANCE

  public

  def feed?
    self.feed == 1
  end

  def email?
    self.email == 1
  end

  def mobile?
    self.mobile == 1
  end

  def mms_message?
    self.mms_message == 1
  end

  def feed_frequency
    feed_priority
  end

  # Determines whether a new NotificationAggregate should be created
  #
  # @param na [NotificationAggregate] current notification aggregate
  # @return [Boolean] true if should create new aggregate notification, false otherwise
  def stale_aggregate?(na)
    na.nil? or (Time.now - na.updated_at) >= self.aggregate_timeframe
  end

end