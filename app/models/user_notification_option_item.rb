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
    feed_priority: 'm',
    email: 1,
    email_frequency: 'week',
    mobile: 0,
    mobile_frequency: nil,
    mms_message: 0,
    mms_message_frequency: nil,
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

  # Determines whether a new NotificationAggregate should be created
  #
  # @param na [NotificationAggregate] current notification aggregate
  # @return [Boolean] true if should create new aggregate notification, false otherwise
  def stale_aggregate?(na)
    na.nil? or (Time.now - na.updated_at) >= aggregate_timeframe
  end

end