# == Schema Information
#
# Table name: user_notification_settings
#
#  id                 :integer          not null, primary key
#  timeframe          :string(255)
#  threshold          :integer
#  email_freq         :string(255)
#  user_id            :integer
#  activity_option_id :integer
#  created_at         :datetime
#  updated_at         :datetime
#

class UserNotificationSetting < OpenCongressModel

  belongs_to :user
  belongs_to :activity_option


end
