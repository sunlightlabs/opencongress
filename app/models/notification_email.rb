# == Schema Information
#
# Table name: notification_emails
#
#  id                        :integer          not null, primary key
#  sent                      :integer
#  received                  :integer
#  code                      :string(255)
#  click_count               :integer
#  aggregate_notification_id :integer
#  created_at                :datetime
#  updated_at                :datetime
#

class NotificationEmail < OpenCongressModel

end
